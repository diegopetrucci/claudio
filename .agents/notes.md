[0] New service boundaries in this repo should use protocol-witness style structs (closure-based APIs, like TelegramClient/TelegramBotService) instead of exposing concrete actor types directly.
[1] Keep one top-level model/object per source file (for example: SessionMessageRole.swift, SessionMessage.swift, SessionStore.swift).
[0] For witness-style services, avoid a second "live implementation" type; keep the live implementation directly in the witness file/extension (like TelegramClient.live).
[0] Session persistence models/store types belong in their own package rather than under TelegramBotService.
[0] Do not add forward-looking APIs/dependencies before they are needed (for example: no unused flush endpoint and no unused package imports).
[1] In witness-style `live` factories, inline helper logic directly in closure fields when it is single-use; extract private helpers only when reused.
[0] Shared JSON codec configuration for SessionStore should live in dedicated source files (e.g., JSONDecoder.swift/JSONEncoder.swift) and be reused from SessionStore.swift.
[0] Formatting preference: for tiny `guard` else branches, place `else` on the next line with a single-line body (`else { return ... }`, `else { continue }`, `else { throw ... }`).
[0] Formatting preference: for tiny `defer` bodies, use single-line form (`defer { ... }`).
[1] In `configure.swift`, follow existing pattern of dedicated `configureX(app)` helper functions instead of inlining setup logic in `configure(_:)`.
[0] For quit persistence, wire a `flush` closure through lifecycle shutdown and invoke it even if the polling task was never started.
[0] Session persistence is not only storage: generated replies must use session history context in prompts.
[0] Telegram session files are keyed by `chat.id` (for example `123.jsonl`); `from.id` is decoded only for sender checks and is not part of the session key.
[0] In SessionStore append paths, do not assume `.sessions` still exists; recreate directory and verify file creation result before opening file handles.
[1] If `swift run` logs `Address already in use` (`errno: 48`), an existing `claudio` process is usually already bound to `127.0.0.1:8080`; verify with `lsof -nP -iTCP:8080 -sTCP:LISTEN`, then `kill <PID>` (and if it remains in `T`/stopped state, use `kill -9 <PID>`) or run with `PORT=8081`.
[0] `SessionStoreError` bridged as NSError uses code `0` for `unableToCreateSessionFile(String)` and code `1` for `invalidUTF8`; `localizedDescription` alone is opaque.
[0] In this package setup, adding `LocalizedError` conformance requires `import Foundation` in the defining source file.
[0] For file-system work in this repo's `SessionStore`, prefer `URL.path` (decoded) over `URL.path()`; the latter can surface percent-encoded paths (e.g. `%20`) and break `FileManager` lookups/creation.
[0] When user requests a lifecycle naming refactor, apply it consistently at type + package + directory level (not just symbol rename) to match repo expectations.
[0] Module inventory in this repo includes `SessionStore` as a first-class local package dependency of both root app and `TelegramBotService`; documentation that lists only four local packages is outdated.
[0] In polling lifecycle code, do not swallow `handleIncomingText` failures if cursor advancement is tied to loop progress; otherwise failed updates get acknowledged and are lost after restart.
[0] In polling lifecycle code, rethrowing `handleIncomingText` failures before advancing `offset` can create a poison-message loop (same update retried forever); handle transient vs permanent failures explicitly.
[0] Top-level `private` types are file-scoped in Swift; shared helper types under `Sources/<Module>/` that are referenced across files (for example `PollingTaskState`) must be at least internal.
[0] In SessionStore, recreate `.sessions` before writing `polling_cursor.json` just like append paths, so cursor persistence survives directory deletion at runtime.
[0] In this workspace, `swift test` at repo root runs only root target tests; run `swift test --package-path <LocalPackage>` for changed local packages (e.g. SessionStore, TelegramBotService, AppLifecycleHandler).
[0] Anthropic system behavior is sourced from `SOUL.md` via file I/O in `AnthropicClient`; do not expose runtime/env/user overrides for this system prompt.
[0] For AnthropicClient-style APIs, prefer a single `.live(...)` entrypoint with injectable closures (system prompt loader and message sender) for tests instead of multiple `.live` overloads.
[0] Ensure `SOUL.md` exists at startup (create with canonical content if missing) before constructing `AnthropicClient.live`, so Docker/runtime launches are not blocked by missing prompt files.
[0] Keep `AnthropicClient.defaultSystemPrompt` as the canonical in-code SOUL content and reuse it in file-writing/tests to avoid symbol drift and package-test compile breaks.
