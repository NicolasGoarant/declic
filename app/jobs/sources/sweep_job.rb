# frozen_string_literal: true
class Sources::SweepJob < ApplicationJob
  queue_as :ingest

  def perform
    Source.active.find_each do |src|
      Sources::FetchJob.perform_later(src.id)
    end
  end
end
