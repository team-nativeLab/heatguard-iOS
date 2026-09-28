import Foundation
import Security

enum HGAPIConfiguration {
    static let baseURLKey = "HeatGuardAPIBaseURL"

    static func baseURL() throws -> URL {
        guard
            let rawValue = Bundle.main.object(forInfoDictionaryKey: baseURLKey) as? String,
            let url = URL(string: rawValue),
            url.scheme != nil,
            url.host != nil
        else {
            throw HGAPIError.configuration("서버 주소가 설정되지 않았습니다.")
        }

        return url
    }
}

struct HGAPIClient {
    private let session: URLSession
    private let tokenStore: HGAuthTokenStore

    init(
        session: URLSession = .shared,
        tokenStore: HGAuthTokenStore = .shared
    ) {
        self.session = session
        self.tokenStore = tokenStore
    }

    func send<Request: Encodable, Response: Decodable>(
        _ requestBody: Request,
        method: String,
        path: String,
        requiresAuthentication: Bool = false,
        headers: [String: String] = [:]
    ) async throws -> Response {
        let body = try JSONEncoder().encode(requestBody)
        return try await request(
            method: method,
            path: path,
            body: body,
            requiresAuthentication: requiresAuthentication,
            headers: headers
        )
    }

    func get<Response: Decodable>(
        path: String,
        requiresAuthentication: Bool = false,
        queryItems: [URLQueryItem] = []
    ) async throws -> Response {
        try await request(
            method: "GET",
            path: path,
            requiresAuthentication: requiresAuthentication,
            queryItems: queryItems
        )
    }

    func sendVoid(method: String, path: String, requiresAuthentication: Bool = false) async throws {
        try await sendVoid(method: method, path: path, body: nil, requiresAuthentication: requiresAuthentication)
    }

    func sendVoid<Request: Encodable>(_ requestBody: Request, method: String, path: String, requiresAuthentication: Bool = false) async throws {
        try await sendVoid(method: method, path: path, body: try JSONEncoder().encode(requestBody), requiresAuthentication: requiresAuthentication)
    }

    private func sendVoid(method: String, path: String, body: Data?, requiresAuthentication: Bool) async throws {
        let baseURL = try HGAPIConfiguration.baseURL()
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.httpBody = body
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        if requiresAuthentication {
            guard let token = try tokenStore.load() else { throw HGAPIError.authenticationRequired }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HGAPIError.invalidResponse
        }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw responseError(from: data, statusCode: httpResponse.statusCode)
        }
    }

    private func request<Response: Decodable>(
        method: String,
        path: String,
        body: Data? = nil,
        requiresAuthentication: Bool,
        headers: [String: String] = [:],
        queryItems: [URLQueryItem] = []
    ) async throws -> Response {
        let baseURL = try HGAPIConfiguration.baseURL()
        guard var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false) else {
            throw HGAPIError.configuration("서버 주소를 처리하지 못했습니다.")
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else {
            throw HGAPIError.configuration("서버 요청 주소를 만들지 못했습니다.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = body
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        if requiresAuthentication {
            guard let token = try tokenStore.load() else {
                throw HGAPIError.authenticationRequired
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HGAPIError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw responseError(from: data, statusCode: httpResponse.statusCode)
        }

        do {
            let envelope = try JSONDecoder().decode(HGAPIEnvelope<Response>.self, from: data)
            guard envelope.success, let payload = envelope.data else {
                throw HGAPIError.server(
                    message: envelope.error?.message ?? "요청을 처리하지 못했습니다.",
                    statusCode: httpResponse.statusCode,
                    serverCode: envelope.error?.code
                )
            }

            return payload
        } catch let error as HGAPIError {
            throw error
        } catch let error as DecodingError {
            throw HGAPIError.responseDecoding(codingPath: decodingPath(for: error))
        } catch {
            throw HGAPIError.responseDecoding(codingPath: nil)
        }
    }

    private func decodingPath(for error: DecodingError) -> String? {
        let codingPath: [any CodingKey]
        switch error {
        case let .typeMismatch(_, context), let .valueNotFound(_, context), let .keyNotFound(_, context), let .dataCorrupted(context):
            codingPath = context.codingPath
        @unknown default:
            return nil
        }

        let path = codingPath.map(\.stringValue).joined(separator: ".")
        return path.isEmpty ? nil : path
    }

    private func responseError(from data: Data, statusCode: Int) -> HGAPIError {
        let errorEnvelope = try? JSONDecoder().decode(HGAPIEnvelope<HGEmptyPayload>.self, from: data)
        let fallbackMessage = HTTPURLResponse.localizedString(forStatusCode: statusCode)

        return HGAPIError.server(
            message: errorEnvelope?.error?.message ?? fallbackMessage,
            statusCode: statusCode,
            serverCode: errorEnvelope?.error?.code
        )
    }
}

struct HGAPIEnvelope<Payload: Decodable>: Decodable {
    let success: Bool
    let data: Payload?
    let error: HGAPIErrorDetail?
}

struct HGAPIErrorDetail: Decodable {
    let code: String?
    let message: String?
}

private struct HGEmptyPayload: Decodable {}

enum HGAPIError: LocalizedError {
    case configuration(String)
    case keychain(message: String, status: OSStatus)
    case authenticationRequired
    case invalidResponse
    case responseDecoding(codingPath: String?)
    case server(message: String, statusCode: Int, serverCode: String?)

    var errorDescription: String? {
        switch self {
        case let .configuration(message), let .keychain(message, _), let .server(message, _, _):
            return message
        case .authenticationRequired:
            return "로그인이 필요합니다."
        case .invalidResponse:
            return "서버 응답을 처리하지 못했습니다."
        case .responseDecoding:
            return "서버 응답 형식을 처리하지 못했습니다."
        }
    }

    var failureTitle: String {
        switch self {
        case .authenticationRequired:
            return "로그인이 필요합니다"
        case let .server(_, statusCode, _) where statusCode == 401 || statusCode == 403:
            return "인증이 만료됐습니다"
        case .configuration:
            return "서버 설정 오류"
        case .keychain:
            return "인증 정보 오류"
        case .invalidResponse, .responseDecoding:
            return "서버 응답 오류"
        case .server:
            return "서버 요청 오류"
        }
    }

    var diagnosticCode: String {
        switch self {
        case .configuration:
            return "CONFIGURATION"
        case let .keychain(_, status):
            return "KEYCHAIN_\(status)"
        case .authenticationRequired:
            return "AUTH_REQUIRED"
        case .invalidResponse:
            return "INVALID_RESPONSE"
        case let .responseDecoding(codingPath):
            guard let codingPath else { return "RESPONSE_DECODING" }
            return "RESPONSE_DECODING · \(codingPath)"
        case let .server(_, statusCode, serverCode):
            guard let serverCode, !serverCode.isEmpty else {
                return "HTTP \(statusCode)"
            }
            return "HTTP \(statusCode) · \(serverCode)"
        }
    }
}
