# claudio

A reimplementation of [OpenClaw](https://github.com/openclaw/openclaw) in Swift & Vapor.

Loosely based on the brilliant [You could've invented OpenClaw](https://gist.github.com/dabit3/bc60d3bea0b02927995cd9bf53c3db32) post.

## Getting Started

1. Copy and fill environment variables:

```bash
cp .env.example .env
```

2. Ensure `SOUL.md` exists in the repo root and is non-empty.
3. Run the app:

```bash
swift run
```

4. Stop with `ctrl+c`.

If required config is missing, startup fails fast.

## Configuration

Required environment variables:

- `TELEGRAM_BOT_TOKEN`
- `ALLOWED_TELEGRAM_CHAT_IDS`
- `ANTHROPIC_API_KEY`

Optional environment variables:

- `ANTHROPIC_MODEL` (`opus`, `sonnet`, `haiku`; default `sonnet`)
- `ANTHROPIC_MAX_TOKENS` (default `1024`, must be greater than `0`)
- `WEB_SEARCH_API_KEY` (enables live `web_search`)

### Telegram chat ID allowlist

Set `ALLOWED_TELEGRAM_CHAT_IDS` to a comma-separated list of Telegram chat IDs allowed to talk to the bot:

```bash
ALLOWED_TELEGRAM_CHAT_IDS=<chat_id_1>,<chat_id_2>
```

To find your chat ID:

1. Start the bot and send it a message.
2. Run:

```bash
curl -s "https://api.telegram.org/bot<token>/getUpdates"
```

3. Copy `message.chat.id` from the response.

### Optional web search

To enable the `web_search` tool, set a Brave Search API key:

```bash
WEB_SEARCH_API_KEY=<your-brave-api-key>
```

Notes:

- `web_search` currently uses a fixed code-level result limit (`5`).
- The tool is still advertised to Anthropic when no key is set; in that case calls fail with a configuration error.

## Development

Build:

```bash
swift build
```

Run:

```bash
swift run
```

Run all root tests:

```bash
swift test
```

Run tests for a local package:

```bash
swift test --package-path TelegramClient
```

Run in Docker (production-like):

```bash
docker compose up app
```

Architecture details: [`.docs/architecture.md`](.docs/architecture.md)

## Troubleshooting

### `Address already in use` (`errno: 48`)

If `swift run` shows:

```text
[ WARNING ] bind(descriptor:ptr:bytes:): Address already in use) (errno: 48)
```

Another process is already listening on the configured port (default `8080`).

Find the process:

```bash
lsof -nP -iTCP:8080 -sTCP:LISTEN
```

Stop it:

```bash
kill <PID>
```

If it is still present, inspect state:

```bash
ps -p <PID> -o pid=,stat=,command=
```

If state is `T` (stopped), force kill:

```bash
kill -9 <PID>
```

Or run the app on another port:

```bash
PORT=8081 swift run
```

## Dependencies

- [SwiftAnthropic](https://github.com/jamesrochabrun/SwiftAnthropic)
- [Vapor](https://github.com/vapor/vapor)
- [SwiftNIO](https://github.com/apple/swift-nio)
