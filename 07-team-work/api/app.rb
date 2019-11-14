require "sinatra"
require "sinatra/json"
require "sinatra/link_header"
require "sinatra/namespace"
require "sinatra/reloader" if development?

require "sqlite3"

enable :static

DB_PATH = File.join(__dir__, "db/team_building.sqlite")
DB      = SQLite3::Database.new(DB_PATH)
DB.results_as_hash = true

get "/" do
  json "name" => "Team Building API", "status" => "Running"
end

namespace "/v1" do
  get "/activities" do
    activities = DB.execute("SELECT * FROM activities ORDER BY name")
    json "activities" => activities
  end

  get "/activities/:id" do
    id         = params["id"].to_i
    activities = DB.execute("SELECT * FROM activities WHERE id = ?", id)
    activity   = activities.first

    json "activity" => activity
  end
end

namespace "/v2" do
  get "/activities" do
    # [POSSIBLE QUERIES]
    # 1. SELECT * FROM activities ORDER BY name
    # 2. SELECT * FROM activities WHERE lower(name) LIKE "%Escape Game%" ORDER BY name
    # 3. SELECT * FROM activities WHERE city = "Nantes" ORDER BY name
    # 4. SELECT * FROM activities WHERE category = "Adventure" ORDER BY name
    # 5. SELECT * FROM activities WHERE lower(name) LIKE "%Escape Game%" AND city = "Nantes" AND category = "Adventure" ORDER BY name

    conditions = []
    filters    = {}

    if params["search"] && !params["search"].empty?
      conditions << "lower(name) LIKE :search"
      filters["search"] = "%#{params["search"]}%".downcase
    end

    if params["category"] && !params["category"].empty?
      conditions << "category = :category"
      filters["category"] = params["category"]
    end

    if params["city"] && !params["city"].empty?
      conditions << "city = :city"
      filters["city"] = params["city"]
    end

    if filters.empty?
      query = "SELECT * FROM activities ORDER BY name"
    else
      query = "SELECT * FROM activities WHERE #{conditions.join(" AND ")} ORDER BY name"
    end

    activities = DB.execute(query, filters)

    json "activities" => activities
  end

  get "/activities/:id" do
    id         = params["id"].to_i
    activities = DB.execute("SELECT * FROM activities WHERE id = ?", id)
    activity   = activities.first

    sites_favorited = DB.execute("SELECT s.id as id, s.name as name FROM sites as s JOIN site_favorite_activities as sfa ON sfa.site_id = s.id WHERE sfa.activity_id = ?", id)
    sites = DB.execute("SELECT id,name FROM sites;")

    sites.each do |site|
      if sites_favorited.any? {|site_favorited| site["id"] == site_favorited["id"] }
        site["isFavorite"] = true
      else
        site["isFavorite"] =false
      end
    end
    activity["sites"] = sites
    json "activity" => activity
  end
end

namespace "/doc" do
  get { erb :"doc/index" }

  namespace "/v1" do
    get "/activities" do
      erb :"doc/v1/activities"
    end
  end

  namespace "/v2" do
    get "/activities" do
      erb :"doc/v2/activities"
    end
  end
end

namespace "/services" do
  get "/sites" do
    sites = DB.execute("SELECT * FROM sites;")
    json "sites" => sites
  end
end
