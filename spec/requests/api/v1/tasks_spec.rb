require "rails_helper"

RSpec.describe "Api::V1::Tasks", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe "authentication" do
    it "returns 401 when X-User-Id header is missing" do
      get "/api/v1/tasks"
      expect(response).to have_http_status(:unauthorized)
      expect(json_response["error"]).to eq("Unauthorized")
    end

    it "returns 401 when X-User-Id references a nonexistent user" do
      get "/api/v1/tasks", headers: { "X-User-Id" => "99999" }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/tasks" do
    let!(:own_tasks)   { create_list(:task, 3, user: user) }
    let!(:other_tasks) { create_list(:task, 2, user: other_user) }

    it "returns 200 with the current user's tasks only" do
      get "/api/v1/tasks", headers: auth_headers(user)
      expect(response).to have_http_status(:ok)
      ids = json_response.pluck("id")
      expect(ids).to match_array(own_tasks.map(&:id))
    end

    it "does not expose other users' tasks" do
      get "/api/v1/tasks", headers: auth_headers(user)
      ids = json_response.pluck("id")
      expect(ids).not_to include(*other_tasks.map(&:id))
    end
  end

  describe "GET /api/v1/tasks/:id" do
    let(:task) { create(:task, user: user) }

    it "returns 200 with the task" do
      get "/api/v1/tasks/#{task.id}", headers: auth_headers(user)
      expect(response).to have_http_status(:ok)
      expect(json_response["id"]).to eq(task.id)
      expect(json_response["title"]).to eq(task.title)
    end

    it "returns 404 when the task belongs to another user" do
      other_task = create(:task, user: other_user)
      get "/api/v1/tasks/#{other_task.id}", headers: auth_headers(user)
      expect(response).to have_http_status(:not_found)
      expect(json_response["error"]).to eq("Task not found")
    end

    it "returns 404 for a nonexistent task" do
      get "/api/v1/tasks/99999", headers: auth_headers(user)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/tasks" do
    let(:valid_params) do
      { task: { title: "Write specs", description: "Be thorough", due_date: "2026-05-01" } }
    end

    it "returns 201 and creates a task for the current user" do
      expect {
        post "/api/v1/tasks", params: valid_params, headers: auth_headers(user)
      }.to change { user.tasks.count }.by(1)

      expect(response).to have_http_status(:created)
      expect(json_response["title"]).to eq("Write specs")
      expect(json_response["status"]).to eq("pending")
    end

    it "allows setting status on creation" do
      post "/api/v1/tasks",
           params: { task: { title: "In flight", status: "in_progress" } },
           headers: auth_headers(user)

      expect(response).to have_http_status(:created)
      expect(json_response["status"]).to eq("in_progress")
    end

    it "returns 422 when title is missing" do
      post "/api/v1/tasks",
           params: { task: { description: "No title" } },
           headers: auth_headers(user)

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response["errors"]).to include("Title can't be blank")
    end

    it "returns 422 for an invalid status value" do
      post "/api/v1/tasks",
           params: { task: { title: "Bad status", status: "flying" } },
           headers: auth_headers(user)

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response["error"]).to be_present
    end
  end

  describe "PATCH /api/v1/tasks/:id" do
    let(:task) { create(:task, user: user, status: :pending) }

    it "returns 200 and updates the task" do
      patch "/api/v1/tasks/#{task.id}",
            params: { task: { title: "Updated title", status: "completed" } },
            headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      expect(json_response["title"]).to eq("Updated title")
      expect(json_response["status"]).to eq("completed")
    end

    it "returns 422 when clearing a required field" do
      patch "/api/v1/tasks/#{task.id}",
            params: { task: { title: "" } },
            headers: auth_headers(user)

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response["errors"]).to include("Title can't be blank")
    end

    it "returns 404 when the task belongs to another user" do
      other_task = create(:task, user: other_user)
      patch "/api/v1/tasks/#{other_task.id}",
            params: { task: { title: "Hijack" } },
            headers: auth_headers(user)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/tasks/:id" do
    let!(:task) { create(:task, user: user) }

    it "returns 204 and destroys the task" do
      expect {
        delete "/api/v1/tasks/#{task.id}", headers: auth_headers(user)
      }.to change { user.tasks.count }.by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "returns 404 when the task belongs to another user" do
      other_task = create(:task, user: other_user)
      delete "/api/v1/tasks/#{other_task.id}", headers: auth_headers(user)
      expect(response).to have_http_status(:not_found)
      expect(Task.find_by(id: other_task.id)).to be_present
    end
  end
end
