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

  ## Database authenticatable
  field :email,              type: String, default: ""
  field :encrypted_password, type: String, default: ""
  field :name,               type: String
  field :username,           type: String, default: ""
  slug :username
  field :password,           type: String, default: ""
  field :access_token,       type: String, default: ""

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
end
