import Vapor
import Foundation
import AnthropicClient
import SessionStore
import TelegramClient
import TelegramBotService
import AppLifecycleHandler

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    
    await DotEnvFile.load(for: app.environment, fileio: app.fileio, logger: app.logger)
    
    app.sessionStore = try sessionStore(app)
    app.telegramClient = telegramClient(app)
    app.anthropicClient = try anthropicClient(app)
    app.telegramBotService = telegramBotService(app)
    app.lifecycle.use(appLifecycleHandler(app))
    
    // register routes
    try routes(app)
}

private func sessionStore(
    _ app: Application,
) throws -> SessionStore {
    try .live(
        baseDirectoryURL: URL(
            fileURLWithPath: app.directory.workingDirectory,
            isDirectory: true
        )
    )
}

private func telegramClient(
    _ app: Application,
) -> TelegramClient {
    guard let botToken = Environment.get("TELEGRAM_BOT_TOKEN"), !botToken.isEmpty else {
        fatalError("Missing TELEGRAM_BOT_TOKEN. Configure it in the environment before starting the app.")
    }
    
    return .live(client: app.client, botToken: botToken)
}

private func anthropicClient(
    _ app: Application,
) throws -> AnthropicClient {
    guard
        let anthropicAPIKey = Environment.get("ANTHROPIC_API_KEY"),
        !anthropicAPIKey.isEmpty
    else {
        fatalError("Missing ANTHROPIC_API_KEY. Configure it in the environment before starting the app.")
    }
    
    let anthropicModel: AnthropicModel
    if let modelValue = Environment.get("ANTHROPIC_MODEL"), !modelValue.isEmpty {
        guard let parsedModel = AnthropicModel(environmentValue: modelValue)
        else {
            fatalError("Invalid ANTHROPIC_MODEL '\(modelValue)'. Expected one of: opus, sonnet, haiku.")
        }
        anthropicModel = parsedModel
    } else {
        anthropicModel = .sonnet
    }
    
    let anthropicMaxTokens = Environment.get("ANTHROPIC_MAX_TOKENS")
        .flatMap(Int.init)
    ?? 1024
    guard anthropicMaxTokens > 0 else {
        fatalError("ANTHROPIC_MAX_TOKENS must be greater than zero.")
    }

    let anthropicClient = AnthropicClient.live(
        apiKey: anthropicAPIKey,
        model: anthropicModel,
        maxTokens: anthropicMaxTokens
    )
    try anthropicClient.ensureSystemPromptFileExists("SOUL.md")
    return anthropicClient
}

private func telegramBotService(
    _ app: Application
) -> TelegramBotService {
    return .live(
        anthropicClient: app.anthropicClient,
        telegramClient: app.telegramClient,
        sessionStore: app.sessionStore
    )
}

private func appLifecycleHandler(
    _ app: Application,
) -> AppLifecycleHandler {
    guard let rawAllowedTelegramChatIDs = Environment.get("ALLOWED_TELEGRAM_CHAT_IDS")
    else {
        fatalError(
            """
            Missing ALLOWED_TELEGRAM_CHAT_IDS.
            Set it to a comma-separated list of Telegram chat IDs, for example:
            ALLOWED_TELEGRAM_CHAT_IDS=123456789,-100987654321
            You can retrieve IDs by messaging your bot and running:
            curl -s "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getUpdates?limit=20"
            """
        )
    }
    
    return AppLifecycleHandler(
        getUpdates: app.telegramClient.getUpdates,
        handleIncomingText: app.telegramBotService.handleIncomingText,
        rawAllowedTelegramChatIDs: rawAllowedTelegramChatIDs,
        loadLastProcessedUpdateID: app.sessionStore.loadLastProcessedUpdateID,
        saveLastProcessedUpdateID: app.sessionStore.saveLastProcessedUpdateID,
        flushSessions: app.sessionStore.flush,
        logger: app.logger,
        pollTimeoutSeconds: 30
    )
}
