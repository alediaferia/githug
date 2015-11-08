class InterestsController < ApplicationController
  before_action :authenticate_user!
  layout 'user'

  # GET /interests/:username/:repo.:format
  def show
    # picking 10 interests randomly
    
  end
end
