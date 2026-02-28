# Claudio Architecture

## Overview

`claudio` is a Vapor-based Telegram bot that:

1. Long-polls Telegram for new updates.
2. Filters incoming messages by an allowlist of Telegram `chat.id` values.
3. Builds a text prompt from persisted per-chat history.
4. Calls Anthropic and supports tool-use rounds.
5. Sends the final response back to Telegram.
6. Persists both chat history and the polling cursor on disk.

The executable target is intentionally thin: startup/configuration and lifecycle wiring happen in `Sources/claudio`, while behavior is implemented in local packages.

## Module Boundaries

### Root executable (`claudio`)

- Files: `Sources/claudio/*`
- Responsibilities:
  - Startup/shutdown (`entrypoint.swift`)
  - Environment loading and dependency wiring (`configure.swift`)
  - Store dependencies in `Application.storage` keys
  - Register `AppLifecycleHandler` as the runtime loop
  - HTTP routes (currently empty)

### `AppLifecycleHandler`

- Files: `AppLifecycleHandler/Sources/AppLifecycleHandler/*`
- Responsibilities:
  - Parse allowed chat IDs from `ALLOWED_TELEGRAM_CHAT_IDS`
  - Start polling loop on app boot
  - Resume from persisted cursor (`lastProcessedUpdateID`)
  - Ignore non-text, bot-originated, or unauthorized chat messages
  - Dispatch valid text messages to `TelegramBotService`
  - Persist cursor after each processed update (including failed handling)
  - Retry polling failures with backoff
  - Cancel polling task and flush sessions on shutdown

### `TelegramBotService`

- File: `TelegramBotService/Sources/TelegramBotService/TelegramBotService.swift`
- Responsibilities:
  - Append incoming user message to session history
  - Build prompt from last 20 session messages
  - Call `AnthropicClient.respond`
  - Send generated reply to Telegram
  - Append assistant message after successful send

### `AnthropicClient`

- Files: `AnthropicClient/Sources/AnthropicClient/*`
- Responsibilities:
  - Wrap Anthropic Messages API interaction
  - Resolve model from `AnthropicModel`
  - Load system prompt from `SOUL.md`
  - Ensure `SOUL.md` exists at startup (writes default prompt if missing)
  - Execute tool-use loops (up to 6 rounds) and feed tool results back to Anthropic
  - Return final text response
- Depends on:
  - `SwiftAnthropic`
  - `ToolExecutor`

### `ToolExecutor`

- Files: `ToolExecutor/Sources/ToolExecutor/*`
- Responsibilities:
  - Execute shell commands (`run_command`) with timeout
  - Read files (`read_file`)
  - Write files (`write_file`)
  - Execute web search (`web_search`) via `SearchTool` when configured
  - Define tool catalog/schema exposed to Anthropic
  - Surface per-tool typed errors
- Current state:
  - `web_search` is always advertised in the tool catalog.
  - If `WEB_SEARCH_API_KEY` is unset, execution fails with `webSearchNotConfigured`.

### `SearchTool`

- Files: `SearchTool/Sources/SearchTool/*`
- Responsibilities:
  - Provider-agnostic search client wrapper
  - Current live implementation targets Brave Search API
  - Request construction, response decoding, and transport/status error mapping
- Current state:
  - Wired into `ToolExecutor.live(searchTool:)` when `WEB_SEARCH_API_KEY` is present.

### `TelegramClient`

- Files: `TelegramClient/Sources/TelegramClient/*`
- Responsibilities:
  - Telegram Bot API transport (`getUpdates`, `sendMessage`)
  - Payload models and API error mapping

### `SessionStore`

- Files: `SessionStore/Sources/SessionStore/*`
- Responsibilities:
  - Persist per-chat transcript JSONL files
  - Persist polling cursor JSON
  - Recreate session directory on writes if removed
  - Flush file handles on shutdown

## Dependency Graph

```mermaid
graph TD
    A["claudio executable"] --> B["AppLifecycleHandler"]
    A --> C["TelegramBotService"]
    A --> D["TelegramClient"]
    A --> E["AnthropicClient"]
    A --> F["SessionStore"]

    B --> D
    B --> C
    B --> F

    C --> D
    C --> E
    C --> F

    E --> G["ToolExecutor"]
    G --> H["SearchTool (enabled when WEB_SEARCH_API_KEY is set)"]
```

## Runtime Flow

1. `Entrypoint.main` creates a Vapor `Application`, runs `configure(_:)`, then `app.execute()`.
2. `configure(_:)`:
   - loads `.env`
   - constructs `SessionStore.live(...)`
   - constructs `TelegramClient.live(...)` (requires `TELEGRAM_BOT_TOKEN`)
   - constructs `ToolExecutor.live(...)`:
     - default `ToolExecutor.live()` when `WEB_SEARCH_API_KEY` is missing
     - injects `SearchTool.live(apiKey:)` when `WEB_SEARCH_API_KEY` is present
   - constructs `AnthropicClient.live(...)` (requires `ANTHROPIC_API_KEY`, receives configured `ToolExecutor`)
   - ensures `SOUL.md` exists
   - constructs `TelegramBotService.live(...)`
   - constructs/registers `AppLifecycleHandler` (requires `ALLOWED_TELEGRAM_CHAT_IDS`)
3. On boot, `AppLifecycleHandler.didBootAsync`:
   - loads last cursor from `SessionStore`
   - starts long-polling loop via `getUpdates(offset, timeout)`
4. For each update:
   - ignore updates without `message`
   - ignore bot-authored messages
   - ignore empty text
   - ignore chats not in allowlist
   - call `TelegramBotService.handleIncomingText(chatID, text)`
   - advance/persist cursor regardless of handling success to avoid poison-message replay loops
5. `TelegramBotService.handleIncomingText`:
   - append user message to session file
   - load session and build prompt from the latest 20 messages (`User:` / `Assistant:` lines + trailing `Assistant:`)
   - call `AnthropicClient.respond`
   - send reply via `TelegramClient.sendMessage`
   - append assistant reply to session file
6. `AnthropicClient.respond`:
   - sends message to Anthropic with system prompt and tool catalog
   - if Anthropic requests tool use, executes tools via `ToolExecutor`, appends `tool_result` (`isError` on failures), and re-queries Anthropic
   - repeats until final text is returned or max tool rounds is reached
7. On shutdown, lifecycle handler cancels polling task and flushes `SessionStore`.

## Persistence Model

Storage root: `./.sessions` (relative to app working directory).

- Transcript per chat: `<chatID>.jsonl`
  - one JSON object per line
  - schema fields: `schemaVersion`, `role`, `text`, `timestamp`
  - loader skips malformed/unsupported records
- Polling cursor: `polling_cursor.json`
  - fields: `schemaVersion`, `lastProcessedUpdateID`

This guarantees conversation and polling continuity across restarts.

## Concurrency Model

- Service packages are mostly closure-based witness structs marked `Sendable`.
- Polling task lifecycle is managed by actor `PollingTaskState`.
- `AppLifecycleHandler` is `@unchecked Sendable`, with mutable task state isolated in the actor.
- Polling retries use async sleep (`Task.sleep`) with configurable delay.

## Configuration

Required environment variables:

- `TELEGRAM_BOT_TOKEN`
- `ALLOWED_TELEGRAM_CHAT_IDS`
- `ANTHROPIC_API_KEY`

Optional environment variables:

- `ANTHROPIC_MODEL` (`opus` | `sonnet` | `haiku`, default: `sonnet`)
- `ANTHROPIC_MAX_TOKENS` (default: `1024`, must be `> 0`)
- `WEB_SEARCH_API_KEY` (enables `web_search` tool execution via Brave Search API)

`SOUL.md` is treated as required runtime prompt content; missing file is auto-created with default prompt content at startup.

## Error Handling

- Polling:
  - polling request failures are logged and retried
  - cursor persistence failures are logged and polling continues
- Message handling:
  - per-update processing failures are logged
  - update is still acknowledged by cursor advancement
- Anthropic tool-use:
  - tool execution failures are returned to Anthropic as `tool_result` with `isError: true`
  - generation continues within the tool loop unless max rounds are exceeded
- Package-typed errors include:
  - `TelegramClientError`
  - `AnthropicClientError`
  - `SessionStoreError`
  - `ToolExecutorError`
  - `SearchToolError`

## Testing Coverage

- Root app:
  - unknown route returns 404
- `TelegramClient`:
  - request encoding, response decoding, API error mapping
- `SessionStore`:
  - append/load round-trip, malformed line tolerance, cursor persistence, directory recreation, flush
- `TelegramBotService`:
  - happy path, history inclusion, Anthropic failure, Telegram send failure
- `AppLifecycleHandler`:
  - resume from cursor, cursor persistence, shutdown flush, failure continuation, allowlist filtering
- `AnthropicClient`:
  - request construction, response text handling, tool-call round-trips, system prompt file behavior
- `ToolExecutor`:
  - run/read/write behavior and error mapping
  - `web_search` configured/unconfigured paths, error wrapping, and JSON serialization behavior
- `SearchTool`:
  - request building, result decoding, and non-2xx error mapping

## Constraints and Known Gaps

- Polling-only bot operation (no webhook mode).
- No application HTTP routes beyond default 404.
- Prompt format is plain role-prefixed text, not structured conversation objects.
- Tool execution currently has no sandboxing or explicit command allowlist.
- `web_search` is advertised to Anthropic even when `WEB_SEARCH_API_KEY` is unset, in which case calls fail at runtime with a tool error.
- Repository still contains `TelegramPollingLifecycleHandler/` directory and `Application+TelegramPollingTask.swift`, which are not part of current runtime wiring.
