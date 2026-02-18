# TODO

- Fix Docker build caching step with local path dependencies:
  - `Dockerfile` runs `swift package resolve` before local packages are copied.
  - Adjust the Docker layering strategy so path dependencies (`AnthropicClient`, `TelegramClient`, `TelegramBotService`, `TelegramPollingLifecycleHandler`) exist before resolve.

- Add meaningful tests for `TelegramPollingLifecycleHandler`:
  - Cover offset progression (`update_id + 1` behavior).
  - Cover retry-after-error behavior and cancellation/shutdown semantics.

- Add failure behavior policy for Anthropic failures:
  - Decide whether to send a fallback message to Telegram users when generation fails.
  - Add polling/update-processing tests for Anthropic failure behavior.

- Add duplicate-update protection for Telegram update processing:
  - Track processed `update_id` values.
  - Ensure repeated deliveries do not trigger duplicate processing/replies.
  - remove init for dependencies, use something like tca's unimplemented.
