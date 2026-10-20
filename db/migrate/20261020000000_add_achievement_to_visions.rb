# ビジョンに「達成した日時」と「最優先の目標」の印を追加する
class AddAchievementToVisions < ActiveRecord::Migration[7.2]
  def change
    add_column :visions, :achieved_at, :datetime
    add_column :visions, :top_priority, :boolean, default: false, null: false
  end
end
