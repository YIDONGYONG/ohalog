# ホーム画面（今日）の表示データをまとめる。
# 「積み上げた朝」は減らない累計、休んだ日は空白ではなく「休んだ日」として扱う。
class HomePresenter
  GARDEN_DAYS = 14        # 庭に表示する日数（7列 × 2週間。表示するだけで、昇格の条件とは関係ない）
  RETURN_AFTER_DAYS = 2   # この日数以上あいたら「また始める」カードを出す
  EVENING_FROM_HOUR = 18  # 「明日の私へ」を出し始める時刻
  MOODS = { "light" => "軽め", "normal" => "普通", "strong" => "元気" }.freeze
  MOOD_HINTS = {
    "light" => "軽い日は、いつもより小さな一歩でも十分です。",
    "normal" => "いつも通り、これだけやってみましょう。",
    "strong" => "力が出る日は、少しだけ先の一歩もどうぞ。"
  }.freeze

  Cell = Struct.new(:date, :state, :stage, keyword_init: true) # state: :grown / :rest / :today / :empty

  attr_reader :mood

  def initialize(user, mood: nil, now: Time.current)
    @user = user
    @now = now
    @mood = MOODS.key?(mood.to_s) ? mood.to_s : "normal"
  end

  def today = @now.to_date
  def mood_hint = MOOD_HINTS[mood]

  # ---- 時間帯 ----
  def evening? = @now.hour >= EVENING_FROM_HOUR
  def clock_text = @now.strftime("%-H:%M")

  def greeting
    case @now.hour
    when 5..10 then [ "おはようございます。", "今日は、ひとつだけやってみましょう。" ]
    when 11..17 then [ "こんにちは。", "今日の一歩は、まだ間に合います。" ]
    else [ "おつかれさまでした。", "明日の朝を、そっと準備しましょう。" ]
    end
  end

  # ---- いちばん大事な目標（ホームの最初に出す） ----
  # 最優先に選んだ目標、なければ達成予定日がいちばん近い未達成の目標
  def top_vision = @top_vision ||= @user.visions.featured
  def visions_any? = @user.visions.exists?

  # 達成予定日までの日数（過ぎていたら nil。責めない表現にするため、過ぎた分は出さない）
  def top_vision_days_left
    return unless top_vision&.target_date

    days = (top_vision.target_date - today).to_i
    days if days >= 0
  end

  # ---- 今日の一歩（ヒーロー） ----
  def routines = @routines ||= @user.routines.order(:category).to_a
  def started? = routines.any?
  def pending_routines = routines.reject(&:recorded_today?)
  def step_routine = pending_routines.first
  def all_done_today? = started? && pending_routines.empty?

  # 気分に応じて目標のレベルを上下させる（軽め=ひとつ下 / 元気=ひとつ上）
  def step_goal(routine = step_routine)
    return unless routine

    level = case mood
    when "light" then [ routine.current_level - 1, 1 ].max
    when "strong" then [ routine.current_level + 1, Routine::MAX_LEVEL ].min
    else routine.current_level
    end
    routine.goal(level)
  end

  # 完了済みなら、今日達成したルーティン名（なければ nil）
  def done_labels = routines.select { |r| r.recorded_today? && achieved_today_ids.include?(r.id) }.map(&:category_label)

  # ---- 積み上げた朝 ----
  def total_mornings = achieved_dates.size

  # 最初の記録日を1日目として14日ごとに区切り、いまの2週間の開始日を返す（記録がなければ今日）
  def garden_start
    first = log_dates.min
    return today unless first

    first + ((today - first).to_i / GARDEN_DAYS) * GARDEN_DAYS
  end

  # 1日目を左上として、左→右・上→下の時系列で並べる。過ぎた日で達成していなければ「休んだ日」、先の日は空き
  def garden
    @garden ||= begin
      start = garden_start
      ordinal = achieved_dates.sort.each_with_index.to_h
      (start...(start + GARDEN_DAYS)).map do |date|
        if achieved_dates.include?(date)
          Cell.new(date: date, state: :grown, stage: stage_for(ordinal[date]))
        elsif date == today
          Cell.new(date: date, state: :today)
        elsif date < today
          Cell.new(date: date, state: :rest)
        else
          Cell.new(date: date, state: :empty)
        end
      end
    end
  end

  # ---- また始める ----
  def last_achieved_on = achieved_dates.max

  def returning?
    last_achieved_on.present? && !achieved_dates.include?(today) && (today - last_achieved_on) >= RETURN_AFTER_DAYS
  end

  # ---- 週ごとの振り返り ----
  # 返事待ちの提案、または未確認のお知らせ（なければ nil）
  def review = @review ||= @user.weekly_reviews.pending.order(:week_start).last
  # 今週、始めた全ルーティンを最後までやれた日数
  def week_clear_days = @week_clear_days ||= @user.clear_days(today.beginning_of_week..today)
  def promote_days = WeeklyReview::PROMOTE_CLEAR_DAYS
  def promote_weeks = WeeklyReview::PROMOTE_STREAK_WEEKS

  # 先週が「クリアした週」で、いま2週連続のチャレンジ中か（昇格した直後の週は含まない）
  def last_week_cleared?
    return @last_week_cleared if defined?(@last_week_cleared)

    prior = @user.weekly_reviews.find_by(week_start: today.beginning_of_week - 7)
    @last_week_cleared = prior.present? && prior.stayed? && prior.clear_days >= promote_days && prior.level_before == @user.level
  end

  # ---- 希望の根拠 ----
  def this_week = count_between(today - 6, today)
  def last_week = count_between(today - 13, today - 7)
  def week_up? = this_week > last_week

  def hope_title
    if week_up? then "先週より、朝を#{this_week - last_week}回多く迎えました。"
    elsif total_mornings.positive? then "これまでに、朝を#{total_mornings}回迎えました。"
    else "ここが最初の一歩です。"
    end
  end

  def hope_body
    if total_mornings.zero?
      "うまくいかなかった日の記録は、ここにはありません。今日の5分から始めましょう。"
    elsif returning?
      "休んだ日があっても、積み上げた#{total_mornings}回の朝は消えません。"
    else
      "小さな一歩が積み重なっている証拠です。今日の一歩も、その上にそっと重ねましょう。"
    end
  end

  # ---- 明日の私へ（夕方以降） ----
  def tomorrow_card? = evening? && started?
  def tomorrow_routine = routines.first
  def tomorrow_goal = tomorrow_routine&.goal

  private

  def logs = @logs ||= @user.routine_logs.pluck(:recorded_on, :achieved)
  def log_dates = logs.map(&:first)
  def achieved_dates = @achieved_dates ||= logs.select(&:last).map(&:first).to_set
  def achieved_today_ids = @achieved_today_ids ||= @user.routine_logs.where(recorded_on: today, achieved: true).pluck(:routine_id).to_set
  def count_between(from, to) = achieved_dates.count { |d| d.between?(from, to) }

  # 積み上げるほど芽が育つ（減ることはない）
  def stage_for(index)
    case index
    when 0..6 then 1
    when 7..13 then 2
    else 3
    end
  end
end
