# Retombées médias du bloc « Déclic dans les médias » de la page d'accueil (/labo/accueil).
#
# Une citation réelle pointe toujours vers sa source (`url` obligatoire). `placeholder: true`
# marque une citation de démonstration : bandeau « Exemple de maquette », masquée en production.
#
# France Bleu Lorraine s'appelle ICI Lorraine depuis 2025 : même podcast, une seule carte.
class PassagePresse
  Definition = Data.define(:media, :precision, :logo, :citation, :action, :url, :placeholder)

  TOUS = [
    Definition.new(media: "ici", precision: "(France Bleu)", logo: "Radio_France.jpeg", action: "Écouter le podcast", placeholder: false,
                   citation: "Déclic, la plateforme qui veut créer du lien dans la métropole du Grand Nancy",
                   url: "https://www.radiofrance.fr/francebleu/podcasts/ici-ca-marche-ici-lorraine-meurthe-et-moselle-et-vosges/declic-la-plateforme-qui-veut-creer-du-lien-dans-la-metropole-du-grand-nancy-7222300"),
    Definition.new(media: "RCF Radio", precision: nil, logo: "RCF.jpeg", action: "Écouter l'émission", placeholder: false,
                   citation: "Le grand témoin régional — Déclic, l'initiative citoyenne qui cartographie les opportunités",
                   url: "https://www.rcf.fr/actualite/le-grand-temoin-regional/embed?episodeId=676550"),
    Definition.new(media: "L'Est Républicain", precision: nil, logo: "L'Est Républicain.png", action: "Lire l'article", placeholder: false,
                   citation: "Déclic, la plateforme qui recense les opportunités citoyennes près de chez vous",
                   url: "https://c.estrepublicain.fr/environnement/2026/04/10/declic-la-plateforme-qui-recense-les-opportunites-citoyennes-pres-de-chez-vous"),
    Definition.new(media: "Radio Fajet", precision: nil, logo: "radiofajet.png", action: "Écouter l'interview", placeholder: false,
                   citation: "Un écran tourné vers l'autre",
                   url: "https://radiofajet.net/2026/04/29/declic/")
  ].freeze

  def self.visibles(production: Rails.env.production?)
    production ? TOUS.reject(&:placeholder) : TOUS
  end
end
