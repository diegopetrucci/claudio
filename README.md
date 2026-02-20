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

## Troubleshooting

### `Address already in use` (`errno: 48`)

If `swift run` shows:

```text
[ WARNING ] bind(descriptor:ptr:bytes:): Address already in use) (errno: 48)
```

the app built correctly, but another process is already listening on the configured port (default: `8080`).

Find what is listening:

```bash
lsof -nP -iTCP:8080 -sTCP:LISTEN
```

Stop the process (example):

```bash
kill <PID>
```

If the process is still listening after `kill <PID>`, check its state:

```bash
ps -p <PID> -o pid=,stat=,command=
```

If state is `T` (stopped), force kill it:

```bash
kill -9 <PID>
```

Or run on another port:

```bash
PORT=8081 swift run
```
