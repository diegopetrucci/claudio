# TODO

- Fix Docker build caching step with local path dependencies:
  - `Dockerfile` runs `swift package resolve` before local packages are copied.
  - Adjust Docker layering so all path dependencies exist before `swift package resolve`:
    - `AnthropicClient`
    - `SessionStore`
    - `TelegramClient`
    - `TelegramBotService`
    - `AppLifecycleHandler`
    - `ToolExecutor`
    - `SearchTool`

- Add meaningful tests for `AppLifecycleHandler`:
  - Cover polling retry-after-request-error behavior (including retry delay/backoff assertions).
  - Expand cancellation/shutdown semantics coverage (task stop guarantees, no post-shutdown processing).

- Add failure behavior policy for Anthropic failures:
  - Decide whether to send a fallback message to Telegram users when generation fails.
  - Add polling/update-processing tests for Anthropic failure behavior.

- Add duplicate-update protection for Telegram update processing:
  - Track processed `update_id` values.
  - Ensure repeated deliveries do not trigger duplicate processing/replies.

- Improve test-time dependency safety in witness services:
  - Consider replacing permissive default closures in test wiring with explicit unimplemented-style defaults.
