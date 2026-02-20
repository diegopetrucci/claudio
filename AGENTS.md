# Repository Guidelines

## Project Structure & Module Organization
- Root app code lives in `Sources/claudio` (`entrypoint.swift`, `configure.swift`, `routes.swift`).
- Root tests live in `Tests/claudioTests`.
- Shared functionality is split into local Swift packages, each with its own `Sources/` and `Tests/`:
  - `AnthropicClient`
  - `TelegramClient`
  - `TelegramBotService`
  - `AppLifecycleHandler`
- Static/public assets are in `Public/`.
- Environment templates are in `.env.example`.

## Build, Test, and Development Commands
- `swift build`: Build the root executable and linked local packages.
- `swift run`: Start the Vapor app locally.
- `swift test`: Run all root tests.
- `swift test --package-path TelegramClient` (or another package path): Run tests for one local package.
- `docker compose up app`: Run the app in a production-like container on port `8080`.

## Coding Style & Naming Conventions
- Follow `.editorConfig`: 4 spaces, no tabs, trim trailing whitespace, final newline.
- Follow `.swift-format` preferences (4-space indentation, compact blank lines, line breaks before control flow keywords/arguments).
- Use Swift naming defaults:
  - Types/protocols: `UpperCamelCase`
  - Functions/properties/variables: `lowerCamelCase`
- Keep module boundaries clear: API clients in their package, orchestration in `TelegramBotService`, lifecycle wiring in `AppLifecycleHandler`.

## Testing Guidelines
- Use Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect`).
- Test names should describe behavior, e.g. `handleIncomingTextAnthropicFailure`.
- Add or update tests with every behavior change; include regression tests for bug fixes.
- Prefer package-local tests when changing a package, then run root tests before opening a PR.

## Commit & Pull Request Guidelines
- Match existing history style: short, imperative, lowercase subjects (e.g., `move telegram client to package`).
- Keep commits scoped to one logical change.
- PRs should include:
  - What changed and why
  - Affected package(s)/module(s)
  - Test evidence (commands run and results)
  - Config changes (new/changed env vars)

## Security & Configuration Tips
- Do not commit real secrets. Use `.env` locally and keep `.env.example` updated.
- Required vars include `TELEGRAM_BOT_TOKEN` and `ANTHROPIC_API_KEY`; startup fails fast when missing.

## Misc
- This is a public repo, be extremely cautious about sharing any information that could be sensitive or personally identifiable.

## Agent notes
- Every time you learn something new, or how to do something in the codebase, if you make a mistake that the user corrects, if you find yourself running commands that are often wrong and have to tweak them: write all of this down in `.agents/notes.md`. This is a file just for you that your user won't read.
- If you're about to write to it, first check if what you're writing (the idea, not 1:1) is already present. If so, increment the counter in the prefix (eg from `[0]` to `[1]`). If it's completely new, prefix it with `[0]`. Once a comment hits [3], codify it into this AGENTS.md file in the `Misc` section.
