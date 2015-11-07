class Identity
	include Mongoid::Document

  validates_presence_of :uid, :provider
  validates_uniqueness_of :uid, :scope => :provider

  field :uid, type: String
  field :provider, type: String

  belongs_to :user

  def self.find_for_oauth(auth)
    find_or_create_by(uid: auth.uid, provider: auth.provider)
  end
end
