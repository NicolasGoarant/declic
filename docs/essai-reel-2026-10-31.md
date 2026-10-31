# Essai réel du 31/10/2026 — articles Gazette (#143 à #150)

Source de tous les articles : **La Gazette France** (rubrique Meurthe-et-Moselle), collectés par `Connectors::GazetteFrance`, enrichis par `AiEnricher` (Haiku), brouillons par `Redaction::Brouillon` (Sonnet). Les titres sont tronqués (« … ») comme en base. Les motifs sont ceux du modèle, repris tels que journalisés (coupés à ~120 caractères quand ils étaient longs). Classement relevé après les ajustements de prompt (`151e914`).

| # | Sujet | Classement | Motif |
|---|---|---|---|
| 143 | Congrès national des EPL à Nancy | écarté (hors ligne) | Annonce institutionnelle d'un congrès professionnel, sans récit inspirant ni appel à agir pour un public citoyen |
| 144 | Ateliers « Bienvenue à la retraite » (Afpa Nancy Laxou, Carsat) | opportunité (confiance 65) | Programme de formation gratuite, public identifié, mais sans dates ni modalités précises d'inscription |
| 145 | « Délices & Saveurs » et « Puces Internationales » | écarté (hors ligne) | Annonce commerciale d'un salon sans dates précises ni appel à action individuel, faute d'élément inspirant |
| 146 | Vente d'une pâtisserie presque centenaire (Batt Advisors) | écarté (hors ligne) | Simple annonce de cession d'entreprise, fait économique sans récit incarné d'engagement ou d'initiative personnelle |
| 147 | Nouveau directeur de la formation Ingénieur civil, Mines Nancy | écarté (hors ligne) | Simple nomination professionnelle sans parcours ni dimension inspirante particulière |
| 148 | Nuit de la Création à Laxou | opportunité (confiance 70) | Événement avec appel à participer et date (8 octobre), année non précisée |
| 149 | La Métropole du Grand Nancy fait condamner Booking.com | écarté (hors ligne) | Actualité juridique et contentieuse (condamnation), explicitement exclue par la règle éditoriale |
| 150 | Le SMPS et la santé mentale des dirigeants hospitaliers | opportunité (confiance 45) | Événement professionnel à Nancy invitant à participer, mais sans date ni horaire |

Aucune belle histoire n'est donc à rédiger sur ce lot.

## Liens

- #143 <https://www.lagazettefrance.fr/article/le-congres-national-des-epl-s-ouvre-a-nancy-au-centre-des-congres-prouve-le-14-octobre>
- #144 <https://www.lagazettefrance.fr/article/l-afpa-de-nancy-laxou-et-la-carsat-lancent-les-ateliers-bienvenue-a-la-retraite>
- #145 <https://www.lagazettefrance.fr/article/nancy-delices-saveurs-et-puces-internationales-booste-le-commerce-regional>
- #146 <https://www.lagazettefrance.fr/article/nancy-batt-advisors-boucle-la-vente-de-la-patisserie-centenaire-recouvreur>
- #147 <https://www.lagazettefrance.fr/article/un-nouveau-directeur-de-la-formation-ingenieur-civil-est-nomme-a-mines-nancy>
- #148 <https://www.lagazettefrance.fr/article/nuit-de-la-creation-a-laxou-le-nouveau-visage-des-porteurs-de-projets>
- #149 <https://www.lagazettefrance.fr/article/la-metropole-du-grand-nancy-fait-condamner-la-plateforme-booking-com>
- #150 <https://www.lagazettefrance.fr/article/nancy-le-smps-au-chevet-de-la-sante-mentale-des-dirigeants-hospitaliers>

## Brouillons rédigés

### #146 — version actuelle (courte et sobre)

Produite après la consigne « rien hors source », sur #146 remis à la main en `retenu` (le classement l'écarte). 63 mots, 0,011 $. Contrôles : aucun bloquant ; avertissements `longueur` (63 mots, minimum 90) et `champs_manquants`.

> Au 11, rue de la Faïencerie, à Nancy, une pâtisserie tenue par la famille Bédard depuis 1965 vient de changer de mains. La cession a été finalisée par le cabinet Batt Advisors, mettant fin à six décennies de présence familiale à cette adresse du quartier. Cette page qui se tourne concerne un commerce resté identifié comme une référence locale pendant toute cette période.
>
> Source : La Gazette France — <https://www.lagazettefrance.fr/article/nancy-batt-advisors-boucle-la-vente-de-la-patisserie-centenaire-recouvreur>
> Accord de la personne : à obtenir

Fidélité : les faits (adresse, famille Bédard, 1965, Batt Advisors, cession) sont dans la source. Deux libertés : « six décennies » est calculé, et « référence locale pendant toute cette période » extrapole « emblématique ».

### Anciens brouillons (avant les ajustements, à titre de comparaison)

Ces trois textes ont été rédigés avant le retrait des généralités de remplissage et avant l'exclusion hors ligne. #147 et #149 ne seraient plus rédigés.

**#146 — première version (~120 mots, remplissage)**

> Au 11, rue de la Faïencerie à Nancy, une pâtisserie presque centenaire vient de changer de mains. Depuis 1965, c'est la famille Bédard qui en assurait la direction, perpétuant une adresse devenue familière dans le quartier. La cession de cet établissement, accompagnée par le cabinet Batt Advisors, met un terme à plusieurs décennies de gestion familiale et ouvre un nouveau chapitre pour ce commerce de proximité. Cette transmission illustre les mutations que connaît le tissu commercial nancéien, où des enseignes anciennes trouvent de nouveaux repreneurs pour poursuivre leur histoire. L'adresse, connue de longue date des habitants, conserve ainsi sa vocation de pâtisserie au cœur de la ville.

Les phrases « ouvre un nouveau chapitre » et « illustre les mutations… tissu commercial » n'étaient pas dans la source.

**#147 — première version (statut : rédigé)**

> À Nancy, François Lesage prend la direction de la formation Ingénieur civil de Mines Nancy. Enseignant-chercheur, il rejoint cet établissement après avoir exercé à l'ENSIC, l'École nationale supérieure des industries chimiques. Sa nomination marque une nouvelle étape pour ce programme de formation d'ingénieurs, désormais placé sous sa responsabilité. Fort de son expérience académique acquise à l'ENSIC, il apporte à Mines Nancy un regard nourri par son parcours d'enseignant-chercheur. Cette arrivée s'inscrit dans la vie de l'école nancéienne, qui voit ainsi son équipe de direction se renouveler avec l'intégration de ce spécialiste venu d'un autre établissement d'enseignement supérieur de la région.

**#149 — première version (statut : à vérifier, bloquant `contact` sur « Booking.com », faux positif corrigé depuis)**

> La Métropole du Grand Nancy a engagé une procédure contre la plateforme Booking.com, portant sur l'encadrement des meublés de tourisme proposés en ligne sur son territoire. Cette démarche visait à mieux réguler l'essor de ce type d'hébergements, mis en avant via la plateforme, dans l'agglomération nancéienne. L'action intentée par la collectivité a abouti à la condamnation de Booking.com. Cette décision marque une étape dans les efforts de la Métropole pour maîtriser le développement des locations touristiques de courte durée sur son territoire, un phénomène suivi de près par les collectivités locales confrontées à la multiplication de ces offres sur les plateformes numériques.

## Coût

Total du mois après les essais : environ 0,07 $ sur le plafond de 15 $.
