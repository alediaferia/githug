class Interest
  include Mongoid::Document
  include Mongoid::Attributes::Dynamic

  has_many :users
  has_many :repositories

  field :rank, type: Float
end
