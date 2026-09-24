import Foundation

struct HGRecordSaveFailure: Hashable {
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
            diagnosticCode = "URLError \(urlError.code.rawValue)"
            return
        }

        title = "기록 저장 오류"
        message = error.localizedDescription
        diagnosticCode = String(describing: type(of: error))
    }
}
