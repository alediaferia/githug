require 'repo_classifier'
require 'github_api'

namespace :classifier do
  desc 'Trans a classifier for the specified user and dumps it into the db'
  task :train, [:username] => :environment do |_, args|
    user = User.find_by(username: args.username)
    user.train
  end

  desc 'Classifies randomly ~1000 repositories and stores them in the database for the user'
  task :classify, [:username] => :environment do |_, args|
    user = User.find_by(username: args.username)
    user.classificator
  end

  desc 'Train and classify all users not yet classified'
  task :run, [:username] => :environment do |_, args|
    if args.username
      user = User.find_by(username: args.username)
      user.classify
      user.update_attributes(classified: true)
      UserMailer.interests(user).deliver_now
    else
      User.where(classified: false).each do |user|
        user.classify
        user.update_attributes(classified: true)
        UserMailer.interests(user).deliver_now
      end
    end
  end
end
