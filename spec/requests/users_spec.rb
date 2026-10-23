require 'rails_helper'

RSpec.describe "Users", type: :request do
  let(:valid_params) do
    { user: { last_name: "山田", first_name: "太郎", email: "new@example.com",
              password: "password1", password_confirmation: "password1" } }
  end

  it "registers and logs in" do
    expect { post users_path, params: valid_params }.to change(User, :count).by(1)
    expect(response).to redirect_to(root_path)
    follow_redirect!
    expect(response.body).to include("山田 太郎")
  end

  it "resets the session on sign-up (session fixation)" do
    expect_any_instance_of(UsersController).to receive(:reset_session).and_call_original
    post users_path, params: valid_params
  end

  it "shows readable Japanese errors for empty input (regression: Translation missing)" do
    expect { post users_path, params: { user: { email: "", password: "" } } }.not_to change(User, :count)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).not_to include("Translation missing")
    expect(response.body).to include("を入力してください")
  end

  it "rejects a 7-character password" do
    valid_params[:user].merge!(password: "1234567", password_confirmation: "1234567")
    expect { post users_path, params: valid_params }.not_to change(User, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "rejects a mismatched password confirmation" do
    valid_params[:user][:password_confirmation] = "different1"
    expect { post users_path, params: valid_params }.not_to change(User, :count)
  end

  it "returns 400 when the user param is missing" do
    post users_path, params: { x: 1 }
    expect(response).to have_http_status(:bad_request)
  end
end
