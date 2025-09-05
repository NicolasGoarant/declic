# app/models/raw_ingestion.rb
class RawIngestion < ApplicationRecord
  belongs_to :source

  # Si la colonne est json/jsonb (PG) ou text (sqlite), ceci marche dans les deux cas
  attribute :payload, :json

  validates :external_id, presence: true
end
