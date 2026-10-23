class UsersController < ApplicationController
  skip_before_action :require_login, only: %i[new create]

  # ユーザー登録画面
  def new
    @user = User.new
  end

  # ユーザー登録処理（成功したらそのままログイン）
  def create
    @user = User.new(user_params)
    if @user.save
      reset_session # 登録前のセッションを引き継がない（セッション固定攻撃への対策）
      session[:user_id] = @user.id
      redirect_to root_path, notice: t(".success")
    else
      flash.now[:alert] = t(".failure")
      render :new, status: :unprocessable_entity
    end
  end

  private

  # 許可するパラメータ
  def user_params
    params.require(:user).permit(:first_name, :last_name, :email, :password, :password_confirmation)
  end
end
