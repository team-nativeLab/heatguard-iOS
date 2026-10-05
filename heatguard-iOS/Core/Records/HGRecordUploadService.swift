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

        let uploadResponse: HGUploadURLResponse = try await client.send(
            HGUploadURLRequest(
                files: photos.enumerated().map {
                    HGUploadFileRequest(photo: $0.element, index: $0.offset)
                }
            ),
            method: "POST",
            path: HGAPIPath.teamUploads,
            requiresAuthentication: true
        )
        guard uploadResponse.uploads.count == photos.count else {
            throw HGRecordUploadError.uploadPreparation
        }

        try await upload(photos, to: uploadResponse.uploads)

        let response: HGRecordSaveResponse = try await client.send(
            HGRecordSaveRequest(
                type: draft.type.rawValue,
                photoKeys: uploadResponse.uploads.map(\.objectKey),
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

        return HGRecordSaveResult(
            recordID: response.recordID,
            draft: draft,
            photoCount: photos.count,
            savedAt: .now
        )
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

    private func upload(_ photos: [HGUploadPhoto], to destinations: [HGUploadDestination]) async throws {
        for (photo, destination) in zip(photos, destinations) {
            guard let url = URL(string: destination.uploadURL) else {
                throw HGRecordUploadError.uploadPreparation
            }
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue(photo.contentType, forHTTPHeaderField: "Content-Type")

            let (_, response) = try await session.upload(for: request, from: photo.data)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw HGRecordUploadError.uploadFailed(statusCode: nil)
            }
            guard (200 ... 299).contains(httpResponse.statusCode) else {
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
    let photoCount: Int
    let savedAt: Date
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
    let slot: Int
    let contentType: String
    let size: Int

    init(photo: HGUploadPhoto, index: Int) {
        slot = index + 1
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

    enum CodingKeys: String, CodingKey {
        case objectKey
        case uploadURL = "uploadUrl"
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
        self.data = data
    }
}

enum HGRecordUploadError: LocalizedError {
    case teamUnavailable
    case photoCount
    case photoEncoding
    case uploadPreparation
    case uploadFailed(statusCode: Int?)

    var errorDescription: String? {
        switch self {
        case .teamUnavailable: "기록할 팀 정보를 찾지 못했습니다."
        case .photoCount: "사진은 1~2장 선택해주세요."
        case .photoEncoding: "선택한 사진을 처리하지 못했습니다."
        case .uploadPreparation: "사진 업로드를 준비하지 못했습니다."
        case .uploadFailed: "사진 업로드에 실패했습니다."
        }
    }

    var diagnosticCode: String {
        switch self {
        case .teamUnavailable: "TEAM_UNAVAILABLE"
        case .photoCount: "PHOTO_COUNT"
        case .photoEncoding: "PHOTO_ENCODING"
        case .uploadPreparation: "UPLOAD_PREPARATION"
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
