require 'lrclassifier'

namespace :classifier do
  desc 'Trans a classifier for the specified user and dumps it into the db'
  task :train, [:username] => :environment do |_, args|

  end
end
