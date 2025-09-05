class Source < ApplicationRecord
  has_many :raw_ingestions, dependent: :destroy
  validates :name, :kind, :url, presence: true
end
