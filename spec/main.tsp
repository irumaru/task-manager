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
// Auth
// ---------------------------------------------------------------------------

model GoogleAuthRequest {
  @doc("Google ID token obtained from Google Sign-In")
  idToken: string;
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
  priorityId: string | null;
  tagIds: string[];
  createdAt: utcDateTime;
  updatedAt: utcDateTime;
}

model CreateTaskRequest {
  title: string;
  memo?: string;
  dueDate?: utcDateTime;
  statusId: string;
  priorityId?: string;
  tagIds?: string[];
}

model UpdateTaskRequest {
  title?: string;
  memo?: string | null;
  dueDate?: utcDateTime | null;
  statusId?: string;
  priorityId?: string | null;
  tagIds?: string[];
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

  @patch
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

model UpdateStatusRequest {
  name?: string;
  displayOrder?: int32;
}

@route("/statuses")
@tag("Statuses")
@useAuth(BearerAuth)
interface StatusOps {
  @get list(): StatusList | ApiError;
  @post create(@body body: CreateStatusRequest): Status | ApiError;

  @patch
  @route("{id}")
  update(@path id: string, @body body: UpdateStatusRequest): Status | ApiError;

  @delete
  @route("{id}")
  delete(@path id: string): void | ApiError;
}

// ---------------------------------------------------------------------------
// Priorities
// ---------------------------------------------------------------------------

model Priority {
  id: string;
  name: string;
  displayOrder: int32;
}

model PriorityList {
  items: Priority[];
}

model CreatePriorityRequest {
  name: string;
  displayOrder: int32;
}

model UpdatePriorityRequest {
  name?: string;
  displayOrder?: int32;
}

@route("/priorities")
@tag("Priorities")
@useAuth(BearerAuth)
interface PriorityOps {
  @get list(): PriorityList | ApiError;
  @post create(@body body: CreatePriorityRequest): Priority | ApiError;

  @patch
  @route("{id}")
  update(@path id: string, @body body: UpdatePriorityRequest): Priority | ApiError;

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

model UpdateTagRequest {
  name?: string;
}

@route("/tags")
@tag("Tags")
@useAuth(BearerAuth)
interface TagOps {
  @get list(): TagList | ApiError;
  @post create(@body body: CreateTagRequest): Tag | ApiError;

  @patch
  @route("{id}")
  update(@path id: string, @body body: UpdateTagRequest): Tag | ApiError;

  @delete
  @route("{id}")
  delete(@path id: string): void | ApiError;
}
