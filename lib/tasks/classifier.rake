require 'repo_classifier'
require 'github_api'

def normalize_repo_features(features)
  normalized_features = {}
  features.each do |k, v|
    normalized_features[k] ||= 0

    rank = (v.to_i / 30)
    # following +10 is because we are owner for the repo
    normalized_features[k] = rank
  end

  normalized_features
end

namespace :classifier do
  desc 'Trans a classifier for the specified user and dumps it into the db'
  task :train, [:username] => :environment do |_, args|
    user_record = User.find_by(username: args.username)
    Github.configure do |c|
      c.user = args.username
      c.oauth_token = user_record.access_token
    end

    classifier = RepoClassifier.new

    # fetching user's repositories
    Github.repos(user: args.username).list.each do |repo|
      langs = Github.repos.languages user: args.username, repo: repo.name
      langs = langs.body

      classifier.collect_train_data(normalize_repo_features(langs), 0.9)
    end

    # fetching user's timeline activity (received events from outside)
    Github.activity.events.received(user: args.username).select{ |event| ["WatchEvent"].include?(event.type)}.each do |event|
      repo = event.repo
      owner, name = repo.name.split('/')
      starring = Github.activity.starring.starring?(user: owner, repo: name)
      if starring
        classifier.collect_train_data(normalize_repo_features(Github.repos.languages(user: owner, repo: name).body), 1)
      else
        classifier.collect_train_data(normalize_repo_features(Github.repos.languages(user: owner, repo: name).body), 0.1)
      end
    end

    Github.activity.starring.starred.body.each { |repo|
      classifier.collect_train_data(normalize_repo_features(Github.repos.languages(user: repo.owner.login, repo: repo.name).body), 1)
    }

    # now we can train the classifier
    classifier.train!

    # now we can marshal the classifier and store it into the db
    user_record.classifier ||= Classifier.new
    user_record.classifier.instance = BSON::Binary.new(Marshal::dump(classifier))
    user_record.classifier.save
    user_record.save
  end

  desc 'Classifies randomly ~1000 repositories and stores them in the database for the user'
  task :classify, [:username] => :environment do |_, args|
    user_record = User.find_by(username: args.username)
    if !user_record.classifier
      puts "Cannot fiend classifier for user: train one first, please"
      break false
    end
    # now we are going to randomly pick at most 1000 repositories for classifying them
    # for the specified user
    repos = (0..Repository.count-1).sort_by{rand}.slice(0, 500).collect! { |i| Repository.skip(i).first }.reject{ |repo| repo.owner['login'] == args.username }

    Github.configure do |c|
      c.user = args.username
      c.oauth_token = user_record.access_token
    end

    classifier = user_record.classifier.loaded_instance
    classifier.rank(repos).each do |repo|
      r = Repository.find_by(full_name: "#{repo[0]}")
      interest = Interest.new
      interest.repository = r
      interest.rank = repo[1]
      interest.save
      user_record.interests.append(interest)
    end
  end
end
