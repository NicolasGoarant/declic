class EngagementImporter
  DEFAULT_LIMIT = 200

  def initialize(api: EngagementApi.new, logger: Rails.logger)
    @api = api
    @log = logger
  end

  # filters: { city:, keywords:, lat:, lon:, distance:, type: "benevolat" }
  # max_rows: limite de sécurité
  def import!(filters: {}, max_rows: 2000)
    skip   = 0
    limit  = DEFAULT_LIMIT
    total_imported = 0

    loop do
      params = filters.merge(limit: limit, skip: skip).compact
      json   = @api.get("/mission", params) # endpoint liste
      data   = Array(json["data"])
      total  = (json["total"] || data.length).to_i

      break if data.empty?

      data.each do |m|
        upsert_mission!(m)
        total_imported += 1
        break if total_imported >= max_rows
      end

      break if total_imported >= max_rows
      skip += limit
      break if skip >= total
      sleep 0.2 # courtoisie
    end

    total_imported
  end

  private

  def upsert_mission!(mission)
    attrs = EngagementMapper.to_opportunity_attrs(mission)
    rec   = Opportunity.find_or_initialize_by(source: attrs[:source], external_id: attrs[:external_id])
    rec.assign_attributes(attrs)
    rec.save!
  rescue => e
    @log.error("[engagement] upsert KO id=#{mission['_id']} : #{e.class} #{e.message}")
  end
end
