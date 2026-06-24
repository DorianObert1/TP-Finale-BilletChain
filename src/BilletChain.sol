// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @title BilletChain
/// @notice Billetterie sur blockchain : chaque billet est un NFT unique, vendu à un
///         prix affiché en euros mais payé en monnaie native via un oracle Chainlink.
///         Le contrat est aussi la place de marché pour la revente plafonnée.
contract BilletChain is ERC721, Ownable, ReentrancyGuard {
    uint256 public constant RESALE_CAP_PERCENT = 110; // plafond de revente

    uint256 public immutable maxTickets;
    uint256 public immutable nominalPriceEur; // en euros entiers (ex. 50 = 50 €)
    AggregatorV3Interface public immutable priceFeed; // euros pour 1 unité native
    uint256 public immutable maxPriceAge; // fraîcheur max du prix oracle, en secondes

    uint256 private _nextTokenId;

    // Prix payé en wei à l'achat initial, base de calcul du plafond de revente.
    mapping(uint256 tokenId => uint256 weiPaid) public purchasePrice;

    // Prix de revente demandé en wei ; 0 = non mis en vente.
    mapping(uint256 tokenId => uint256 priceWei) public listingPrice;

    // Sommes dues à chaque adresse, retirables via withdraw (pull-payment).
    mapping(address account => uint256 amount) public proceeds;

    event TicketSold(uint256 indexed tokenId, address indexed buyer, uint256 pricePaidWei);
    event TicketListed(uint256 indexed tokenId, address indexed seller, uint256 priceWei);
    event ListingCancelled(uint256 indexed tokenId, address indexed seller);
    event TicketResold(uint256 indexed tokenId, address indexed seller, address indexed buyer, uint256 priceWei);
    event Withdrawn(address indexed account, uint256 amount);

    error SoldOut();
    error IncorrectPayment(uint256 expected, uint256 sent);
    error InvalidOraclePrice();
    error StalePrice(uint256 updatedAt);
    error NotTicketOwner();
    error ZeroPrice();
    error PriceAboveCap(uint256 cap, uint256 asked);
    error NotApprovedForResale();
    error NotListed();
    error NothingToWithdraw();
    error WithdrawFailed();

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 maxTickets_,
        uint256 nominalPriceEur_,
        address priceFeed_,
        uint256 maxPriceAge_
    ) ERC721(name_, symbol_) Ownable(msg.sender) {
        maxTickets = maxTickets_;
        nominalPriceEur = nominalPriceEur_;
        priceFeed = AggregatorV3Interface(priceFeed_);
        maxPriceAge = maxPriceAge_;
    }

    /// @notice Prix d'un billet neuf en wei au taux courant de l'oracle.
    function currentTicketPriceWei() public view returns (uint256) {
        (, int256 answer,, uint256 updatedAt,) = priceFeed.latestRoundData();
        if (answer <= 0) revert InvalidOraclePrice();
        if (block.timestamp - updatedAt > maxPriceAge) revert StalePrice(updatedAt);

        // montant(wei) = prix€ * 1e18 * 10^decimals / answer
        uint8 feedDecimals = priceFeed.decimals();
        return (nominalPriceEur * 1e18 * (10 ** feedDecimals)) / uint256(answer);
    }

    /// @notice Plafond de revente d'un billet en wei (110 % du prix d'achat initial).
    function resaleCapWei(uint256 tokenId) public view returns (uint256) {
        return purchasePrice[tokenId] * RESALE_CAP_PERCENT / 100;
    }

    /// @notice Achète un billet neuf en payant le montant exact.
    function buyTicket() external payable returns (uint256 tokenId) {
        if (_nextTokenId >= maxTickets) revert SoldOut();

        uint256 price = currentTicketPriceWei();
        if (msg.value != price) revert IncorrectPayment(price, msg.value);

        tokenId = _nextTokenId++;
        purchasePrice[tokenId] = price;
        proceeds[owner()] += price;
        _safeMint(msg.sender, tokenId);

        emit TicketSold(tokenId, msg.sender, price);
    }

    /// @notice Met un billet en vente. Réservé au propriétaire, plafonné à 110 %.
    /// @dev Le contrat doit être approuvé pour pouvoir transférer le billet à la revente.
    function listTicket(uint256 tokenId, uint256 priceWei) external {
        if (ownerOf(tokenId) != msg.sender) revert NotTicketOwner();
        if (priceWei == 0) revert ZeroPrice();

        uint256 cap = resaleCapWei(tokenId);
        if (priceWei > cap) revert PriceAboveCap(cap, priceWei);

        if (getApproved(tokenId) != address(this) && !isApprovedForAll(msg.sender, address(this))) {
            revert NotApprovedForResale();
        }

        listingPrice[tokenId] = priceWei;
        emit TicketListed(tokenId, msg.sender, priceWei);
    }

    /// @notice Retire un billet de la vente.
    function cancelListing(uint256 tokenId) external {
        if (ownerOf(tokenId) != msg.sender) revert NotTicketOwner();
        delete listingPrice[tokenId];
        emit ListingCancelled(tokenId, msg.sender);
    }

    /// @notice Achète un billet mis en vente au montant exact demandé.
    function buyResale(uint256 tokenId) external payable nonReentrant {
        uint256 price = listingPrice[tokenId];
        if (price == 0) revert NotListed();
        if (msg.value != price) revert IncorrectPayment(price, msg.value);

        address seller = ownerOf(tokenId);
        // L'approbation peut avoir été retirée depuis la mise en vente : on revérifie.
        if (getApproved(tokenId) != address(this) && !isApprovedForAll(seller, address(this))) {
            revert NotApprovedForResale();
        }

        proceeds[seller] += price;
        _safeTransfer(seller, msg.sender, tokenId); // _update efface le listing

        emit TicketResold(tokenId, seller, msg.sender, price);
    }

    /// @notice Retire les sommes dues à l'appelant (pull-payment).
    function withdraw() external nonReentrant {
        uint256 amount = proceeds[msg.sender];
        if (amount == 0) revert NothingToWithdraw();

        proceeds[msg.sender] = 0; // effet avant interaction
        (bool ok,) = msg.sender.call{value: amount}("");
        if (!ok) revert WithdrawFailed();

        emit Withdrawn(msg.sender, amount);
    }

    /// @notice Compte, parmi les billets fournis, combien sont actuellement en vente.
    function countListed(uint256[] calldata tokenIds) external view returns (uint256 count) {
        uint256 length = tokenIds.length;
        for (uint256 i; i < length;) {
            if (listingPrice[tokenIds[i]] != 0) {
                unchecked {
                    ++count;
                }
            }
            unchecked {
                ++i;
            }
        }
    }

    function totalMinted() external view returns (uint256) {
        return _nextTokenId;
    }

    /// @dev Tout transfert d'un billet annule sa mise en vente (évite un listing périmé).
    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        if (listingPrice[tokenId] != 0) {
            delete listingPrice[tokenId];
        }
        return super._update(to, tokenId, auth);
    }
}
