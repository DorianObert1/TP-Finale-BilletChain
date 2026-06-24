# Partie théorique

## Q1 : Fondamentaux

Chaque nœud du réseau rejoue la transaction de son côté et doit trouver le même résultat, sinon
ils ne sont pas d'accord. C'est pour ça que l'exécution est déterministe et répliquée. Du coup
un contrat ne peut pas aller chercher une donnée du monde réel tout seul (taux, météo, hasard),
car deux nœuds pourraient récupérer des valeurs différentes. Il faut un oracle qui envoie la
donnée au contrat.

## Q2 : Cryptographie

L'utilisateur signe sa transaction avec sa clé privée, qui reste secrète. La signature prouve
qu'il a bien validé cette transaction. Le réseau retrouve l'adresse de l'émetteur à partir de la
signature, sans avoir besoin de la clé privée. Comme on ne peut pas fabriquer une signature sans
la clé privée, on est sûr de qui a envoyé la transaction.

## Q3 : Tokens

Un billet est unique : chaque place est différente et a son propre prix. Il faut donc un token
unique (ERC-721), où chaque billet a son identifiant et son propriétaire. Un token
interchangeable (ERC-20) ne va pas, car toutes les unités sont pareilles. L'ERC-20 servirait
plutôt pour une monnaie, par exemple des jetons boisson où peu importe lequel on dépense.

## Q4 : Sécurité

La réentrance : au moment du retrait, un attaquant pourrait rappeler withdraw() avant que son
solde soit remis à zéro et vider le contrat. Je remets le solde à zéro avant d'envoyer l'argent,
et j'ajoute nonReentrant.

L'oracle : si le prix est faux ou trop vieux, je calcule un mauvais prix. Donc je rejette un
prix nul ou négatif et un prix trop ancien avant de l'utiliser.

## Q5 : Gas

J'utilise des custom errors au lieu de messages texte, car le texte coûte plus cher à stocker et
à renvoyer.

Je mets les valeurs fixées à la création en immutable : elles sont dans le code et pas en
storage, donc moins cher à lire. Et dans countListed, je ne fais que lire (view) sans écrire dans
la boucle.
