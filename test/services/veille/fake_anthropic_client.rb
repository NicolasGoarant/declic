# Doublure d'AnthropicClient partagée par les tests de service.
# Aucun appel réseau : elle rend le texte qu'on lui a confié et retient
# les paramètres reçus pour qu'on puisse les inspecter.
class FakeAnthropicClient
  attr_reader :calls

  def initialize(text: nil, raise_with: nil, usage: nil)
    @usage      = usage
    @text       = text
    @raise_with = raise_with
    @calls      = []
  end

  def messages(**kwargs)
    @calls << kwargs
    raise @raise_with if @raise_with

    reponse = { "content" => [{ "type" => "text", "text" => @text }] }
    reponse["usage"] = @usage if @usage
    reponse
  end

  def last          = @calls.last
  def user_content  = last[:messages].first[:content]
  def system_prompt = last[:system]
end
