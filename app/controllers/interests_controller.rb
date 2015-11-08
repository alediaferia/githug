class InterestsController < ApplicationController
  before_action :authenticate_user!
  layout 'user'

  # GET /interests/:username/:repo.:format
  def show
    # picking 10 interests randomly
    @interests = (0..current_user.interests.count-1).sort_by{rand}.slice(0, 10).collect! { |i| current_user.interests.skip(i).first }  
  end
end
