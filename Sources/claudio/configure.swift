import Vapor
import AnthropicClient
import SessionStore
import TelegramClient
import TelegramBotService
import TelegramPollingLifecycleHandler

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    
    await DotEnvFile.load(for: app.environment, fileio: app.fileio, logger: app.logger)

    try configureSessionStore(app)
    
    configureTelegram(app)
    configureAnthropic(app)
    configureTelegramBotService(app)
    app.lifecycle.use(
        TelegramPollingLifecycleHandler(
            getUpdates: app.telegramClient.getUpdates,
            handleIncomingText: app.telegramBotService.handleIncomingText,
            logger: app.logger,
            pollTimeoutSeconds: 30
        )
    )
    
    // register routes
    try routes(app)
}

private func configureSessionStore(
    _ app: Application,
) throws {
    app.sessionStore = try .live(
        baseDirectoryURL: URL(
            fileURLWithPath: app.directory.workingDirectory,
            isDirectory: true
        )
    )
}

private func configureTelegram(
    _ app: Application,
) {
    guard let botToken = Environment.get("TELEGRAM_BOT_TOKEN"), !botToken.isEmpty else {
        fatalError("Missing TELEGRAM_BOT_TOKEN. Configure it in the environment before starting the app.")
    }
    
    app.telegramClient = .live(client: app.client, botToken: botToken)
}

private func configureAnthropic(
    _ app: Application,
) {
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
    
    let anthropicSystemPrompt = Environment.get("ANTHROPIC_SYSTEM_PROMPT")
        .flatMap { $0.isEmpty ? nil : $0 }
    app.anthropicClient = .live(
        apiKey: anthropicAPIKey,
        model: anthropicModel,
        maxTokens: anthropicMaxTokens,
        systemPrompt: anthropicSystemPrompt
    )
}

private func configureTelegramBotService(
    _ app: Application,
) {
    app.telegramBotService = .live(
        anthropicClient: app.anthropicClient,
        telegramClient: app.telegramClient,
        sessionStore: app.sessionStore
    )
}
