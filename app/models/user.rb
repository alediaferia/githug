require 'repo_classifier'

class User
  include Mongoid::Document
  include Mongoid::Attributes::Dynamic
  include Mongoid::Slug

  TEMP_EMAIL_PREFIX = 'change@me'
  TEMP_EMAIL_REGEX = /\Achange@me/

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable, :omniauthable

  has_one :identity, dependent: :delete
  has_one :classifier, dependent: :delete
  has_many :interests, dependent: :delete

  ## Database authenticatable
  field :email,              type: String, default: ""
  field :encrypted_password, type: String, default: ""
  field :name,               type: String
  field :username,           type: String, default: ""
  slug :username
  field :password,           type: String, default: ""
  field :access_token,       type: String, default: ""
  field :classified,         type: Boolean, default: false

  ## Recoverable
  field :reset_password_token,   type: String
  field :reset_password_sent_at, type: Time

  ## Rememberable
  field :remember_created_at, type: Time

  ## Trackable
  field :sign_in_count,      type: Integer, default: 0
  field :current_sign_in_at, type: Time
  field :last_sign_in_at,    type: Time
  field :current_sign_in_ip, type: String
  field :last_sign_in_ip,    type: String
  field :github_starred,     type: Boolean

  def self.find_for_oauth(auth, signed_in_resource = nil)
    # Get the identity and user if they exist
    identity = Identity.find_for_oauth(auth)

    # If a signed_in_resource is provided it always overrides the existing user
    # to prevent the identity being locked with accidentally created accounts.
    # Note that this may leave zombie accounts (with no associated identity) which
    # can be cleaned up at a later date.
    user = signed_in_resource ? signed_in_resource : identity.user

    # Create the user if needed
    if user.nil?
      # Get the existing user by email if the provider gives us a verified email.
      # If no verified email was provided we assign a temporary email and ask the
      # user to verify it on the next step via UsersController.finish_signup
      email_is_verified = auth.info.email
      email = auth.info.email if email_is_verified
      user = User.where(email: email).first if email

      # Create the user if it's a new registration
      if user.nil?
        user = User.new(
          name: auth.extra.raw_info.name,
          avatar_url: auth.extra.raw_info.avatar_url,
          location: auth.extra.raw_info.location,
          username: auth.info.nickname || auth.uid,
          email: email ? email : "#{TEMP_EMAIL_PREFIX}-#{auth.uid}-#{auth.provider}.com",
          access_token: auth.credentials.token,
          password: Devise.friendly_token[0,20]
        )
        user.save!
      end
    else
      user.update_attributes(
        access_token: auth.credentials.token,
        avatar_url: auth.extra.raw_info.avatar_url,
        location: auth.extra.raw_info.location
      )
    end

    # Associate the identity with the user if needed
    if identity.user != user
      identity.user = user
      identity.save!
    end
    user
  end

  def repos
    Github.new(oauth_token: self.access_token).repos.list user: self.username
  end

  def languages
    languages = []
    self.repos.each do|repo|
      github = Github.new(oauth_token: self.access_token)
      owner, repo = repo['full_name'].split("/")
      languages.push (github.repos.languages owner, repo).body
    end
    languages.inject{|memo, el| memo.merge( el ){|k, old_v, new_v| old_v + new_v}}
  end

  def email_verified?
    self.email && self.email !~ TEMP_EMAIL_REGEX
  end

  def classify
    self.train
    self.classificator
  end

  def train
    Github.configure do |c|
      c.user = username
      c.oauth_token = self.access_token
    end

    repo_classifier = RepoClassifier.new

    # fetching user's repositories
    Github.repos(user: username).list.reject {|repo| repo.fork == true }.each do |repo|
      begin
        langs = Github.repos.languages user: username, repo: repo.name
      rescue
        next
      end
      langs = langs.body.merge(stargazers_count: repo.stargazers_count)

      repo_classifier.collect_train_data(normalize_repo_features(langs), 0.9)
    end

    # fetching user's timeline activity (received events from outside)
    Github.activity.events.received(user: username).select{ |event| ["WatchEvent"].include?(event.type)}.each do |event|
      repo = event.repo
      owner, name = repo.name.split('/')
      starring = Github.activity.starring.starring?(user: owner, repo: name)
      if starring
        begin
          langs = Github.repos.languages user: owner, repo: name
        rescue
          next
        end
        repo_classifier.collect_train_data(normalize_repo_features(langs.body.merge(stargazers_count: Github.repos.get(user: owner, repo: name).stargazers_count)), 1)
      else
        begin
          langs = Github.repos.languages user: owner, repo: name
        rescue
          next
        end
        repo_classifier.collect_train_data(normalize_repo_features(langs.body.merge(stargazers_count: Github.repos.get(user: owner, repo: name).stargazers_count)), 0.1)
      end
    end

    Github.activity.starring.starred.body.each { |repo|
      begin
        langs = Github.repos.languages user: repo.owner.login, repo: repo.name
      rescue
        next
      end
      repo_classifier.collect_train_data(normalize_repo_features(langs.body.merge(stargazers_count: repo.stargazers_count)), 1)
    }

    # now we can train the repo_classifier
    repo_classifier.train!

    # now we can marshal the classifier and store it into the db
    self.classifier ||= Classifier.new
    self.classifier.instance = BSON::Binary.new(Marshal::dump(repo_classifier))
    self.classifier.save
    self.save
  end

  def classificator
    return false unless self.classifier
    # now we are going to randomly pick at most 1000 repositories for classifying them
    # for the specified user
    repos = (0..Repository.where(:fork => { :$ne => true }).count-1).sort_by{rand}.slice(0, 500).collect! { |i| Repository.where(:fork => { :$ne => true }).skip(i).first }.reject{ |repo|
      repo.owner['login'] == username
    }

    Github.configure do |c|
      c.user = username
      c.oauth_token = self.access_token
    end

    classifier = self.classifier.loaded_instance
    classifier.rank(repos).each do |repo|
      r = Repository.find_by(full_name: "#{repo[0]}")

      Interest.find_or_create_by(
        repository: r,
        user: self,
        rank: repo[1]
      ) if repo[1] >= 0.7
    end
  end

  private

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
end
