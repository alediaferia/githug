class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user
  before_filter :ensure_signup_complete, only: [:new, :create, :update, :destroy]

  layout 'user'
  # GET /:username.:format
  def show
    interests = (0..current_user.interests.count-1).sort_by{rand}.slice(0, 10).collect! { |i| current_user.interests.skip(i).first }
    @repos = interests.map(&:repository)

    puts "REPOS #{@repos}"
  end

  # PATCH/PUT /:username.:format
  def update
    respond_to do |format|
      if @user.update(user_params)
        sign_in(@user == current_user ? @user : current_user, :bypass => true)
        format.html { redirect_to @user, notice: 'Your profile was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  # GET/PATCH /:username/complete
  def complete
    if request.patch? && params[:user]
      if @user.update(user_params)
        sign_in(@user, bypass: true)
        redirect_to @user, notice: 'Your profile was successfully activated.'
      else
        flash[:error] = "Unable to complete signup due: #{@user.errors.full_messages.to_sentence}"
      end
    end
  end

  # DELETE /:username.:format
  def destroy
    reset_session
    respond_to do |format|
      format.html { redirect_to root_url , notice: 'Your account was successfully deleted.'}
      format.json { head :no_content }
    end
  end

  private

  def set_user
    @user = current_user
  end

  def user_params
    accessible = [:name, :email, :username, :name]
    accessible << [:password, :password_confirmation] unless params[:user][:password].blank?
    params.require(:user).permit(accessible)
  end
end
