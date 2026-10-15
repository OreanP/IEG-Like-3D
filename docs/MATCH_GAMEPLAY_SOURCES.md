# Origine des règles du prototype de match

Cette livraison suit la demande de gameplay du 15 octobre 2026. Elle ne cherche
pas à reproduire exactement les formules ou le contenu d'Inazuma Eleven.

## Ce que la demande définit

- Un match chronométré, deux équipes, deux périodes et un changement de
  disposition à la mi-temps ; le résultat distingue victoire et égalité.
- Un affrontement interrompt le jeu et le chrono : choix gauche, droite ou
  technique, puis présentation des scores et du résultat avant la reprise.
- Le joueur dribblé reste immobile et devient semi-transparent pendant une
  seconde de jeu après la reprise.
- L'affrontement tireur/gardien présente le triangle de tir ; les gardiens ont
  une jauge d'endurance. Une déviation ne vaut pas possession.
- Huit techniques originales : Tir orbital, Tir Magnus, Lame de combat, Drift,
  Barrage ouragan, Aquablast, Arrêt photo et Arrêt Gyroscopique.
- Les animations de gardien partagent leur introduction puis divergent après
  l'affichage des scores, selon la réussite ou l'échec.
- Un éditeur Godot permet de consulter et modifier les techniques et les
  systèmes tactiques/de transformation du prototype.

## Choix propres à ce prototype

Les puissances, coûts, multiplicateurs, durées de présentation, règles de
direction, dimensions du terrain et dispositions sont des paramètres de jeu
originaux à ajuster après le playtest. Ils ne sont pas présentés comme des
statistiques officielles de Chrono Stones ou Galaxy.

Les systèmes de renforcement ont leurs propres noms et données. Leur présence
sert à tester des variantes de gameplay dans cet éditeur ; aucune animation,
ressource visuelle ou donnée propriétaire n'est copiée depuis ces jeux.

La simulation calcule le résultat. La présentation anime le résultat enregistré
et n'accorde ni but ni possession. Les alliés IA ne déclenchent ni passe ni tir ;
une vraie prise de possession alliée sélectionne immédiatement ce porteur.

## Consultation externe : limite constatée

Le 15 octobre 2026, les tentatives `curl` suivantes ont été refusées par le
réseau de cet environnement (HTTP 403, dont refus du tunnel CONNECT). Aucun
texte de ces pages n'a donc pu être lu ni cité. Les URL ci-dessous sont les
adresses essayées, pas des sources vérifiées pour les règles de cette livraison :

- [Page Nintendo recherchée, Chrono Stones Wildfire](https://www.nintendo.com/en-gb/Games/Nintendo-3DS-games/INAZUMA-ELEVEN-GO-Chrono-Stones-Wildfire-965350.html)
- [Adresse de manuel Nintendo Europe essayée](https://cdn02.nintendo-europe.com/media/downloads/games_8/emanuals/nintendo_3ds_2/inazumaelevengochronostones/emanual_3ds_inazumaelevengochronostones_fr.pdf)
- [Article Wikipedia Chrono Stone](https://en.wikipedia.org/wiki/Inazuma_Eleven_GO_2:_Chrono_Stone)
- [Wiki communautaire : Miximax](https://inazuma-eleven.fandom.com/wiki/Miximax)
- [Wiki communautaire : Duel](https://inazuma-eleven.fandom.com/wiki/Duel)
- [GameFAQs Chrono Stone](https://gamefaqs.gamespot.com/3ds/669358-inazuma-eleven-go-2-chrono-stone-neppuu/faqs)
- [Site japonais officiel Level-5 : Galaxy](https://www.inazuma.jp/go/galaxy/)
- [Site japonais officiel Level-5 : Chrono Stones](https://www.inazuma.jp/go2/)
- [Article Wikipedia Galaxy](https://en.wikipedia.org/wiki/Inazuma_Eleven_GO:_Galaxy_(video_game))

Il reste donc à comparer les sensations avec une capture de gameplay ou un
manuel effectivement consultable. Cette limitation n'empêche pas de tester les
règles explicitement demandées et les systèmes originaux de la livraison.
