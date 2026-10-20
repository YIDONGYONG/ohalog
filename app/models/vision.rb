# ユーザーに紐づく長期ビジョン。タイトル・内容・達成予定日がすべて必須
class Vision < ApplicationRecord
  TITLE_MAX = 50
  CONTENT_MAX = 500
  MAX_YEARS_AHEAD = 100 # 達成予定日の上限（入力ミスで 9999 年などにならないように）

  belongs_to :user

  validates :title, presence: true, length: { maximum: TITLE_MAX }
  validates :content, presence: true, length: { maximum: CONTENT_MAX }
  # 日付として読めない入力（2026-02-30 や文字列）は、必須エラーではなく「正しい日付」のエラーにする
  validates :target_date, presence: true, unless: :unparsable_target_date?
  validate :target_date_must_be_valid

  scope :unachieved, -> { where(achieved_at: nil) }
  # 一覧の並び順: 未達成が先、その中で最優先 → 達成予定日が近い順。達成済みは後ろにまとめる
  scope :for_list, -> { order(Arel.sql("(achieved_at IS NOT NULL)"), top_priority: :desc, target_date: :asc, id: :asc) }

  # ホームの最初に出す目標。最優先に選んだものがあればそれ、なければ達成予定日がいちばん近い未達成の目標
  def self.featured
    unachieved.order(top_priority: :desc, target_date: :asc, id: :asc).first
  end

  def achieved? = achieved_at.present?

  def achieve!
    update!(achieved_at: Time.current, top_priority: false)
  end

  def reopen!
    update!(achieved_at: nil)
  end

  # 最優先は1人につき1件だけ。すでに最優先なら外す
  def toggle_top_priority!
    return if achieved?

    transaction do
      if top_priority?
        update!(top_priority: false)
      else
        user.visions.where.not(id: id).update_all(top_priority: false)
        update!(top_priority: true)
      end
    end
  end

  private

  def unparsable_target_date?
    target_date.nil? && target_date_before_type_cast.present?
  end

  def target_date_must_be_valid
    if unparsable_target_date?
      errors.add(:target_date, "は正しい日付で入力してください")
    elsif target_date && target_date_changed? # 保存済みの過去の日付は、他の項目の編集を妨げない
      errors.add(:target_date, "は今日以降の日付にしてください") if target_date < Date.current
      errors.add(:target_date, "は#{MAX_YEARS_AHEAD}年以内の日付にしてください") if target_date > Date.current + MAX_YEARS_AHEAD.years
    end
  end
end
