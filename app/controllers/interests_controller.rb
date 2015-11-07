class InterestsController < ApplicationController
  before_action :authenticate_user!
  layout 'user'

  # GET /interests/:username/:repo.:format
  def show
    
  end
end
