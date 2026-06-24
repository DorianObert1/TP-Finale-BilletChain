# BilletChain

Billetterie d'une salle de concert gérée directement sur la blockchain, sans intermédiaire.
Projet réalisé dans le cadre de l'évaluation finale (voir `Evaluation_BilletChain.md`).

## Objectif

- Vendre des billets **uniques** (un NFT par place) infalsifiables et transférables.
- Afficher un prix **en euros** mais faire payer en monnaie native, via un **oracle** de taux
  de change (Chainlink).
- Autoriser la **revente entre particuliers**, plafonnée à **110 %** du prix d'achat initial.
- Sécuriser les fonds : encaissement par **retrait** (pull-payment), protection contre la
  réentrance et contrôle d'accès.

## Stack technique

- **Solidity** `0.8.24`
- **Foundry** (forge / cast / anvil) pour le build et les tests
- **OpenZeppelin Contracts** : `ERC721`, `Ownable`, `ReentrancyGuard`
- **Chainlink** : `AggregatorV3Interface` pour le taux de change EUR → natif

## Organisation du dépôt

```
src/        contrats Solidity
test/       suite de tests Foundry (+ mock d'oracle)
script/     scripts de déploiement
lib/        dépendances (forge-std, OpenZeppelin, Chainlink)
docs/       partie théorique (Q1→Q5) et note de déploiement
```

## Commandes utiles

```bash
forge build         # compilation
forge test          # exécution des tests
forge test -vvv     # tests avec traces détaillées
forge fmt           # formatage
```

## Dépendances

Après un clone, récupérer les sous-modules :

```bash
forge install
```
