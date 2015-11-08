class Language
  include Mongoid::Document
  include Mongoid::Attributes::Dynamic

  belongs_to :repository
end
