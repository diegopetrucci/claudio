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
