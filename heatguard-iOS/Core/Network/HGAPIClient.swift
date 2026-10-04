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
        let (data, httpResponse) = try await authenticatedData(for: request, requiresAuthentication: requiresAuthentication)
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

        let (data, httpResponse) = try await authenticatedData(for: request, requiresAuthentication: requiresAuthentication)

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
        } catch {
            throw HGAPIError.responseDecoding
        }
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

    private func authenticatedData(
        for request: URLRequest,
        requiresAuthentication: Bool
    ) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HGAPIError.invalidResponse
        }
        guard requiresAuthentication, httpResponse.statusCode == 401,
              let staleToken = try? tokenStore.load(),
              await HGAuthSessionRecovery.shared.recover(
                staleToken: staleToken,
                session: session,
                tokenStore: tokenStore
              ),
              let newToken = try? tokenStore.load(), newToken != staleToken else {
            return (data, httpResponse)
        }

        var retryRequest = request
        retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
        let (retryData, retryResponse) = try await session.data(for: retryRequest)
        guard let retryHTTPResponse = retryResponse as? HTTPURLResponse else {
            throw HGAPIError.invalidResponse
        }
        return (retryData, retryHTTPResponse)
    }
}

@MainActor
private final class HGAuthSessionRecovery {
    static let shared = HGAuthSessionRecovery()

    private var recoveryTask: Task<String?, Never>?

    func recover(
        staleToken: String,
        session: URLSession,
        tokenStore: HGAuthTokenStore
    ) async -> Bool {
        if let currentToken = try? tokenStore.load(), currentToken != staleToken {
            return true
        }
        if let recoveryTask {
            return await recoveryTask.value != nil
        }

        let task = Task { [weak self] () -> String? in
            guard let self else { return nil }
            return await self.login(session: session, tokenStore: tokenStore)
        }
        recoveryTask = task
        let newToken = await task.value
        recoveryTask = nil
        return newToken != nil
    }

    private func login(session: URLSession, tokenStore: HGAuthTokenStore) async -> String? {
        guard let credentials = try? HGAuthCredentialStore.shared.load(),
              let baseURL = try? HGAPIConfiguration.baseURL() else { return nil }
        var request = URLRequest(url: baseURL.appending(path: HGAPIPath.teamLogin))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(credentials)

        guard let (data, response) = try? await session.data(for: request),
              let httpResponse = response as? HTTPURLResponse else { return nil }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                try? HGAuthCredentialStore.shared.clear()
                try? tokenStore.clear()
            }
            return nil
        }
        guard
              let envelope = try? JSONDecoder().decode(HGAPIEnvelope<HGRecoveredLoginResponse>.self, from: data),
              envelope.success,
              let accessToken = envelope.data?.accessToken,
              (try? tokenStore.save(accessToken)) != nil else { return nil }
        return accessToken
    }
}

private struct HGRecoveredLoginResponse: Decodable {
    let accessToken: String

    private enum CodingKeys: String, CodingKey {
        case accessToken
        case token
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let accessToken = try container.decodeIfPresent(String.self, forKey: .accessToken) {
            self.accessToken = accessToken
        } else if let token = try container.decodeIfPresent(String.self, forKey: .token) {
            self.accessToken = token
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.accessToken,
                .init(codingPath: decoder.codingPath, debugDescription: "로그인 토큰이 없습니다.")
            )
        }
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
    case responseDecoding
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
        case .server(_, _, "INVALID_CREDENTIALS"):
            return "로그인 정보를 확인해주세요"
        case .server(_, _, "ACCOUNT_DISABLED"):
            return "비활성화된 계정입니다"
        case let .server(_, statusCode, _) where statusCode == 401:
            return "인증이 만료됐습니다"
        case let .server(_, statusCode, _) where statusCode == 403:
            return "접근 권한이 없습니다"
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
        case .responseDecoding:
            return "RESPONSE_DECODING"
        case let .server(_, statusCode, serverCode):
            guard let serverCode, !serverCode.isEmpty else {
                return "HTTP \(statusCode)"
            }
            return "HTTP \(statusCode) · \(serverCode)"
        }
    }
}
