class Interest
  include Mongoid::Document

  belongs_to :user
  has_one :repository

  field :rank, type: Float
end
