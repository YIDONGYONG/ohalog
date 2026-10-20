class VisionsController < ApplicationController
  before_action :set_vision, only: [ :edit, :update, :destroy, :achieve, :reopen, :prioritize ]

  # 1. 一覧表示
  def index
    @visions = current_user.visions.for_list
  end

  # 3. 新規作成フォーム
  def new
    @vision = Vision.new
  end

  # 3. 新規作成（DB保存）
  def create
    @vision = current_user.visions.build(vision_params)

    if @vision.save
      redirect_to visions_path, notice: "ビジョンを登録しました"
    else
      render :new, status: :unprocessable_entity
    end
  end

  # 4. 編集フォーム
  def edit; end

  # 4. 更新（DB保存）
  def update
    if @vision.update(vision_params)
      redirect_to visions_path, notice: "ビジョンを更新しました"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # 5. 削除
  def destroy
    @vision.destroy
    redirect_to visions_path, status: :see_other, notice: "ビジョンを削除しました"
  end

  # 6. 達成のチェック（Turbo Stream でそのカードだけ差し替えて、お祝いの動きを見せる）
  def achieve
    @vision.achieve!
    @just_achieved = true
    respond_to_status_change("目標を達成しました。おめでとうございます")
  end

  # 7. 達成の取り消し（間違えてチェックしても、いつでも戻せる）
  def reopen
    @vision.reopen!
    respond_to_status_change("目標をもとに戻しました")
  end

  # 8. 最優先の切り替え（並び順が変わるので一覧ごと読み直す）
  def prioritize
    @vision.toggle_top_priority!
    notice = @vision.top_priority? ? "最優先の目標に設定しました" : "最優先を外しました"
    redirect_to visions_path, status: :see_other, notice: notice
  end

  private

  def respond_to_status_change(notice)
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to visions_path, status: :see_other, notice: notice }
    end
  end

  # 対象のビジョンを取得する共通処理（自分のビジョンだけ。他人のIDは404）
  def set_vision
    @vision = current_user.visions.find(params[:id])
  end

  def vision_params
    params.require(:vision).permit(:title, :content, :target_date)
  end
end
