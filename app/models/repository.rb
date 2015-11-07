class Repository
  include Mongoid::Document
  include Mongoid::Attributes::Dynamic

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
end
