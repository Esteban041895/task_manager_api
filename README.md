# Task Manager API

## AI Collaboration

See [explanation.md](EXPLANATION.md) for a detailed account of how I worked with AI to build this project, covering:

- How I validated the AI's suggestions
- How I corrected or improved the output, if necessary
- How I handled edge cases, authentication, and validations
- How I assessed the performance and idiomatic quality of the code

---

A RESTful JSON API built with Ruby on Rails 7 (API-only mode) for managing tasks. Tasks are scoped to individual users via a request-header stub — ready to swap in real authentication without changing the rest of the application.

---

## Stack

| Component | Version |
|-----------|---------|
| Ruby | 3.4.7 |
| Rails | 7.2 (API-only) |
| Database | SQLite3 (development/test) |
| Testing | RSpec 6, FactoryBot, Faker |

---

## Getting started

```bash
git clone <repo-url>
cd task_manager_api

bundle install
rails db:create db:migrate
rails server
```

The API is available at `http://localhost:3000`.

---

## Project structure

```
task_manager_api/
├── app/
│   ├── controllers/
│   │   ├── application_controller.rb
│   │   └── api/
│   │       └── v1/
│   │           └── tasks_controller.rb
│   └── models/
│       ├── user.rb
│       └── task.rb
├── config/
│   └── routes.rb
├── db/
│   ├── migrate/
│   │   ├── ..._create_users.rb
│   │   └── ..._create_tasks.rb
│   └── schema.rb
└── spec/
    ├── factories/
    │   ├── users.rb
    │   └── tasks.rb
    ├── models/
    │   ├── user_spec.rb
    │   └── task_spec.rb
    ├── requests/
    │   └── api/v1/tasks_spec.rb
    ├── support/
    │   └── request_helpers.rb
    └── rails_helper.rb
```

---

## API reference

All endpoints are prefixed with `/api/v1`. Authentication is provided by passing the user's ID in the `X-User-Id` request header.

### Authentication header

```
X-User-Id: <user_id>
```

Missing or unresolvable values return `401 Unauthorized`.

### Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/v1/tasks` | List all tasks for the current user |
| `GET` | `/api/v1/tasks/:id` | Fetch a single task |
| `POST` | `/api/v1/tasks` | Create a task |
| `PATCH` | `/api/v1/tasks/:id` | Update a task |
| `DELETE` | `/api/v1/tasks/:id` | Delete a task |

### Task fields

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `title` | string | yes | |
| `description` | text | no | |
| `status` | enum | no | `pending` (default), `in_progress`, `completed` |
| `due_date` | date | no | ISO 8601 format: `YYYY-MM-DD` |

### Example requests

**Create a task**
```bash
curl -X POST http://localhost:3000/api/v1/tasks \
  -H "Content-Type: application/json" \
  -H "X-User-Id: 1" \
  -d '{"task": {"title": "Write documentation", "due_date": "2026-05-01"}}'
```

**Response `201 Created`**
```json
{
  "id": 1,
  "user_id": 1,
  "title": "Write documentation",
  "description": null,
  "status": "pending",
  "due_date": "2026-05-01",
  "created_at": "2026-04-09T20:00:00.000Z",
  "updated_at": "2026-04-09T20:00:00.000Z"
}
```

**Update status**
```bash
curl -X PATCH http://localhost:3000/api/v1/tasks/1 \
  -H "Content-Type: application/json" \
  -H "X-User-Id: 1" \
  -d '{"task": {"status": "completed"}}'
```

### HTTP status codes

| Code | Meaning |
|------|---------|
| `200` | Success (index, show, update) |
| `201` | Task created |
| `204` | Task deleted (no body) |
| `401` | Missing or invalid `X-User-Id` header |
| `404` | Task not found or belongs to another user |
| `422` | Validation failed |

### Error response shape

Single error:
```json
{ "error": "Task not found" }
```

Validation errors:
```json
{ "errors": ["Title can't be blank"] }
```

---

## Key design decisions

### Auth stub via request header

`ApplicationController` reads `X-User-Id` from the request header and sets `@current_user`. A missing or unresolvable ID halts the request with `401`.

### Task scoping through the association

All task lookups are performed through `current_user.tasks` rather than `Task.find`. A user requesting another user's task ID receives `404`.

```ruby
def set_task
  @task = current_user.tasks.find(params[:id])
rescue ActiveRecord::RecordNotFound
  render json: { error: "Task not found" }, status: :not_found
end
```

### Status as a validated enum

`status` is stored as an integer with a DB-level `NOT NULL DEFAULT 0` constraint. The Rails enum uses `validate: true` so that an unrecognised string value produces a standard `422` validation error rather than an `ArgumentError` exception.

```ruby
enum :status, { pending: 0, in_progress: 1, completed: 2 }
```

### Thin controllers, fat models

Controllers contain no business logic. Validations, scopes, and associations live in the models. The controller's only responsibilities are: parse permitted params, delegate to the model, and render the appropriate response.

### Consistent error envelope

All error responses use one of two shapes so clients need no special-case handling:

- Single string → `{ "error": "..." }` (auth, not found)
- Validation array → `{ "errors": [...] }` (model validation failures)

### No user endpoints

`User` is a minimal supporting model with only `id` and `name`. It has no controller or routes. The only way to create users is via `rails console` or seeds.

---

## Running tests

```bash
bundle exec rspec
```

The suite runs **26 examples** covering:

- Model validations and associations (`Task`)
- All CRUD request specs with success and error cases
- Authentication enforcement (missing header, invalid user ID)
- Cross-user access isolation (404 on another user's task)
- Enum validation (invalid status value returns 422)

---

## Database schema

```
users
  id         integer  primary key
  name       string   not null
  created_at datetime
  updated_at datetime

tasks
  id          integer  primary key
  user_id     integer  not null, foreign key → users.id
  title       string   not null
  description text
  status      integer  not null, default 0
  due_date    date
  created_at  datetime
  updated_at  datetime
```
