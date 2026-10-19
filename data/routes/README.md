# Données des parcours

`demo_routes.json` est le catalogue de version 1. Il contient deux tableaux indépendants, dont le Circuit des Équinoxes et ses six adversaires. Ces données ne contiennent aucun résultat de match.

## Ajouter un parcours

Ajouter une entrée dans `routes`, avec `id`, `name`, `description`, `accent_color`, `nodes` et `edges`. Les identifiants sont stables, uniques dans leur espace et utilisent `a-z`, `0-9` et `_`. Les identifiants des joueurs sont uniques dans tout le catalogue.

Chaque nœud possède `id`, `type`, `name`, `position: [x, y]`, `requires` et `rewards`. Les positions sont des pixels sur le tableau déroulant. Prévoir au moins 250 pixels entre deux cartes horizontalement et 170 verticalement.

- `match` : ajouter `team_id` et `recommended_level`.
- `branch` : bifurcation accessible lorsque ses conditions sont remplies.
- `gate` : condition de passage ; les nœuds suivants peuvent la référencer.
- `reward` : coffre dont les récompenses sont dans `rewards.claim`.

`edges` est un tableau de paires `["départ", "arrivée"]` pour le dessin. **Les liaisons visuelles ne constituent pas des conditions d'accès** : les préciser dans `requires`.

Les conditions de `requires` sont cumulatives. `requires_any`, facultatif, demande au moins une condition satisfaite, en plus de toutes celles de `requires`.

```json
{
  "requires": [{"node": "quartz", "rank": "B"}, {"node": "midnight", "rank": "B"}],
  "requires_any": [{"node": "quartz", "rank": "A"}, {"node": "midnight", "rank": "A"}]
}
```

Une référence à un match sans `rank` exige sa victoire. Un rang exige au moins ce rang historique. Une référence à un `gate` ou `branch` exige son déblocage ; une référence à un coffre exige sa récupération. `{ "flag": "identifiant" }` permet un déblocage spécial fourni par le jeu. Les nœuds sans condition sont disponibles au départ. Une victoire passée suffit toujours, sans obliger à rejouer le chemin.

## Ajouter une équipe

Ajouter une entrée dans `teams` avec un emblème `res://`, les couleurs `kit_color`, `keeper_color` et `accent_color`, un `recommended_level`, une `formation` (`balanced`, `wide` ou `press`), un profil `ai` et `half_seconds` (durée d'une période). La démonstration utilise deux périodes de 300 secondes.

Le tableau `players` contient exactement onze profils : le gardien en premier, puis dix joueurs de champ. Chaque profil définit `id`, `name`, `shirt_number`, `stats` (`shot`, `dribble`, `technique`, `defense`, `keeper`), `run_speed`, `sprint_speed`, `skin_color`, `hair_color`, `techniques` et, facultativement, `karmas`. Les références de techniques sont vérifiées dans le catalogue de contenu existant.

```json
"ai": {"pressure": 0.2, "shoot_distance": 21, "shot_charge": 0.65, "sprint_distance": 8}
```

`IEGRouteCatalog.build_roster(team_id)` réutilise `IEGMatchRoster.build()` et conserve tous les profils alliés. Il remplace seulement les onze adversaires par des `IEGPlayerProfile`. Les positions de départ restent neutres ; le moteur existant applique la formation au coup d'envoi et à la mi-temps. Le dictionnaire retourné contient aussi `opponent`, `team_name`, `emblem`, `formation`, `ai` et `half_seconds` pour configurer cette même rencontre.

## Rangs et récompenses

Les règles uniques sont dans `rank_rules` :

```json
{"a_goal_difference": 3, "s_goals_for": 5, "s_goals_against": 0}
```

`IEGRouteRank.calculate()` renvoie une chaîne vide pour un nul, une défaite ou des buts négatifs. Lors d'une victoire, S est prioritaire : au moins `s_goals_for` buts marqués et au plus `s_goals_against` encaissés. Sinon, l'écart demandé donne A ; les autres victoires donnent B. `value()` compare les rangs : aucun = 0, B = 1, A = 2, S = 3. Les données invalides sont refusées par le catalogue ; les appels directs au calcul conservent les valeurs par défaut lorsqu'un seuil fourni est invalide.

Une récompense possède `id`, `type`, `amount`, `name`, `min_rank` et `chance`. Types disponibles : `currency`, `xp`, `item`, `technique`, `equipment`, `recruitment`. `chance` va de 0 à 1. `first_win` s'applique à la première victoire, `repeat` aux victoires rejouables et `claim` aux coffres. Les identifiants de techniques doivent être les identifiants du catalogue ; les objets, équipements et éléments de recrutement sont des entrées d'inventaire extensibles.

Le catalogue valide les références, doublons, tableaux de onze joueurs, couleurs, nombres finis, récompenses et cycles de dépendance/liaisons avant de remplacer ses données. `load_document()` permet une injection atomique pour les tests et outils futurs. La sauvegarde du joueur reste séparée du catalogue.
