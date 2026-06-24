# Note de déploiement

## Réseau choisi

Je déploierais d'abord sur Sepolia. C'est le réseau de test Ethereum le mieux maintenu, l'ETH
de test s'obtient facilement avec un faucet, et surtout des price feeds Chainlink officiels y
sont disponibles. C'est important vu que le contrat dépend d'un oracle pour le taux de change.

## Valeurs passées au constructeur

Le constructeur prend (name, symbol, maxTickets, nominalPriceEur, priceFeed, maxPriceAge,
platformFeeBps). Pour un événement type je mettrais :

- name = "BilletChain" et symbol = "BLT" : le nom et le symbole de la collection.
- maxTickets = 500 : la jauge de la salle, fixée une fois pour toutes à la création.
- nominalPriceEur = 50 : le prix affiché, soit 50 euros.
- priceFeed : l'adresse du feed Chainlink (voir plus bas).
- maxPriceAge = 3600 : un prix de plus d'une heure est considéré comme périmé et l'achat est
  refusé. À ajuster selon le heartbeat réel du feed.
- platformFeeBps = 250 : les frais de plateforme sur revente, soit 2,5 % (le contrat les
  plafonne à 10 %).

## Où récupérer l'adresse du taux de change

Les adresses des feeds ne s'inventent pas. Chainlink les publie sur sa page officielle "Price
Feed Addresses" (docs.chain.link, section Data Feeds). On y choisit le réseau (Sepolia) et on
copie l'adresse du feed voulu, qu'on passe ensuite en priceFeed au déploiement.

Mon contrat attend un feed qui donne le prix d'une unité de monnaie native en euros (genre un
feed ETH/EUR), avec ses propres décimales. La fonction currentTicketPriceWei lit decimals() et
s'adapte toute seule. Deux cas possibles :

- s'il y a un feed adapté sur le réseau, on prend son adresse sur la page Chainlink ;
- sinon, pour les tests et la démo, on déploie le MockV3Aggregator du projet avec une valeur
  réaliste (par exemple 1 ETH = 2000 euros) et on lui passe son adresse. C'est aussi ce qui sert
  à isoler la dépendance externe dans la suite de tests. En production on basculerait sur le vrai
  feed Chainlink.

## Étapes de déploiement

1. Mettre l'URL RPC de Sepolia et la clé privée du déployeur dans un fichier .env.
2. Récupérer l'adresse du price feed sur la page Chainlink.
3. Déployer avec forge create ou un script Foundry en passant les sept paramètres.
4. Vérifier le contrat sur Etherscan, puis tester un achat depuis un wallet alimenté en ETH de
   test pour valider toute la chaîne (oracle, prix, paiement).
