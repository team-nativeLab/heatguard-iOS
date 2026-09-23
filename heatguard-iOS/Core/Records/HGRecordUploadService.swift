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

    func save(_ draft: HGRecordDraft, images: [UIImage]) async throws {
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
            path: "/api/v1/team/uploads",
            requiresAuthentication: true
        )
        guard uploadResponse.uploads.count == photos.count else {
            throw HGRecordUploadError.uploadPreparation
        }

        try await upload(photos, to: uploadResponse.uploads)

        let _: HGRecordSaveResponse = try await client.send(
            HGRecordSaveRequest(
                type: draft.type.rawValue,
                photoKeys: uploadResponse.uploads.map(\.objectKey),
                memo: draft.memo.nilIfEmpty,
                measuredAt: ISO8601DateFormatter().string(from: draft.measuredAt),
                temperature: draft.temperature,
                humidity: draft.humidity
            ),
            method: "POST",
            path: "/api/v1/team/records",
            requiresAuthentication: true
        )
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
            guard let httpResponse = response as? HTTPURLResponse, (200 ... 299).contains(httpResponse.statusCode) else {
                throw HGRecordUploadError.uploadFailed
            }
        }
    }
}

struct HGRecordDraft: Hashable {
    let type: HGRecordType
    let memo: String
    let measuredAt: Date
    let temperature: Double?
    let humidity: Double?

    init(type: HGRecordType, memo: String, measuredAt: Date = .now, temperature: Double? = nil, humidity: Double? = nil) {
        self.type = type
        self.memo = memo
        self.measuredAt = measuredAt
        self.temperature = temperature
        self.humidity = humidity
    }
}

enum HGRecordType: String, Hashable, Decodable {
    case thermometer = "THERMOMETER"
    case work = "WORK"
    case rest = "REST"
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
    case uploadFailed

    var errorDescription: String? {
        switch self {
        case .teamUnavailable: "기록할 팀 정보를 찾지 못했습니다."
        case .photoCount: "사진은 1~2장 선택해주세요."
        case .photoEncoding: "선택한 사진을 처리하지 못했습니다."
        case .uploadPreparation: "사진 업로드를 준비하지 못했습니다."
        case .uploadFailed: "사진 업로드에 실패했습니다."
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
