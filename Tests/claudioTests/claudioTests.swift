@testable import claudio
import VaporTesting
import Testing

@Suite("App Tests")
struct claudioTests {
    @Test("Unknown route returns 404")
    func unknownRouteReturnsNotFound() async throws {
        try await withApp(configure: { app in
            try routes(app)
        }, { app in
            try await app.testing().test(.GET, "hello", afterResponse: { res async in
                #expect(res.status == .notFound)
            })
        })
    }
}
