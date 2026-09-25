import Foundation

struct HGErrorPresentation: Hashable {
    let title: String
    let message: String
    let diagnosticCode: String

    init(error: Error) {
        if let apiError = error as? HGAPIError {
            title = apiError.failureTitle
            message = apiError.localizedDescription
            diagnosticCode = apiError.diagnosticCode
            return
        }

        if let uploadError = error as? HGRecordUploadError {
            title = "사진 업로드 오류"
            message = uploadError.localizedDescription
            diagnosticCode = uploadError.diagnosticCode
            return
        }

        if let urlError = error as? URLError {
            title = "네트워크 연결 오류"
            message = urlError.localizedDescription
            diagnosticCode = "URL_ERROR_\(urlError.code.rawValue)"
            return
        }

        title = "처리 중 오류가 발생했습니다"
        message = error.localizedDescription
        diagnosticCode = String(describing: type(of: error))
    }

    var alertMessage: String {
        "\(message)\n\n오류 코드: \(diagnosticCode)"
    }
}
