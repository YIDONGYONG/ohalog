require 'rails_helper'

RSpec.describe "Visions", type: :request do
  let!(:user) { User.create!(email: "vv@example.com", password: "password1", first_name: "a", last_name: "b") }
  let!(:vision) { user.visions.create!(title: "My vision", content: "text", target_date: 1.year.from_now.to_date) }

  before { post login_path, params: { email: user.email, password: "password1" } }

  it "shows the cover image on index" do
    get visions_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("cover").and include("私のビジョン画像")
  end

  it "still supports deleting" do
    expect { delete vision_path(vision) }.to change(Vision, :count).by(-1)
  end

  describe "ownership (regression: other users' visions were readable and editable)" do
    let!(:other) { User.create!(email: "other@example.com", password: "password1", first_name: "c", last_name: "d") }
    let!(:others_vision) { other.visions.create!(title: "Others secret", content: "private", target_date: 1.year.from_now.to_date) }

    it "lists only my own visions" do
      get visions_path
      expect(response.body).to include("My vision")
      expect(response.body).not_to include("Others secret")
    end

    it "returns 404 for another user's vision on edit" do
      get edit_vision_path(others_vision)
      expect(response).to have_http_status(:not_found)
    end

    it "cannot update another user's vision" do
      patch vision_path(others_vision), params: { vision: { title: "hacked" } }
      expect(response).to have_http_status(:not_found)
      expect(others_vision.reload.title).to eq "Others secret"
    end

    it "cannot delete another user's vision" do
      expect { delete vision_path(others_vision) }.not_to change(Vision, :count)
      expect(response).to have_http_status(:not_found)
    end
  end

  it "creates a vision owned by the current user" do
    expect { post visions_path, params: { vision: { title: "New", content: "x", target_date: 1.year.from_now.to_date.to_s } } }.to change { user.visions.count }.by(1)
    expect(response).to redirect_to(visions_path)
  end

  it "shows a readable error when the title is empty" do
    expect { post visions_path, params: { vision: { title: "" } } }.not_to change(Vision, :count)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("タイトル を入力してください")
    expect(response.body).not_to include("Translation missing")
  end

  it "updates my own vision" do
    patch vision_path(vision), params: { vision: { title: "Renamed" } }
    expect(vision.reload.title).to eq "Renamed"
  end

  it "shows readable errors for a missing content and a past target date" do
    post visions_path, params: { vision: { title: "t", content: "", target_date: (Date.current - 1).to_s } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("詳細 を入力してください").and include("達成予定日 は今日以降の日付にしてください")
  end

  it "shows the target date on the vision card" do
    get visions_path
    expect(response.body).to include("達成予定日：#{vision.target_date.strftime('%Y年%-m月%-d日')}")
  end

  # スマホ対応: 日付が未選択でも案内が見え、入力欄は iPhone が自動拡大しない 16px、空送信は日本語のサーバーメッセージ
  describe "form on mobile" do
    it "shows the Japanese hint for the empty target date, which the browser would otherwise render blank" do
      get new_vision_path
      expect(response.body).to include("達成日を決めてください")
      expect(response.body).to include("field-date-hint")
    end

    it "lets the server show the validation messages instead of the browser's own bubble" do
      get new_vision_path
      expect(response.body).to match(/<form[^>]*novalidate/)
    end

    it "does not hide an already saved (possibly past) target date behind a min attribute" do
      vision.update_columns(target_date: Date.current - 5)
      get edit_vision_path(vision)
      expect(response.body).to include(%(value="#{(Date.current - 5).iso8601}"))
      expect(response.body).not_to match(/type="date"[^>]*min=/)
    end
  end

  describe "achievement and priority" do
    it "marks a vision as achieved with a Turbo Stream that celebrates it" do
      patch achieve_vision_path(vision), as: :turbo_stream
      expect(response).to have_http_status(:ok)
      expect(vision.reload).to be_achieved
      expect(response.body).to include("vision-done-fresh").and include("visions_progress")
    end

    it "falls back to a redirect without Turbo" do
      patch achieve_vision_path(vision)
      expect(response).to redirect_to(visions_path)
    end

    it "can undo an achievement" do
      vision.achieve!
      patch reopen_vision_path(vision), as: :turbo_stream
      expect(vision.reload).not_to be_achieved
      expect(response.body).not_to include("vision-done-fresh")
    end

    it "sets and clears the top priority" do
      patch prioritize_vision_path(vision)
      expect(vision.reload.top_priority).to be true
      get visions_path
      expect(response.body).to include("最優先")
      patch prioritize_vision_path(vision)
      expect(vision.reload.top_priority).to be false
    end

    it "cannot achieve or prioritize another user's vision" do
      other = User.create!(email: "o2@example.com", password: "password1", first_name: "c", last_name: "d")
      theirs = other.visions.create!(title: "Theirs", content: "p", target_date: 1.year.from_now.to_date)
      patch achieve_vision_path(theirs)
      expect(response).to have_http_status(:not_found)
      patch prioritize_vision_path(theirs)
      expect(response).to have_http_status(:not_found)
      expect(theirs.reload).not_to be_achieved
    end

    it "shows the top priority vision first on the home page" do
      other_vision = user.visions.create!(title: "Priority goal", content: "x", target_date: 2.years.from_now.to_date)
      other_vision.toggle_top_priority!
      get root_path
      expect(response.body).to include("Priority goal")
      expect(response.body.index("top_vision")).to be < response.body.index("はじめの一歩")
    end
  end
end
