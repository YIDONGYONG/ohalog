class UserSessionsController < ApplicationController
  skip_before_action :require_login, only: %i[new create]
  # 総当たりでパスワードを試されないよう、ログイン試行を制限する
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> {
    flash.now[:alert] = t("user_sessions.create.throttled")
    render :new, status: :too_many_requests
  }

  # ログイン画面
  def new; end

  # ログイン処理（メールアドレスとパスワードで認証）
  def create
    user = User.find_by(email: params[:email])

    if user&.authenticate(params[:password])
      reset_session # ログイン前のセッションを引き継がない（セッション固定攻撃への対策）
      session[:user_id] = user.id
      redirect_to root_path, notice: t(".success")
    else
      flash.now[:alert] = t(".failure")
      render :new, status: :unprocessable_entity
    end
  end

  # ログアウト処理
  def destroy
    logout
    redirect_to root_path, notice: t(".success"), status: :see_other
  end
end
