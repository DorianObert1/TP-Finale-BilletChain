// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @title BilletChain
/// @notice Billetterie sur blockchain : chaque billet est un NFT unique, vendu à un
///         prix affiché en euros mais payé en monnaie native via un oracle Chainlink.
contract BilletChain is ERC721, Ownable {
    uint256 public immutable maxTickets;
    uint256 public immutable nominalPriceEur; // en euros entiers (ex. 50 = 50 €)
    AggregatorV3Interface public immutable priceFeed; // euros pour 1 unité native
    uint256 public immutable maxPriceAge; // fraîcheur max du prix oracle, en secondes

    uint256 private _nextTokenId;

    // Prix payé en wei à l'achat initial, base de calcul du plafond de revente.
    mapping(uint256 tokenId => uint256 weiPaid) public purchasePrice;

    event TicketSold(uint256 indexed tokenId, address indexed buyer, uint256 pricePaidWei);

    error SoldOut();
    error IncorrectPayment(uint256 expected, uint256 sent);
    error InvalidOraclePrice();
    error StalePrice(uint256 updatedAt);

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

    /// @notice Achète un billet neuf en payant le montant exact.
    function buyTicket() external payable returns (uint256 tokenId) {
        if (_nextTokenId >= maxTickets) revert SoldOut();

        uint256 price = currentTicketPriceWei();
        if (msg.value != price) revert IncorrectPayment(price, msg.value);

        tokenId = _nextTokenId++;
        purchasePrice[tokenId] = price;
        _safeMint(msg.sender, tokenId);

        emit TicketSold(tokenId, msg.sender, price);
    }

    function totalMinted() external view returns (uint256) {
        return _nextTokenId;
    }
}
