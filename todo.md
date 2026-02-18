# TODO

- Add failure behavior policy for Anthropic failures:
  - Decide whether to send a fallback message to Telegram users when generation fails.
  - Add polling/update-processing tests for Anthropic failure behavior.

- Add duplicate-update protection for Telegram update processing:
  - Track processed `update_id` values.
  - Ensure repeated deliveries do not trigger duplicate processing/replies.
  - remove init for dependencies, use something like tca's unimplemented.
