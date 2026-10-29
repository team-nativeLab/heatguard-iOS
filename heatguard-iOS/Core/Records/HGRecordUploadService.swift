import Foundation
import UIKit

struct HGRecordUploadService {
    private let client: HGAPIClient
    private let session: URLSession

    init(
        client: HGAPIClient = HGAPIClient(),
        session: URLSession = .shared
    ) {
        self.client = client
        self.session = session
    }

    func save(_ draft: HGRecordDraft, images: [UIImage]) async throws -> HGRecordSaveResult {
        let photos = try images.map(HGUploadPhoto.init)
        guard (1 ... 2).contains(photos.count) else {
            throw HGRecordUploadError.photoCount
        }

        let destinations = try await prepareAndUpload(photos)

        let response: HGRecordSaveResponse = try await client.send(
            HGRecordSaveRequest(
                type: draft.type.rawValue,
                photoKeys: destinations.map(\.objectKey),
                memo: draft.memo.nilIfEmpty,
                measuredAt: ISO8601DateFormatter.heatGuard.string(from: draft.measuredAt),
                temperature: draft.temperature,
                humidity: draft.humidity,
                restStartedAt: draft.restStartedAt.map(Self.restTimestamp),
                restEndedAt: draft.restEndedAt.map(Self.restTimestamp),
                restMinutes: draft.restMinutes,
                teamName: draft.teamName,
                workplace: draft.workplace,
                siteName: draft.siteName
            ),
            method: "POST",
            path: HGAPIPath.teamRecords,
            requiresAuthentication: true
        )

        let photoVerification: HGRecordPhotoVerification
        do {
            let detail = try await HGRecordHistoryService(client: client).fetchDetail(id: response.recordID)
            photoVerification = .checked(photoURLCount: detail.photoURLs.count)
        } catch {
            // The record is already saved. Keep it as a partial success so retrying
            // cannot create a duplicate record just because verification failed.
            photoVerification = .unavailable(diagnosticCode: Self.diagnosticCode(for: error))
        }

        return HGRecordSaveResult(
            recordID: response.recordID,
            draft: draft,
            expectedPhotoCount: photos.count,
            photoVerification: photoVerification,
            savedAt: .now
        )
    }

    static func validatePhotoSize(_ byteCount: Int) throws {
        guard (1 ... 5 * 1_024 * 1_024).contains(byteCount) else {
            throw HGRecordUploadError.photoTooLarge
        }
    }

    private static func diagnosticCode(for error: Error) -> String {
        if let apiError = error as? HGAPIError {
            return apiError.diagnosticCode
        }
        if let urlError = error as? URLError {
            return "URL_ERROR_\(urlError.code.rawValue)"
        }
        return String(describing: type(of: error))
    }

    private static func restTimestamp(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        components.second = 0
        let minutePrecisionDate = calendar.date(from: components) ?? date
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: minutePrecisionDate)
    }

    private func prepareAndUpload(_ photos: [HGUploadPhoto]) async throws -> [HGUploadDestination] {
        // Renew the entire batch once so record creation never mixes old and new keys.
        for attempt in 0 ... 1 {
            try Task.checkCancellation()
            let response: HGUploadURLResponse = try await client.send(
                HGUploadURLRequest(files: photos.map(HGUploadFileRequest.init)),
                method: "POST",
                path: HGAPIPath.teamUploads,
                requiresAuthentication: true
            )
            guard response.uploads.count == photos.count else {
                throw HGRecordUploadError.uploadPreparation
            }
            do {
                try await upload(photos, to: response.uploads)
                return response.uploads
            } catch HGRecordUploadError.uploadExpired where attempt == 0 {
                continue
            }
        }
        throw HGRecordUploadError.uploadExpired
    }

    private func upload(_ photos: [HGUploadPhoto], to destinations: [HGUploadDestination]) async throws {
        for (photo, destination) in zip(photos, destinations) {
            guard let expiresAt = destination.expiresAt.hgISO8601Date else {
                throw HGRecordUploadError.uploadPreparation
            }
            guard expiresAt > .now else { throw HGRecordUploadError.uploadExpired }
            guard let url = URL(string: destination.uploadURL), url.scheme?.lowercased() == "https" else {
                throw HGRecordUploadError.uploadPreparation
            }
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            guard let requiredHeaders = destination.requiredHeaders else {
                throw HGRecordUploadError.requiredHeadersMissing
            }
            for (name, value) in requiredHeaders {
                request.setValue(value, forHTTPHeaderField: name)
            }

            let (_, response) = try await session.upload(for: request, from: photo.data)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw HGRecordUploadError.uploadFailed(statusCode: nil)
            }
            guard (200 ... 299).contains(httpResponse.statusCode) else {
                if httpResponse.statusCode == 403, expiresAt <= .now {
                    throw HGRecordUploadError.uploadExpired
                }
                throw HGRecordUploadError.uploadFailed(statusCode: httpResponse.statusCode)
            }
        }
    }
}

struct HGRecordDraft: Hashable, Codable {
    let type: HGRecordType
    let memo: String
    let measuredAt: Date
    let temperature: Double?
    let humidity: Double?
    let restStartedAt: Date?
    let restEndedAt: Date?
    let restMinutes: Int?
    let teamName: String?
    let workplace: String?
    let siteName: String?

    init(
        type: HGRecordType,
        memo: String,
        measuredAt: Date = .now,
        temperature: Double? = nil,
        humidity: Double? = nil,
        restStartedAt: Date? = nil,
        restEndedAt: Date? = nil,
        restMinutes: Int? = nil,
        teamName: String? = nil,
        workplace: String? = nil,
        siteName: String? = nil
    ) {
        self.type = type
        self.memo = memo
        self.measuredAt = measuredAt
        self.temperature = temperature
        self.humidity = humidity
        self.restStartedAt = restStartedAt
        self.restEndedAt = restEndedAt
        self.restMinutes = restMinutes
        self.teamName = teamName
        self.workplace = workplace
        self.siteName = siteName
    }
}

struct HGRecordSaveResult: Hashable {
    let recordID: String
    let draft: HGRecordDraft
    let expectedPhotoCount: Int
    let photoVerification: HGRecordPhotoVerification
    let savedAt: Date
}

enum HGRecordPhotoVerification: Hashable {
    case checked(photoURLCount: Int)
    case unavailable(diagnosticCode: String)
}

enum HGRecordType: String, Hashable, Codable {
    case thermometer = "THERMOMETER"
    case work = "WORK"
    case rest = "REST"
}

extension HGRecordType {
    var savedRecordTitle: String {
        switch self {
        case .thermometer: "온도계 기록"
        case .work: "작업 사진"
        case .rest: "휴식 사진"
        }
    }
}

private struct HGUploadURLRequest: Encodable {
    let files: [HGUploadFileRequest]
}

private struct HGUploadFileRequest: Encodable {
    let contentType: String
    let size: Int

    init(photo: HGUploadPhoto) {
        contentType = photo.contentType
        size = photo.data.count
    }
}

private struct HGUploadURLResponse: Decodable {
    let uploads: [HGUploadDestination]
}

private struct HGUploadDestination: Decodable {
    let objectKey: String
    let uploadURL: String
    let expiresAt: String
    let requiredHeaders: [String: String]?

    enum CodingKeys: String, CodingKey {
        case objectKey
        case expiresAt
        case uploadURL = "uploadUrl"
        case requiredHeaders
    }
}

private struct HGRecordSaveRequest: Encodable {
    let type: String
    let photoKeys: [String]
    let memo: String?
    let measuredAt: String
    let temperature: Double?
    let humidity: Double?
    let restStartedAt: String?
    let restEndedAt: String?
    let restMinutes: Int?
    let teamName: String?
    let workplace: String?
    let siteName: String?
}

private struct HGRecordSaveResponse: Decodable {
    let recordID: String

    enum CodingKeys: String, CodingKey {
        case recordID = "recordId"
    }
}

private struct HGUploadPhoto {
    let data: Data
    let contentType = "image/jpeg"

    init(image: UIImage) throws {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw HGRecordUploadError.photoEncoding
        }
        try HGRecordUploadService.validatePhotoSize(data.count)
        self.data = data
    }
}

enum HGRecordUploadError: LocalizedError {
    case teamUnavailable
    case photoCount
    case photoEncoding
    case photoTooLarge
    case uploadExpired
    case uploadPreparation
    case requiredHeadersMissing
    case uploadFailed(statusCode: Int?)

    var errorDescription: String? {
        switch self {
        case .teamUnavailable: "기록할 팀 정보를 찾지 못했습니다."
        case .photoCount: "사진은 1~2장 선택해주세요."
        case .photoEncoding: "선택한 사진을 처리하지 못했습니다."
        case .photoTooLarge: "사진은 장당 5MiB 이하로 선택해주세요."
        case .uploadExpired: "사진 업로드 시간이 만료됐습니다. 다시 저장해주세요."
        case .uploadPreparation: "사진 업로드를 준비하지 못했습니다."
        case .requiredHeadersMissing: "업로드 서버가 필요한 사진 전송 정보를 주지 않았습니다."
        case .uploadFailed: "사진 업로드에 실패했습니다."
        }
    }

    var diagnosticCode: String {
        switch self {
        case .teamUnavailable: "TEAM_UNAVAILABLE"
        case .photoCount: "PHOTO_COUNT"
        case .photoEncoding: "PHOTO_ENCODING"
        case .photoTooLarge: "PHOTO_TOO_LARGE"
        case .uploadExpired: "UPLOAD_EXPIRED"
        case .uploadPreparation: "UPLOAD_PREPARATION"
        case .requiredHeadersMissing: "UPLOAD_HEADERS_MISSING"
        case let .uploadFailed(statusCode):
            statusCode.map { "S3_UPLOAD_HTTP_\($0)" } ?? "S3_UPLOAD_FAILED"
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
