class Interest
  include Mongoid::Document

  belongs_to :user
  belongs_to :repository

  field :rank, type: Float
end
