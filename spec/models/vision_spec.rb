require 'rails_helper'

RSpec.describe Vision, type: :model do
  let(:user) { User.create!(email: "vm@example.com", password: "password1", first_name: "a", last_name: "b") }

  def build_vision(**attrs)
    user.visions.build({ title: "朝を大切にする", content: "毎朝5分、自分のために使う", target_date: Date.current + 30 }.merge(attrs))
  end

  it "is valid with a title, content and target date" do
    expect(build_vision).to be_valid
  end

  describe "title (長期ビジョン)" do
    it "is required, with a readable Japanese message" do
      vision = build_vision(title: "")
      expect(vision).not_to be_valid
      expect(vision.errors.full_messages).to eq [ "タイトル を入力してください" ]
    end

    it "accepts exactly 50 characters (boundary)" do
      expect(build_vision(title: "あ" * 50)).to be_valid
    end

    it "rejects 51 characters" do
      vision = build_vision(title: "あ" * 51)
      expect(vision).not_to be_valid
      expect(vision.errors.full_messages).to eq [ "タイトル は50文字以内で入力してください" ]
    end
  end

  describe "content (目標内容)" do
    it "is required" do
      expect(build_vision(content: "")).not_to be_valid
    end

    it "accepts exactly 500 characters (boundary)" do
      expect(build_vision(content: "あ" * 500)).to be_valid
    end

    it "rejects 501 characters" do
      expect(build_vision(content: "あ" * 501)).not_to be_valid
    end
  end

  describe "target_date (達成予定日)" do
    it "is required" do
      vision = build_vision(target_date: nil)
      expect(vision).not_to be_valid
      expect(vision.errors.full_messages).to eq [ "達成予定日 を入力してください" ]
    end

    it "accepts today (boundary)" do
      expect(build_vision(target_date: Date.current)).to be_valid
    end

    it "rejects yesterday" do
      vision = build_vision(target_date: Date.current - 1)
      expect(vision).not_to be_valid
      expect(vision.errors.full_messages).to eq [ "達成予定日 は今日以降の日付にしてください" ]
    end

    it "rejects an impossible calendar date such as 2026-02-30" do
      vision = build_vision(target_date: "2026-02-30")
      expect(vision).not_to be_valid
      expect(vision.errors.full_messages).to eq [ "達成予定日 は正しい日付で入力してください" ]
    end

    it "rejects text that is not a date" do
      expect(build_vision(target_date: "あした")).not_to be_valid
    end

    it "accepts exactly 100 years ahead and rejects a day beyond (boundary)" do
      limit = Date.current + Vision::MAX_YEARS_AHEAD.years
      expect(build_vision(target_date: limit)).to be_valid
      expect(build_vision(target_date: limit + 1)).not_to be_valid
    end

    it "does not block editing other fields of a vision whose saved date has already passed" do
      vision = build_vision
      vision.save!
      vision.update_columns(target_date: Date.current - 10)
      vision.reload
      expect(vision.update(title: "言い換えた")).to be true
    end

    it "still rejects changing the date of an existing vision to the past" do
      vision = build_vision
      vision.save!
      expect(vision.update(target_date: Date.current - 1)).to be false
    end
  end

  describe "association with User" do
    it "belongs to a user and is listed in user.visions" do
      vision = build_vision
      vision.save!
      expect(vision.user).to eq user
      expect(user.visions).to include(vision)
    end

    it "is invalid without a user" do
      expect(Vision.new(title: "t", content: "c", target_date: Date.current)).not_to be_valid
    end

    it "is deleted together with its user, without touching other users' visions" do
      other = User.create!(email: "vo@example.com", password: "password1", first_name: "c", last_name: "d")
      mine = build_vision.tap(&:save!)
      theirs = other.visions.create!(title: "t", content: "c", target_date: Date.current + 1)

      expect { user.destroy }.to change(Vision, :count).by(-1)
      expect(Vision.exists?(mine.id)).to be false
      expect(Vision.exists?(theirs.id)).to be true
    end
  end

  describe "achievement and priority" do
    def make(title, days, **attrs) = user.visions.create!(title: title, content: "c", target_date: Date.current + days, **attrs)

    it "can be achieved and reopened" do
      v = make("a", 5)
      v.achieve!
      expect(v.reload).to be_achieved
      v.reopen!
      expect(v.reload).not_to be_achieved
    end

    it "can be achieved even if a legacy record has no target date" do
      v = make("legacy", 5)
      v.update_columns(target_date: nil)
      v.achieve!
      expect(v.reload).to be_achieved
      v.reopen!
      expect(v.reload).not_to be_achieved
    end

    it "keeps only one top priority per user" do
      a = make("a", 5)
      b = make("b", 9)
      a.toggle_top_priority!
      b.toggle_top_priority!
      expect(a.reload.top_priority).to be false
      expect(b.reload.top_priority).to be true
      b.toggle_top_priority!
      expect(b.reload.top_priority).to be false
    end

    it "features the top priority one, otherwise the nearest unachieved one" do
      far = make("far", 30)
      near = make("near", 3)
      expect(user.visions.featured).to eq near
      far.toggle_top_priority!
      expect(user.visions.featured).to eq far
      far.achieve!
      expect(user.visions.featured).to eq near
      near.achieve!
      expect(user.visions.featured).to be_nil
    end

    it "lists unachieved first and achieved last" do
      done = make("done", 1).tap(&:achieve!)
      later = make("later", 20)
      soon = make("soon", 2)
      expect(user.visions.for_list.to_a).to eq [ soon, later, done ]
    end
  end
end
