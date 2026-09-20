import Foundation

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
        requiresAuthentication: Bool = false
    ) async throws -> Response {
        let baseURL = try HGAPIConfiguration.baseURL()
        let url = baseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(requestBody)

        if requiresAuthentication, let token = try tokenStore.load() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HGAPIError.invalidResponse
        }

        let decoder = JSONDecoder()
        let envelope = try decoder.decode(HGAPIEnvelope<Response>.self, from: data)

        guard (200 ... 299).contains(httpResponse.statusCode), envelope.success, let payload = envelope.data else {
            throw HGAPIError.server(
                message: envelope.error?.message ?? "요청을 처리하지 못했습니다.",
                statusCode: httpResponse.statusCode
            )
        }

        return payload
    }
}

struct HGAPIEnvelope<Payload: Decodable>: Decodable {
    let success: Bool
    let data: Payload?
    let error: HGAPIErrorDetail?
}

struct HGAPIErrorDetail: Decodable {
    let code: String
    let message: String
}

enum HGAPIError: LocalizedError {
    case configuration(String)
    case invalidResponse
    case server(message: String, statusCode: Int)

    var errorDescription: String? {
        switch self {
        case let .configuration(message), let .server(message, _):
            return message
        case .invalidResponse:
            return "서버 응답을 처리하지 못했습니다."
        }
    }
}
