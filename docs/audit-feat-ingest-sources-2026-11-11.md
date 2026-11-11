# Étape 1 — `origin/feat/ingest-sources` : mise à jour de l'audit (11/11/2026)

Lecture seule. Complète `audit-feat-ingest-sources-2026-10-28.md` (la branche avait déjà été auditée ; rien n'a bougé depuis).

- Un seul commit (`1113b30`, 22/09/2025, « diverses data »), **688 commits derrière `main`**. `veille-auto` est entièrement contenue dans `main` (0 commit d'avance, 29 de retard : `veille-sources-v2` part donc de `main`, qui est en prod).
- Aucun test, aucune doc ; erreurs avalées (`rescue => _`), pas de robots.txt, création directe et active d'`Opportunity`, 440+ commits de pages légales/navbar/carte sans rapport.
- **À reprendre (idée, pas le code)** : sources CCI Grand Nancy et Lorr'Up (entrepreneuriat), lecteur JSON-LD d'événements en liste. À réécrire comme `Veille::Connectors::*` (via `Veille::Http`, robots.txt, `Veille::Item`).
- **À reprendre en détail** : `Support::FrenchDateParser` (« jeudi 16 octobre 2025 de 09h30 à 11h30 »), utile aux sources HTML ; à tester d'abord (le cas « plage » est inatteignable : le cas 2 le masque).
- **À laisser** : `Ingest::*` (doublonne `RawIngester`), `Sources::*Job` + Sidekiq (la prod n'a pas de worker), pages légales, navbar, `_map`, `Gemfile` (sidekiq, nokogiri en double).
- Verdict : ne pas fusionner ; aucune urgence.
