module StoriesHelper
  def safe_excerpt(text, words: 25)
    text.to_s.split(/\s+/).first(words).join(" ")
  end
end
