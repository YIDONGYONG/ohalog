# Harness ルール
- スタック: Ruby 3.4 / Rails 8.1 (Hotwire) / PostgreSQL / RSpec。コマンドは Docker 経由 (`docker compose exec -T web ...`)。
- 変更後は必ず `bundle exec rspec` を通す。
- push / 破壊的コマンド (rm -rf, reset --hard, DROP TABLE) は禁止。
- 読むべきファイルは step ファイルの「読むファイル」に書かれたものだけ読む。
