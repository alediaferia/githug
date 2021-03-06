class Repository
  include Mongoid::Document
  include Mongoid::Attributes::Dynamic

  attr_accessor :langs, :stars

  belongs_to :interest
  has_one :language
  
  def languages(oauth_token = nil)
    github =
     if oauth_token
       Github.new(oauth_token: oauth_token)
     else
       Github.new
     end
    owner, repo = full_name.split("/")
    languages = github.repos.languages owner, repo
    languages
  end

  def stargazers(oauth_token = nil)
    owner, repo = full_name.split("/")
    url =
     if oauth_token
       "https://api.github.com/repos/#{owner}/#{repo}/stargazers?oauth_token=#{oauth_token}"
     else
       "https://api.github.com/repos/#{owner}/#{repo}/stargazers"
     end
    stargazers = Faraday.get(url)
    JSON.parse(stargazers.body)
  end

  def stargazers_count(oauth_token = nil)
    owner, repo = full_name.split("/")
    url =
     if oauth_token
       "https://api.github.com/repos/#{owner}/#{repo}?oauth_token=#{oauth_token}"
     else
       "https://api.github.com/repos/#{owner}/#{repo}"
     end
    stargazers = Faraday.get(url)
    JSON.parse(stargazers.body)['stargazers_count']

  end

  def forks(oauth_token = nil)
    github =
     if oauth_token
       Github.new(oauth_token: oauth_token)
     else
       Github.new
     end
    owner, repo = full_name.split("/")
    forks = github.repos.forks owner, repo
    forks
  end
end
