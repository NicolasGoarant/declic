puts '=== OPPORTUNITIES ==='
Opportunity.where(is_active: true).find_each do |o|
  next if o.description.blank?
  [1,2,3].each do |i|
    marker = "<!-- IMAGE_#{i} -->"
    if o.description.include?(marker)
      unless o.send("inline_image_#{i}").attached?
        puts "  [opp ##{o.id}] #{o.title.truncate(50)} — IMAGE_#{i} orpheline"
      end
    end
  end
end

puts ''
puts '=== STORIES ==='
Story.where(is_active: true).find_each do |s|
  next if s.body.blank?
  [1,2,3].each do |i|
    marker = "___INLINE_PHOTO_#{i}_PLACEHOLDER___"
    if s.body.include?(marker)
      unless s.send("inline_image_#{i}").attached?
        puts "  [story ##{s.id}] #{s.title.truncate(50)} — PHOTO_#{i} orpheline"
      end
    end
  end
end
