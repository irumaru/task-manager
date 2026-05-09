import "@typespec/http";
import "@typespec/rest";
import "@typespec/openapi3";

using Http;

@service(#{
  title: "Task Manager API",
})
@server("http://localhost:8080", "Local development server")
namespace TaskManagerApi;

// ---------------------------------------------------------------------------
// Auth scheme
// ---------------------------------------------------------------------------

@doc("JWT Bearer token")
model BearerAuth is Http.BearerAuth;

// ---------------------------------------------------------------------------
// Common models
// ---------------------------------------------------------------------------

@error
model ApiError {
  code: int32;
  message: string;
}

// ---------------------------------------------------------------------------
// Health
// ---------------------------------------------------------------------------

model PingResponse {
  message: string;
}

@route("/ping")
@tag("Health")
interface HealthOps {
  @get
  @doc("Healthcheck endpoint")
  ping(): PingResponse | ApiError;
}

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

model GoogleAuthRequest {
  @doc("Google ID token obtained from Google Sign-In")
  idToken: string;
}

model GoogleAuthCodeRequest {
  @doc("Authorization code from OAuth2 redirect")
  code: string;

  @doc("Redirect URI used in the OAuth2 flow (must match)")
  redirectUri: string;
}

model AuthResponse {
  @doc("JWT access token issued by this server")
  accessToken: string;

  @doc("Authenticated user info")
  user: UserProfile;
}

model UserProfile {
  id: string;
  email: string;
  displayName: string;
  avatarUrl: string | null;
}

@route("/auth")
@tag("Auth")
interface AuthOps {
  @post
  @route("/google")
  @doc("Exchange Google ID token for a server-issued JWT")
  googleLogin(@body body: GoogleAuthRequest): AuthResponse | ApiError;

  @post
  @route("/google/code")
  @doc("Exchange Google authorization code for a server-issued JWT")
  googleLoginWithCode(@body body: GoogleAuthCodeRequest): AuthResponse | ApiError;

  @get
  @route("/me")
  @useAuth(BearerAuth)
  @doc("Get the currently authenticated user")
  getMe(): UserProfile | ApiError;
}

// ---------------------------------------------------------------------------
// Tasks
// ---------------------------------------------------------------------------

model Task {
  id: string;
  title: string;
  memo: string | null;
  dueDate: utcDateTime | null;
  statusId: string;

  @minValue(1)
  @maxValue(3)
  importance: int32;

  @minValue(1)
  @maxValue(3)
  urgency: int32;

  tagIds: string[];
  createdAt: utcDateTime;
  updatedAt: utcDateTime;
}

model CreateTaskRequest {
  title: string;
  memo?: string;
  dueDate?: utcDateTime;
  statusId: string;

  @minValue(1)
  @maxValue(3)
  importance?: int32;

  @minValue(1)
  @maxValue(3)
  urgency?: int32;

  tagIds?: string[];
}

// PUT semantics: full replacement. All fields required.
model UpdateTaskRequest {
  title: string;
  memo: string | null;
  dueDate: utcDateTime | null;
  statusId: string;

  @minValue(1)
  @maxValue(3)
  importance: int32;

  @minValue(1)
  @maxValue(3)
  urgency: int32;

  tagIds: string[];
}

model TaskList {
  items: Task[];
}

@route("/tasks")
@tag("Tasks")
@useAuth(BearerAuth)
interface TaskOps {
  @get
  @doc("List all tasks for the authenticated user")
  list(): TaskList | ApiError;

  @post
  @doc("Create a new task")
  create(@body body: CreateTaskRequest): Task | ApiError;

  @get
  @route("{id}")
  @doc("Get a task by ID")
  get(@path id: string): Task | ApiError;

  @put
  @route("{id}")
  @doc("Update a task")
  update(@path id: string, @body body: UpdateTaskRequest): Task | ApiError;

  @delete
  @route("{id}")
  @doc("Delete a task")
  delete(@path id: string): void | ApiError;
}

// ---------------------------------------------------------------------------
// Statuses
// ---------------------------------------------------------------------------

model Status {
  id: string;
  name: string;
  displayOrder: int32;
}

model StatusList {
  items: Status[];
}

model CreateStatusRequest {
  name: string;
  displayOrder: int32;
}

// PUT semantics: full replacement. All fields required.
model UpdateStatusRequest {
  name: string;
  displayOrder: int32;
}

@route("/statuses")
@tag("Statuses")
@useAuth(BearerAuth)
interface StatusOps {
  @get list(): StatusList | ApiError;
  @post create(@body body: CreateStatusRequest): Status | ApiError;

  @put
  @route("{id}")
  update(@path id: string, @body body: UpdateStatusRequest): Status | ApiError;

  @delete
  @route("{id}")
  delete(@path id: string): void | ApiError;
}

// ---------------------------------------------------------------------------
// Tags
// ---------------------------------------------------------------------------

model Tag {
  id: string;
  name: string;
}

model TagList {
  items: Tag[];
}

model CreateTagRequest {
  name: string;
}

// PUT semantics: full replacement. All fields required.
model UpdateTagRequest {
  name: string;
}

@route("/tags")
@tag("Tags")
@useAuth(BearerAuth)
interface TagOps {
  @get list(): TagList | ApiError;
  @post create(@body body: CreateTagRequest): Tag | ApiError;

  @put
  @route("{id}")
  update(@path id: string, @body body: UpdateTagRequest): Tag | ApiError;

  @delete
  @route("{id}")
  delete(@path id: string): void | ApiError;
}

// ---------------------------------------------------------------------------
// Wishes (やりたいこと)
// ---------------------------------------------------------------------------

model Wish {
  id: string;
  title: string;
  detail: string | null;
  labelIds: string[];
  archivedAt: utcDateTime | null;
  createdAt: utcDateTime;
  updatedAt: utcDateTime;
}

model WishList { items: Wish[]; }

model CreateWishRequest {
  title: string;
  detail?: string;
  labelIds?: string[];
}

// PUT semantics: full replacement. All fields required.
model UpdateWishRequest {
  title: string;
  detail: string | null;
  labelIds: string[];
}

@route("/wishes")
@tag("Wishes")
@useAuth(BearerAuth)
interface WishOps {
  @get list(@query includeArchived?: boolean): WishList | ApiError;
  @post create(@body body: CreateWishRequest): Wish | ApiError;
  @get  @route("{id}") get(@path id: string): Wish | ApiError;
  @put  @route("{id}") update(@path id: string, @body body: UpdateWishRequest): Wish | ApiError;
  @delete @route("{id}") delete(@path id: string): void | ApiError;

  @post @route("{id}/archive")   archive(@path id: string):   Wish | ApiError;
  @post @route("{id}/unarchive") unarchive(@path id: string): Wish | ApiError;
}

// ---------------------------------------------------------------------------
// Wish Labels
// ---------------------------------------------------------------------------

model WishLabel {
  id: string;
  name: string;
}

model WishLabelList { items: WishLabel[]; }

model CreateWishLabelRequest { name: string; }

// PUT semantics: full replacement. `name` required.
model UpdateWishLabelRequest { name: string; }

@route("/wish-labels")
@tag("WishLabels")
@useAuth(BearerAuth)
interface WishLabelOps {
  @get list(): WishLabelList | ApiError;
  @post create(@body body: CreateWishLabelRequest): WishLabel | ApiError;
  @put   @route("{id}") update(@path id: string, @body body: UpdateWishLabelRequest): WishLabel | ApiError;
  @delete @route("{id}") delete(@path id: string): void | ApiError;
}
