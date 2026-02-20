# claudio

A reimplementation of [OpenClaw](https://github.com/openclaw/openclaw) in Swift & Vapor.

Loosely based on the brilliant [You could've invented OpenClaw](https://gist.github.com/dabit3/bc60d3bea0b02927995cd9bf53c3db32) post.

## Getting Started

1. Fill in the required environment variables `cp .env.example .env`
2. Run the project `swift run`
3. Stop the execution via `control + c`

## Development

1. Build with `swift build`, or using Xcode
2. Run tests with `swift test`

## Session Persistence

- Sessions are persisted under `.sessions/` in the project working directory.
- One transcript file is maintained per Telegram chat (`<chatID>.jsonl`).
- Telegram polling cursor is persisted in `.sessions/polling_cursor.json` to avoid duplicate processing on restart.
- User and assistant messages are appended as they arrive.
- Session history is included in prompt generation for new replies.
