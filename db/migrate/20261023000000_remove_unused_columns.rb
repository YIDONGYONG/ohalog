# 使われなくなった列を削除する（連続記録の方針をやめ、週ごとの判定に移したときの名残）
class RemoveUnusedColumns < ActiveRecord::Migration[8.1]
  def change
    remove_column :routines, :current_streak, :integer, default: 0, null: false
    remove_column :routines, :consecutive_misses, :integer, default: 0, null: false
    remove_column :visions, :status, :integer
  end
end
