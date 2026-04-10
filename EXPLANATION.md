# Explanation

## How I validated the AI's suggestions

I reviewed each piece of generated code before accepting it rather than treating the output as final. For the models, I checked that the associations, validations, and enum definition made sense. 
For the controller, I read through the action logic to confirm tasks were always fetched through the user association and never directly from `Task`.
For the migrations, I verified the column types, constraints, and defaults before running them. I also let the RSpec suite act as a continuous validation layer — if the tests passed cleanly, the implementation was behaving as intended.

## How I corrected or improved the output

Several corrections came up during the session:

- **Removed the email field from User.** The AI included `email` with a uniqueness validation and a database index. I pointed out that the spec said to assume a user exists and only needed an ID to work — email was unnecessary overhead. The AI removed the column, index, and related validation.

- **Removed `validate: true` from the enum.** The AI added this option so that an unknown status value would produce a standard validation error. I pushed back because the enum already guards against invalid values by raising `ArgumentError` — adding `validate: true` was redundant. The AI agreed, reverted it, and instead added a `rescue_from ArgumentError` in the controller to handle the case gracefully at the API boundary.


- **`params.expect` was caught by the tests.** The AI initially used the Rails 8 `params.expect` API, which does not exist in Rails 7. This surfaced immediately as a `NoMethodError` when the suite ran, and was corrected to `params.require(:task).permit(...)`.

## How I handled edge cases, authentication, and validations

**Authentication** was stubbed via a `before_action :set_current_user` in `ApplicationController` that reads the `X-User-Id` request header and resolves it to a `User` record. A missing or unresolvable header halts the request with `401 Unauthorized`. This keeps the auth concern in a single method that can be replaced with real JWT or session logic without touching anything else.

**Task scoping** is enforced by always going through `current_user.tasks` for every lookup. A request for a task that belongs to another user returns `404` rather than `403` — the resource simply does not exist from the current user's perspective.

**Validations** live in the model: `title` is required, `status` has a DB-level `NOT NULL DEFAULT 0` constraint backed by the enum, and `belongs_to :user` enforces the foreign key. The controller only handles what the model cannot — converting `ArgumentError` from an invalid enum value into a `422` response via `rescue_from`.

**Consistent error responses** use two shapes: `{ "error": "..." }` for single errors (auth, not found, invalid enum) and `{ "errors": [...] }` for model validation failures, so clients always know what key to read.

## How I assessed the performance and idiomatic quality of the code

The code follows standard Rails conventions throughout. Controllers are thin — each action delegates immediately to the model or association and renders the result. No business logic leaks into the controller layer. Scoping through the association (`current_user.tasks`) rather than a manual `where` clause is the idiomatic Rails approach and keeps authorization implicit in every query.

The enum is stored as an integer, which is the correct choice for a fixed set of states — it keeps the column compact and lets ActiveRecord handle the string-to-integer mapping. The DB default ensures the column is never null even if Rails is bypassed.

The test suite covers : model validations, association behaviour, all five CRUD endpoints, authentication enforcement, and cross-user isolation.
