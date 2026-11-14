# Rapport — sécurité, coût et qualité du tri (veille-sources-v2, 11/11/2026)

## En tête : deux constats
1. **Clé API : rien à purger.** `git log --all -p -G'sk-ant-…'` : aucune clé réelle dans l'historique de aucune branche (seul un exemple `sk-ant-...` dans `lib/tasks/ai.rake`). `.env` est ignoré et n'a jamais été commité ; aucune clé dans l'arbre de travail. Les clés vivent dans `.env` (ANTHROPIC_API_KEY, MAPTILER_KEY, MAPBOX_TOKEN, ADMIN_*). Clé affichée en clair le 02/11 : **régénérée le 11/11** (`.env` modifié le 11/11 à 19:19, la clé se termine par `EwAA`). Reste à vérifier la valeur sur Heroku et à supprimer l'ancienne clé dans la Console Anthropic.
   `NOTES.md` n'est **pas** dans `.gitignore` : il est suivi (c'est la mémoire de travail commitée, et il ne contient aucun secret). Pas modifié ; à décider.
2. **Les CGU d'ICI et de France 3 s'opposent à l'usage par IA : mon classement précédent (« non opposée ») était faux.** Corrigé : les deux flux sont `restreinte`, le connecteur n'a plus aucune source, le banc d'essai n'a **pas** été lancé sur ces flux.

## Étape 0 — inventaire
Briques réutilisées : `AiEnricher`, `Runner`, `Cout`/`Plafond`/`AppelIa`, `AnnuairePresse`, `FluxPresse`, `XlsxImporter` (inchangé). `Connectors::Presse` = lecture humaine, non lancé. Avant cette session, `FluxPresse` lisait **ICI Lorraine et France 3 Nancy uniquement** ; L'Est Républicain, Républicain Lorrain, Vosges Matin et Actu étaient déjà écartés (rien à désactiver). `veille-auto` est contenue dans `main`.

## Étape 5 — CGU relues (11/11/2026, texte récupéré sur les pages)
- **ICI** (Radio France + France Télévisions) : https://www.ici.fr/mentions-legales, « Conditions générales d'utilisation de la plateforme dédiée à l'offre numérique de proximité », **art. VII « Utilisation des contenus »** : « ne peuvent pas non plus être utilisés par des logiciels et/ou système d'intelligence artificielle pour générer du contenu dans le cadre des requêtes formulées par leurs utilisateurs », et pas d'usage « à des fins d'entraînement ou de développement de tout logiciel ou système d'apprentissage automatique ou d'intelligence artificielle […] sans l'autorisation écrite et préalable de RADIO FRANCE et de FRANCE TELEVISIONS, y compris lorsque le but poursuivi est non commercial » ; art. IX-1 : même interdiction. **Conclusion : opposition.**
- **France 3 Nancy** (France Télévisions) : https://www.francetelevisions.fr/cgu et https://www.franceinfo.fr/cgu.html, **art. 13 « Politique de fouille de textes et de données (Text And Data Mining Policy) < TDM-RESERVATION: 1> »** : « France Télévisions s'oppose à toutes opérations de moissonnage et de fouille de textes et de données au sens de l'article L. 122-5-3 du code de la propriété intellectuelle » ; 13.2 : accès automatisé « dans le but d'extraire, copier, réutiliser, analyser ou entraîner un système algorithmique ou un modèle ou système d'intelligence artificielle » interdit sans autorisation écrite. **Conclusion : opposition.**
- Pour réutiliser : demander l'accord écrit à Radio France / France Télévisions (GIE « Numérique de proximité »).

## Étapes 2 à 4 — faites (tests : 540 verts)
- Préfiltre (`config/veille/prefiltre.yml`) et journal « reçus / retenus / écartés ». Limité à la presse (les sources d'agenda et de communes sont déjà locales).
- Haiku 5.5 par défaut, escalade Sonnet 5.5 sur 40-70, Opus par configuration ; plafond `VEILLE_BUDGET_MENSUEL` (15 $) ; bandeau + compte des « non triés » dans `/admin/veille`.
- `VEILLE_PRESSE_ACTIVE` (faux par défaut).

## Étape 6 — banc d'essai : script prêt ; lancé le 11/11 sur sources autorisées (voir plus bas), jamais sur la presse
Lancer 40 éléments de ces deux flux dans l'API serait précisément l'usage interdit, et la lecture automatisée du flux l'est aussi. Le script (`rake veille:banc_essai`, `Veille::BancEssai`) refuse ces origines. Il peut tourner sur des éléments autorisés déjà en base (par défaut `agenda_nancy:20,communes:20`) : accord à donner. Coût attendu : environ 0,5 $ au total. Estimations (non mesurées) : Haiku ≈ 0,08 $/100 éléments, Sonnet ≈ 1,5 $/100.

## Banc d'essai mesuré (11/11/2026, 26 éléments, `rapports/banc-essai-2026-11-11.csv`)
- Éléments : 20 de `agenda_nancy` + les **6** Belles Histoires actives en base (et non 20 : il n'y en a que 6). Origine `communes` : **aucun candidat en base locale**, donc non testée. Presse (ICI, France 3) : non lancée, CGU.
- **Coût mesuré pour 100 éléments : Haiku 5.5 ≈ 0,097 $ ; Sonnet 5.5 ≈ 1,534 $** (total du banc : 0,025 $ et 0,399 $). Estimation initiale (0,08 / 1,5 $) confirmée.
- **Accord de type : 53,8 %** (14/26), écart moyen de score 11 points. Belles Histoires : 6/6 reconnues par les deux modèles (100 %). Agenda : accord 8/20 seulement.
- Cause du désaccord : Haiku classe 14 des 20 éléments d'agenda « hors ligne » (Sonnet : 2) ; Sonnet les range en opportunité (scores 55-80). Haiku seul écarterait donc beaucoup d'événements d'agenda ; la colonne « avis de Nicolas » du CSV doit trancher qui a raison avant de fixer le seuil d'escalade.
