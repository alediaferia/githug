module GitHub
  class Repo
    # basic auth "client_id:client_secret"
    def initialize(basic_auth)
      @client_id, @client_secret = basic_auth.split(":")
    end

    def list(since = nil)
      # GET https://api.github.com/repositories
      response = client.get "/repositories?since=#{since}&client_id=#{@client_id}&client_secret=#{@client_secret}"
      return [] if response.headers['X-RateLimit-Remaining'].to_i <= 0
      return JSON.parse(response.body)
    end

    def client
      conn = Faraday.new(:url => 'https://api.github.com') do |faraday|
        faraday.request  :url_encoded             # form-encode POST params
        faraday.response :logger                  # log requests to STDOUT
        faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
      end
      conn
    end
  end
end
