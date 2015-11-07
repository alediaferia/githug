require 'lrclassifier'

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
    langs.keys.each { |k| @used_keys.add?(k) }
    @t_train_data.push([langs, fact])
  end

  def train!
    @train_data = []
    @t_train_data.each { |d|
      row = Array.new
      row << 0
      row << d[1]
      @used_keys.each { |k|
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

  def eval(repos)
    tmp_class_data = []
    repos.each do |repo|
      langs = Github.repos.languages(user: $cf_user, repo: repo.name)
      langs = langs.body

      row = []
      row << "#{$cf_user}/#{repo.name}"
      @used_keys.each { |k|
        if langs.include?(k)
          row << langs[k]
        else
          row << 0
        end
      }
      tmp_class_data.push row
    end
    results = classify(tmp_class_data)
  end
end
