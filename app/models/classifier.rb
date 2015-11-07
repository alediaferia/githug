class Classifier
  include Mongoid::Document
  include Mongoid::Attributes::Dynamic

  belongs_to :user

  field :instance, type: BSON::Binary
end
