class Repository
  include Mongoid::Document
  include Mongoid::Attributes::Dynamic

  def languages(access_token = nil)
    owner, repo = full_name.split("/")
    url =
      if access_token
        "https://api.github.com/repos/#{owner}/#{repo}/languages?access_token=#{access_token}"
      else
        "https://api.github.com/repos/#{owner}/#{repo}/languages"
      end
    response = Faraday.get url
    JSON.parse(response.body)
  end
end
