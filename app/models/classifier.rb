class Classifier
  include Mongoid::Document
  include Mongoid::Attributes::Dynamic

  belongs_to :user

  field :instance, type: BSON::Binary

  def loaded_instance
    @loaded_instance ||= Marshal::load(self.instance.data)
  end
end
