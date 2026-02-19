import Testing
@testable import SessionStore

@Suite("SessionStore Tests")
struct SessionStoreTests {
    @Test("module compiles")
    func moduleCompiles() {
        #expect(Bool(true))
    }
}
