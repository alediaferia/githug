require 'lrclassifier'
require 'github_api'

class RepoClassifier < LRClassifier

  def initialize
    super
    @t_train_data = Array.new # temporary train data
    @train_data = Array.new
    @used_features  = Set.new
  end

  # features is a hash with all the features
  # of a single repo
  #
  # fact is a value between 0 and 1
  def collect_train_data(features, fact)
    features.keys.each { |k| @used_features.add?(k) }
    @t_train_data.push([features, fact])
  end

  def train!
    @train_data = []
    @t_train_data.each { |d|
      row = Array.new
      row << 0
      row << d[1]
      @used_features.each { |k|
        if d[0].include?(k)
          row << d[0][k]
        else
          row << 0
        end
      }
      @train_data << row
    }

    set_train_data(@train_data)
    train
  end

  def rank(repos)
    tmp_class_data = []
    repos.each do |repo|
      begin
        langs = Github.repos.languages(user: repo.owner['login'], repo: repo.name)
        langs = langs.body

        row = []
        row << "#{repo.owner['login']}/#{repo.name}"
        @used_features.each { |k|
          if langs.include?(k)
            row << langs[k]
          else
            row << 0
          end
        }
        tmp_class_data.push row
      rescue Exception
        next
      end
    end

    return [] if tmp_class_data.empty?

    results = classify(tmp_class_data).to_a
    interesting_repos = []
    0.upto results.length - 1 do |i|
      interesting_repos << [tmp_class_data[i][0], results[i][0]]
    end
    interesting_repos
  end
end
