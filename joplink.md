# Joplink MCP Server - Complete Documentation

## Package Information

**Name:** joplink
**Version:** 0.2.0
**Summary:** MCP server providing AI assistants with structured access to Joplin Data API
**License:** MIT
**Python:** >=3.12
**Homepage:** https://github.com/yourusername/joplink

### Dependencies

- `fastmcp==2.13.1` - FastMCP framework for MCP server
- `httpx==0.28.1` - HTTP client for API requests
- `pydantic==2.12.4` - Data validation
- `pydantic-settings>=2.6.0` - Settings management

### Keywords

ai, api, assistant, joplin, mcp, notes

---

## Architecture Overview

Joplink is structured in layers:

1. **Low-Level Layer** (`joplink.low_level.*`)
   - Direct HTTP communication with Joplin Data API
   - Service classes for notes, folders, tags, search, and ping
   - Error handling and request/response management
   - Configuration management

2. **High-Level Layer** (`joplink.high_level`)
   - Path-aware operations (e.g., "folder/subfolder/note")
   - Convenience methods (append, rename, move)
   - Automatic ID resolution for paths
   - Caching for path-to-ID mappings

3. **MCP Layer** (`joplink.mcp.*`)
   - MCP server implementation using FastMCP
   - Tool registration for AI assistants
   - Error mapping to MCP error codes
   - Configuration via environment variables

### Module Structure

```
joplink/
├── __init__.py                      # Main exports
├── models.py                        # Data models (Note, Folder, Tag)
├── high_level.py                    # High-level client with path support
├── path_mapping.py                  # Path-to-ID resolution
├── tag_mapping.py                   # Tag title-to-ID resolution
├── low_level/
│   ├── base.py                      # Base service, config, errors
│   ├── client.py                    # Main low-level client
│   ├── notes_service.py             # Note CRUD operations
│   ├── folders_service.py           # Folder CRUD operations
│   ├── tags_service.py              # Tag CRUD operations
│   ├── search_service.py            # Search functionality
│   └── ping_service.py              # Health check
└── mcp/
    ├── __init__.py                  # MCP exports
    ├── server.py                    # MCP server factory
    ├── config.py                    # MCP settings
    ├── errors.py                    # Error handling
    ├── models.py                    # MCP-specific models
    └── tools/
        ├── __init__.py              # Tool registration
        ├── notes.py                 # Note tools
        ├── folders.py               # Folder tools
        ├── tags.py                  # Tag tools
        └── paths.py                 # Path-based tools
```

---

## Configuration

### Low-Level Client Configuration

The low-level `JoplinClient` uses `JoplinConfig`:

```python
from joplink import JoplinClient, JoplinConfig

config = JoplinConfig(
    base_url="http://localhost:41184",  # Default: http://127.0.0.1:41184
    token="YOUR_API_TOKEN",              # Required
    timeout=30.0                         # Default: 10.0 seconds
)

client = JoplinClient(config)
```

**Environment Variables:**
- `JOPLIN_BASE_URL` - Base URL of Joplin server
- `JOPLIN_TOKEN` - API token (required)
- `JOPLIN_TIMEOUT` - Request timeout in seconds

### MCP Server Configuration

The MCP server uses `McpSettings` (loaded from environment):

```bash
export JOPLINK_JOPLIN_BASE_URL=http://localhost:41184
export JOPLINK_JOPLIN_TOKEN=your_token_here
export JOPLINK_JOPLIN_TIMEOUT_SECONDS=30
export JOPLINK_LOG_LEVEL=INFO
export JOPLINK_MCP_SERVER_NAME=joplink-mcp
export JOPLINK_MCP_SERVER_VERSION=0.1.0
```

**Settings Class:**

```python
class McpSettings(BaseSettings):
    joplin_base_url: AnyHttpUrl
    joplin_token: SecretStr
    joplin_timeout_seconds: PositiveInt | None = 30
    log_level: Literal["DEBUG", "INFO", "WARNING", "ERROR"] = "INFO"
    mcp_server_name: str = "joplink-mcp"
    mcp_server_version: str = "0.1.0"

    model_config = SettingsConfigDict(
        env_prefix="JOPLINK_",
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )
```

### Passing Environment Variables via `reg-mcp`

When registering the Joplink MCP server through this repository's `reg-mcp` helper, you can provide environment variables in two ways:

1. **Inline `--env KEY=VALUE` pairs** (simple values)
2. **An `--env-file`** with one `KEY=VALUE` per line (recommended for complex values like JSON or values containing `%Y`, `%m`, etc.)

**Basic registration:**

```bash
reg-mcp --name joplink \
    --command 'python3 -m joplink.mcp.server' \
    --env 'JOPLINK_JOPLIN_TOKEN=XXX' \
    --env 'JOPLINK_JOPLIN_BASE_URL=http://host.docker.internal:41184'
```

**Using an env file for complex values:**

Create `joplink.env`:

```bash
JOPLINK_JOPLIN_TOKEN=XXX
JOPLINK_JOPLIN_BASE_URL=http://host.docker.internal:41184
JOPLINK_MACROS={"today":"Journal/%%Y/%%m/%%Y-%%m-%%d"}
JOPLINK_TOOLS=["get_note","save_note","append_to_note","search_notes","get_folder","search_folders","list_child_folders","list_notes_in_folder","get_path"]
```

Then register:

```bash
reg-mcp --name joplink \
    --command 'python3 -m joplink.mcp.server' \
    --env-file ./joplink.env

If you prefer running via `uv`, make sure you don't accidentally pick up a bind-mounted
project venv from `/workspace` (for example, a `/workspace/.venv` or a `pyproject.toml`).
In that case, use:

```bash
uv run --no-project python -m joplink.mcp.server
```
```

The `--env-file` approach avoids most shell quoting issues on Windows and is the most robust way to pass JSON configuration such as `JOPLINK_MACROS` and `JOPLINK_TOOLS`.

**Percent (`%`) handling on Windows:**

- Both inline `--env` values and values inside `--env-file` ultimately pass through Windows tooling that treats `%` specially.
- To reliably get a single `%` into the container (for formats like `%Y`, `%m`, etc.), always write `%%Y`, `%%m`, and so on in your values. They will arrive inside the container as `%Y`, `%m`, etc.

### Registration with Claude Code

Use the included `reg-mcp` script:

```sh
reg-mcp --name joplink \
    --command 'python3 -m joplink.mcp.server' \
  --env 'JOPLINK_JOPLIN_TOKEN=XXX' \
  --env 'JOPLINK_JOPLIN_BASE_URL=http://host.docker.internal:41184'
```

Or manually configure in Claude Desktop:

```json
{
  "mcpServers": {
    "joplink": {
      "command": "joplink-mcp",
      "env": {
        "JOPLINK_JOPLIN_BASE_URL": "http://localhost:41184",
        "JOPLINK_JOPLIN_TOKEN": "your_token_here"
      }
    }
  }
}
```

---

## Error Hierarchy

### Exception Classes

All errors inherit from `JoplinClientError`:

```python
class JoplinClientError(Exception):
    """Base error for Joplin client failures."""

class JoplinConfigError(JoplinClientError):
    """Raised when required configuration (token) is missing or invalid."""

class JoplinRequestError(JoplinClientError):
    """Raised when an httpx request fails (connectivity, DNS, etc.)."""

class JoplinTimeoutError(JoplinClientError):
    """Raised when a request times out."""

class JoplinAuthError(JoplinClientError):
    """Raised for authentication/authorization errors (401/403)."""

class JoplinNotFoundError(JoplinClientError):
    """Raised for 404 Not Found responses."""

class JoplinPathError(JoplinClientError):
    """Raised when a path has invalid format or escape sequences."""

class JoplinServerError(JoplinClientError):
    """Raised for 5xx server error responses."""
```

### MCP Error Mapping

MCP tools map exceptions to error codes:

| Exception | MCP Error Code | Description |
|-----------|----------------|-------------|
| `JoplinNotFoundError` | `NOT_FOUND` | Resource not found |
| `JoplinPathError` | `INVALID_ARGUMENT` | Invalid path syntax |
| `JoplinClientError` | `UPSTREAM_ERROR` | Joplin API error |
| `JoplinConfigError` | `CONFIG_ERROR` | Configuration error |
| Other exceptions | `INTERNAL` | Unexpected error |

**Error Payload Structure:**

```json
{
    "code": "NOT_FOUND",
    "message": "Note not found: projects/nonexistent",
    "details": {
        "tool": "joplin_get_note",
        "resource_id": "projects/nonexistent"
    }
}
```

---

## Data Models

### JoplinNote

```python
class JoplinNote(BaseModel):
    id: str
    parent_id: Optional[str] = None
    title: Optional[str] = None
    body: Optional[str] = None
    created_time: Optional[int] = None
    updated_time: Optional[int] = None
    is_conflict: Optional[int] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    altitude: Optional[float] = None
    author: Optional[str] = None
    is_todo: Optional[int] = None
    todo_due: Optional[int] = None
    todo_completed: Optional[int] = None
    source: Optional[str] = None
    source_application: Optional[str] = None
    user_created_time: Optional[int] = None
    user_updated_time: Optional[int] = None
    deleted_time: Optional[int] = None
    body_html: Optional[str] = None
    base_url: Optional[str] = None
```

### JoplinFolder

```python
class JoplinFolder(BaseModel):
    id: str
    title: Optional[str] = None
    created_time: Optional[int] = None
    updated_time: Optional[int] = None
    parent_id: Optional[str] = None
    deleted_time: Optional[int] = None
```

### JoplinTag

```python
class JoplinTag(BaseModel):
    id: str
    title: Optional[str] = None
    created_time: Optional[int] = None
    updated_time: Optional[int] = None
    deleted_time: Optional[int] = None
```

### PagedResults

Generic paginated response structure:

```python
class PagedResults(BaseModel, Generic[T]):
    items: List[T]
    has_more: bool
    page: int = Field(default=1, description="1-indexed page number")
    limit: int = Field(default=10, description="Maximum items per page")
```

**Pagination Constants:**
- `DEFAULT_PAGE = 1` (1-indexed)
- `DEFAULT_LIMIT = 10`

---

## MCP Tools Reference

All tools are registered via `register_all_tools(mcp, client)` which calls:
- `register_note_tools(mcp, client)`
- `register_folder_tools(mcp, client)`
- `register_tag_tools(mcp, client)`
- `register_path_tools(mcp, client)`

### Note Operations

#### joplin_get_note

Get a note by ID or path.

**Parameters:**
- `note_ref` (required): Joplin note ID (32-char hex) or path like "folder/note"
- `fields` (optional): List of fields to include in response

**Returns:** Note data as dictionary

**Raises:**
- `JoplinNotFoundError`: If the note does not exist
- `JoplinPathError`: If the path syntax is invalid
- `JoplinClientError`: If the Joplin API returns an error

**Implementation:**
```python
@mcp.tool(name="joplin_get_note")
@handle_mcp_errors(tool_name="joplin_get_note")
def joplin_get_note(note_ref: str, fields: list[str] | None = None) -> dict[str, Any]:
    note = client.get_note(note_ref, fields=fields)
    return note.model_dump(exclude_none=True)
```

---

#### joplin_save_note

Create or update a note. If the note exists, it is updated. If not and note_ref is a path, creates a new note.

**Parameters:**
- `note_ref` (required): Joplin note ID or path like "folder/note_title"
- `body` (optional): Note body content
- `extra_fields` (optional): Additional fields to set

**Returns:** The ID of the created or updated note (string)

**Raises:**
- `JoplinNotFoundError`: If note_ref is an ID and the note does not exist
- `JoplinPathError`: If the path syntax is invalid or parent folder doesn't exist
- `JoplinClientError`: If the Joplin API returns an error

---

#### joplin_delete_note

Delete a note by ID or path.

**Parameters:**
- `note_ref` (required): Joplin note ID or path

**Returns:** `{"success": True}`

**Raises:**
- `JoplinNotFoundError`: If the note does not exist
- `JoplinPathError`: If the path syntax is invalid
- `JoplinClientError`: If the Joplin API returns an error

---

#### joplin_append_to_note

Append content to an existing note.

**Parameters:**
- `note_ref` (required): Joplin note ID or path
- `content` (required): The content to append
- `separator` (optional): Separator between existing and new content (default: newline)

**Returns:** The ID of the updated note (string)

**Raises:**
- `JoplinNotFoundError`: If the note does not exist
- `JoplinPathError`: If the path syntax is invalid
- `JoplinClientError`: If the Joplin API returns an error

---

#### joplin_replace_note_body

Replace the entire body of a note.

**Parameters:**
- `note_ref` (required): Joplin note ID or path
- `body` (required): The new note body

**Returns:** The ID of the updated note (string)

**Raises:**
- `JoplinNotFoundError`: If the note does not exist
- `JoplinPathError`: If the path syntax is invalid
- `JoplinClientError`: If the Joplin API returns an error

---

#### joplin_list_notes

List notes, optionally filtering by search query.

**Parameters:**
- `query` (optional): Search query. If None, lists all notes
- `fields` (optional): Fields to include in response
- `page` (optional): Page number for pagination
- `limit` (optional): Limit on results

**Returns:** Paged results dictionary with `items`, `has_more`, `page`, `limit`

**Raises:**
- `JoplinClientError`: If the Joplin API returns an error

---

### Folder Operations

#### joplin_create_folder

Create a new folder at the specified path.

**Parameters:**
- `path` (required): Folder path like "parent/child" or just "name" for root folder
- `extra_fields` (optional): Additional fields to set

**Returns:** The ID of the created folder (string)

**Raises:**
- `JoplinPathError`: If path syntax is invalid or parent folder doesn't exist
- `JoplinClientError`: If the Joplin API returns an error

---

#### joplin_get_folder

Get a folder by ID or path.

**Parameters:**
- `folder_ref` (required): Joplin folder ID (32-char hex) or path like "parent/child"
- `fields` (optional): List of fields to include in response

**Returns:** Folder data as dictionary

**Raises:**
- `JoplinNotFoundError`: If the folder does not exist
- `JoplinPathError`: If the path syntax is invalid
- `JoplinClientError`: If the Joplin API returns an error

---

#### joplin_delete_folder

Delete a folder by ID or path.

**Parameters:**
- `folder_ref` (required): Joplin folder ID or path

**Returns:** `{"success": True}`

**Raises:**
- `JoplinNotFoundError`: If the folder does not exist
- `JoplinPathError`: If the path syntax is invalid
- `JoplinClientError`: If the Joplin API returns an error

---

#### joplin_list_folders

List folders, optionally filtering by search query.

**Parameters:**
- `query` (optional): Search query. If None, lists all folders
- `fields` (optional): Fields to include in response
- `page` (optional): Page number for pagination
- `limit` (optional): Limit on results

**Returns:** Paged results dictionary with `items`, `has_more`, `page`, `limit`

**Raises:**
- `JoplinClientError`: If the Joplin API returns an error

---

#### joplin_list_child_folders

List child folders of a folder.

**Parameters:**
- `folder_ref` (optional): Joplin folder ID or path, or None for root-level folders
- `fields` (optional): Fields to include in response

**Returns:** List of child folder dictionaries

**Raises:**
- `JoplinNotFoundError`: If the folder does not exist
- `JoplinPathError`: If the path syntax is invalid
- `JoplinClientError`: If the Joplin API returns an error

---

#### joplin_move_folder

Move a folder to a different parent folder.

**Parameters:**
- `folder_ref` (required): Joplin folder ID or path to move
- `to_folder_ref` (optional): Destination folder ID or path, or None to move to root

**Returns:** The ID of the updated folder (string)

**Raises:**
- `JoplinNotFoundError`: If source or destination folder does not exist
- `JoplinPathError`: If the path syntax is invalid
- `JoplinClientError`: If the Joplin API returns an error

---

#### joplin_rename_folder

Rename a folder.

**Parameters:**
- `folder_ref` (required): Joplin folder ID or path
- `new_title` (required): The new title for the folder

**Returns:** The ID of the updated folder (string)

**Raises:**
- `JoplinNotFoundError`: If the folder does not exist
- `JoplinPathError`: If the path syntax is invalid
- `JoplinClientError`: If the Joplin API returns an error

---

### Tag Operations

#### joplin_save_tag

Get or create a tag by name. If a tag with the given name exists, it is returned. Otherwise, a new tag is created.

**Parameters:**
- `name` (required): The tag name/title

**Returns:** The ID of the existing or newly created tag (string)

**Raises:**
- `JoplinClientError`: If the Joplin API returns an error

---

#### joplin_get_tag

Get a tag by ID or title.

**Parameters:**
- `tag_ref` (required): Joplin tag ID (32-char hex) or tag title
- `fields` (optional): List of fields to include in response

**Returns:** Tag data as dictionary

**Raises:**
- `JoplinNotFoundError`: If the tag does not exist
- `JoplinClientError`: If the Joplin API returns an error

---

#### joplin_delete_tag

Delete a tag by ID or title.

**Parameters:**
- `tag_ref` (required): Joplin tag ID or title

**Returns:** `{"success": True}`

**Raises:**
- `JoplinNotFoundError`: If the tag does not exist
- `JoplinClientError`: If the Joplin API returns an error

---

#### joplin_list_tags

List tags, optionally filtering by search query.

**Parameters:**
- `query` (optional): Search query. If None, lists all tags
- `fields` (optional): Fields to include in response
- `page` (optional): Page number for pagination
- `limit` (optional): Limit on results

**Returns:** Paged results dictionary with `items`, `has_more`, `page`, `limit`

**Raises:**
- `JoplinClientError`: If the Joplin API returns an error

---

#### joplin_tag_note

Add a tag to a note. If tag_ref is a title (not an ID), the tag is created if it doesn't exist.

**Parameters:**
- `note_ref` (required): Joplin note ID or path
- `tag_ref` (required): Joplin tag ID or tag title

**Returns:** `{"success": True}`

**Raises:**
- `JoplinNotFoundError`: If the note does not exist
- `JoplinPathError`: If the note path syntax is invalid
- `JoplinClientError`: If the Joplin API returns an error

---

#### joplin_untag_note

Remove a tag from a note.

**Parameters:**
- `note_ref` (required): Joplin note ID or path
- `tag_ref` (required): Joplin tag ID or tag title

**Returns:** `{"success": True}`

**Raises:**
- `JoplinNotFoundError`: If the note or tag does not exist
- `JoplinPathError`: If the note path syntax is invalid
- `JoplinClientError`: If the Joplin API returns an error

---

#### joplin_list_notes_for_tag

List notes associated with a tag.

**Parameters:**
- `tag_ref` (required): Joplin tag ID or tag title
- `fields` (optional): Fields to include in response
- `page` (optional): Page number for pagination
- `limit` (optional): Limit on results

**Returns:** Paged results dictionary with `items`, `has_more`, `page`, `limit`

**Raises:**
- `JoplinNotFoundError`: If the tag does not exist
- `JoplinClientError`: If the Joplin API returns an error

---

### Path Operations

#### joplin_list_notes_in_folder

List notes in a specific folder.

**Parameters:**
- `folder_ref` (required): Joplin folder ID (32-char hex) or path like "parent/child"
- `fields` (optional): Fields to include in response
- `page` (optional): Page number for pagination
- `limit` (optional): Limit on results

**Returns:** Paged results dictionary with `items`, `has_more`, `page`, `limit`

**Raises:**
- `JoplinNotFoundError`: If the folder does not exist
- `JoplinPathError`: If the path syntax is invalid
- `JoplinClientError`: If the Joplin API returns an error

---

## High-Level Client API

The `HighLevelJoplinClient` provides a more ergonomic API with path support.

### Initialization

```python
from joplink import JoplinClient, HighLevelJoplinClient

low_level = JoplinClient()
client = HighLevelJoplinClient(low_level)
```

### Path Resolution

Joplink IDs are 32-character lowercase hexadecimal strings. The high-level client automatically distinguishes between IDs and paths:

```python
# Using ID
note = client.get_note("a1b2c3d4e5f6...")

# Using path
note = client.get_note("Projects/MyNote")
```

**Path Escaping:**
- Use `\/` to escape a slash in a title
- Use `\\` to escape a backslash

### Note Methods

```python
# Get note
note = client.get_note(note_ref, fields=["id", "title", "body"])

# Create or update note
note = client.save_note("folder/note", body="Content", is_todo=1)

# Delete note
client.delete_note(note_ref)

# Append to note
note = client.append_to_note(note_ref, "New content", separator="\n\n")

# Replace note body
note = client.replace_note_body(note_ref, "Completely new body")

# Move note
note = client.move_note(note_ref, to_folder_ref="NewFolder")

# Rename note
note = client.rename_note(note_ref, new_title="New Title")

# List notes
results = client.list_notes(query="search term", page=1, limit=20)

# List notes in folder
results = client.list_notes_in_folder(folder_ref, fields=["id", "title"])
```

### Folder Methods

```python
# Create folder
folder = client.create_folder("parent/child")

# Get folder
folder = client.get_folder(folder_ref, fields=["id", "title"])

# Delete folder
client.delete_folder(folder_ref)

# Move folder
folder = client.move_folder(folder_ref, to_folder_ref="NewParent")
folder = client.move_folder(folder_ref, to_folder_ref=None)  # Move to root

# Rename folder
folder = client.rename_folder(folder_ref, new_title="New Name")

# List folders
results = client.list_folders(query="search term")

# List child folders
folders = client.list_child_folders(folder_ref)
folders = client.list_child_folders(None)  # Root-level folders
```

### Tag Methods

```python
# Get or create tag
tag = client.save_tag("important")

# Get tag
tag = client.get_tag(tag_ref, fields=["id", "title"])

# Delete tag
client.delete_tag(tag_ref)

# Tag a note
client.tag_note(note_ref, tag_ref)
client.tag_note("Projects/Note", "important")  # Creates tag if needed

# Untag a note
client.untag_note(note_ref, tag_ref)

# List tags
results = client.list_tags(query="imp")

# List notes for tag
results = client.list_notes_for_tag(tag_ref, page=1, limit=10)
```

---

## Low-Level Client API

The low-level `JoplinClient` provides direct access to service classes.

### Structure

```python
client = JoplinClient(config)

client.notes       # NotesService
client.folders     # FoldersService
client.tags        # TagsService
client.search      # SearchService
client.ping        # PingService
```

### Service Methods

Each service inherits from `BaseService` which provides:
- `_build_url(*parts)` - Construct API URLs
- `_request(method, path, params, json)` - Make HTTP requests
- `_build_pagination_params(fields, page, limit, order_by, order_dir)` - Build query params

---

## Running the MCP Server

### As Console Script

```bash
# Using the installed console script
joplink-mcp

# Or using uv
uv run joplink-mcp

# Or as module
python -m joplink.mcp.server
```

### Programmatically

```python
from joplink.mcp.server import create_mcp_server

server = create_mcp_server()
server.run()
```

### Server Lifecycle

The `main()` function in `server.py`:

1. Loads settings from environment
2. Configures logging
3. Creates `JoplinClient` and `HighLevelJoplinClient`
4. Creates `FastMCP` server
5. Registers all tools
6. Runs the server

**Logging:**
- Structured JSON logging to stderr
- Format: `{"time": "...", "level": "...", "logger": "...", "message": "..."}`
- Events: `server_start`, `server_ready`, `tool_invoke`, `tool_result`, `tool_error`, `server_stop`

---

## Path Conventions

### ID Format

Joplin IDs are 32-character lowercase hexadecimal strings:
```
^[0-9a-f]{32}$
```

Example: `debc705366024b31a1a40e13be901a0b`

### Path Format

Paths use forward slashes as separators:
- Notes: `"folder/subfolder/note_title"`
- Folders: `"parent/child"`
- Tags: Use title directly (no paths)

**Escaping:**
- `\/` - Escaped slash (literal slash in title)
- `\\` - Escaped backslash (literal backslash in title)

**Examples:**
```python
# Simple path
"Projects/MyNote"

# Path with escaped slash in title
"Work/Client\/Project Meeting"  # Folder is "Work", note is "Client/Project Meeting"

# Path with escaped backslash
"Code\\Snippets"  # Folder is "Code\Snippets"
```

---

## Common Field Names

When using the `fields` parameter to select specific fields:

**All Resources:**
- `id` - Resource ID (32-char hex)
- `title` - Title/name
- `created_time` - Creation timestamp (milliseconds)
- `updated_time` - Last update timestamp (milliseconds)
- `deleted_time` - Deletion timestamp (0 if not deleted)

**Notes Only:**
- `body` - Note content (Markdown)
- `parent_id` - Parent folder ID
- `is_todo` - Is this a to-do item (0 or 1)
- `todo_due` - Due date timestamp
- `todo_completed` - Completion timestamp
- `body_html` - HTML rendering of body
- `latitude`, `longitude`, `altitude` - Location data
- `author` - Author name
- `source` - Source of the note
- `source_application` - Application that created it
- `user_created_time` - User-set creation time
- `user_updated_time` - User-set update time
- `is_conflict` - Is this a conflict note
- `base_url` - Base URL for relative links

**Folders Only:**
- `parent_id` - Parent folder ID (empty string for root)

---

## Usage Examples

### Basic Note Operations

```python
from joplink import JoplinClient, HighLevelJoplinClient

# Initialize
low = JoplinClient()
client = HighLevelJoplinClient(low)

# Create a note
note = client.save_note(
    "Projects/Meeting Notes",
    body="# Meeting with client\\n\\n- Discussed requirements"
)

# Append to it
client.append_to_note(
    "Projects/Meeting Notes",
    "- Reviewed timeline"
)

# Tag it
client.tag_note("Projects/Meeting Notes", "important")

# List all notes in folder
results = client.list_notes_in_folder("Projects")
for note in results.items:
    print(f"{note.title}: {note.id}")
```

### Folder Organization

```python
# Create folder structure
client.create_folder("Work")
client.create_folder("Work/ClientA")
client.create_folder("Work/ClientB")

# Move a folder
client.move_folder("Work/ClientA", to_folder_ref="Archive")

# List child folders
children = client.list_child_folders("Work")
print([f.title for f in children])
```

### Search and Tags

```python
# Search notes
results = client.list_notes(query="meeting")

# Get all tags
all_tags = client.list_tags()

# Get notes with specific tag
tagged = client.list_notes_for_tag("important")

# Untag a note
client.untag_note("Projects/Meeting Notes", "important")
```

---

## Best Practices

### Error Handling

```python
from joplink import (
    JoplinNotFoundError,
    JoplinPathError,
    JoplinClientError
)

try:
    note = client.get_note("NonExistent/Note")
except JoplinNotFoundError:
    print("Note not found")
except JoplinPathError as e:
    print(f"Invalid path: {e}")
except JoplinClientError as e:
    print(f"API error: {e}")
```

### Field Selection

Request only needed fields to reduce payload size:

```python
# Minimal fields for listing
results = client.list_notes(fields=["id", "title", "updated_time"])

# Full note for editing
note = client.get_note(note_id, fields=["id", "title", "body"])
```

### Pagination

Always handle pagination for large result sets:

```python
page = 1
all_notes = []
while True:
    results = client.list_notes(page=page, limit=100)
    all_notes.extend(results.items)
    if not results.has_more:
        break
    page += 1
```

### Path Caching

The high-level client caches path-to-ID mappings. After modifications that change paths (create, delete, rename, move), the cache is automatically invalidated.

---

## Development

### Running Tests

```bash
# Integration tests (requires Joplin CLI)
uv run pytest tests/integration/

# Install Joplin CLI if needed
npm install -g joplin
```

### Package Structure

```bash
# Install with development dependencies
uv pip install joplink[dev]

# Development dependencies include:
# - pytest>=8.0.0
# - pytest-asyncio>=0.23.0
# - pytest-cov>=4.1.0
# - dirty-equals>=0.7.0
# - inline-snapshot>=0.11.0
```

---

## Links

- **Homepage:** https://github.com/yourusername/joplink
- **Documentation:** https://github.com/yourusername/joplink/blob/main/README.md
- **Issues:** https://github.com/yourusername/joplink/issues
- **PyPI:** https://pypi.org/project/joplink/

---

## License

MIT License - See package metadata for full license text.

---

*This documentation was generated from joplink version 0.2.0*
