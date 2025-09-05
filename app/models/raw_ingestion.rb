class RawIngestion < ApplicationRecord
  belongs_to :source
  serialize :payload, JSON
end
