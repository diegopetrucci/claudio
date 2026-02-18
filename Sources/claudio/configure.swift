import Vapor

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    await DotEnvFile.load(for: app.environment, fileio: app.fileio, logger: app.logger)

    guard let botToken = Environment.get("TELEGRAM_BOT_TOKEN"), !botToken.isEmpty else {
        fatalError("Missing TELEGRAM_BOT_TOKEN. Configure it in the environment before starting the app.")
    }

    app.telegramClient = .live(client: app.client, botToken: botToken)

    if let secretToken = Environment.get("TELEGRAM_WEBHOOK_SECRET_TOKEN"), !secretToken.isEmpty {
        app.telegramWebhookSecretToken = secretToken
    }

    // register routes
    try routes(app)
}
