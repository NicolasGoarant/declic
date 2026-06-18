# Idempotent: met à jour la pépite "Pitch Night" vers l'édition du 25 juin 2026.
# Usage: bin/rails runner script/update_pitch_night.rb

NEW_ATTRS = {
  title: "Pitch Night — Grand Nancy Innovation",
  description: "Testez votre pitch, challengez votre projet ou découvrez les pépites de l'écosystème. Soirée organisée par Grand Nancy Innovation. Inscription gratuite mais obligatoire.",
  category: "entreprendre",
  organization: "Grand Nancy Innovation",
  location: "ORBOR, 5 rue Jacques Villermaux, 54000 Nancy",
  address: "5 rue Jacques Villermaux",
  city: "Nancy",
  postal_code: "54000",
  starts_at: DateTime.new(2026, 6, 25, 17, 0),
  ends_at:   DateTime.new(2026, 6, 25, 19, 0),
  cta_button_url: "https://lnkd.in/ehrhXkGP",
  cta_button_text: "S'inscrire",
  is_active: true,
}.freeze

matches = Opportunity.where("title LIKE ?", "%Pitch Night%").to_a
abort "❌ Aucune pépite Pitch Night trouvée." if matches.empty?
abort "❌ Plusieurs pépites Pitch Night trouvées (#{matches.map(&:id).join(', ')}). Aborté." if matches.size > 1

o = matches.first

puts "── AVANT (id=#{o.id}) ──"
NEW_ATTRS.each_key { |k| puts "  #{k}: #{o.public_send(k).inspect}" }
puts "  latitude: #{o.latitude.inspect}"
puts "  longitude: #{o.longitude.inspect}"

o.assign_attributes(NEW_ATTRS)

# Si le lieu a changé, on force un re-geocoding en effaçant les coordonnées.
if o.location_changed?
  o.latitude = nil
  o.longitude = nil
end

if o.changed?
  o.save!
  puts "✅ Mise à jour effectuée."
else
  puts "ℹ️  Aucune modification (déjà à jour)."
end

o.reload
puts "── APRÈS (id=#{o.id}) ──"
NEW_ATTRS.each_key { |k| puts "  #{k}: #{o.public_send(k).inspect}" }
puts "  latitude: #{o.latitude.inspect}"
puts "  longitude: #{o.longitude.inspect}"
puts "  slug: #{o.slug.inspect}"
