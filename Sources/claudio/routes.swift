import Vapor

func routes(_ app: Application) throws {
    try app.register(collection: TelegramWebhookController())

    app.get { req async in
        "It works!"
    }

    app.get("hello") { req async -> String in
        "Hello, world!"
    }
}
