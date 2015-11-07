class Interest
  include Mongoid::Document

  has_many :users
  has_many :repositories

  field :rank, type: Float
end
