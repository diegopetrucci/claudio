import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol SearchToolHTTPSession: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: SearchToolHTTPSession {}
