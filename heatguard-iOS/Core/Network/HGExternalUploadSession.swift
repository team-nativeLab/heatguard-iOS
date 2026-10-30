import Foundation

/// Isolated session for presigned uploads. It mirrors the Android external
/// upload client: no app cookies/credentials and no redirect that could alter
/// a signed URL or move the request to a different host.
enum HGExternalUploadSession {
    static let shared: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        return URLSession(
            configuration: configuration,
            delegate: HGExternalUploadRedirectDelegate(),
            delegateQueue: nil
        )
    }()
}

final class HGExternalUploadRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
