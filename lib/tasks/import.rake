require 'github'

namespace :import do
  desc 'Store new repos'
  task :repos, [:from, :to] => [:environment] do |_, args|
    github_config = YAML.load_file("#{Rails.root}/config/omniauth.yml")[Rails.env]['github']
    store_data(github_config)
  end

  def store_data(github_config)
    basic_auth = "#{github_config['app_id']}:#{github_config['secret']}"
    client = GitHub::Repo.new(basic_auth)

    last_id = Repository.order_by(id: 'desc').first.try(:id)
    repos = client.list(last_id ? last_id : nil)
    since = repos.last['id']

    while since do
      repos.each do |repo|
        Repository.find_or_create_by(repo)
      end
      repos = client.list(since)
      since = repos.last['id']
    end
  end
end
