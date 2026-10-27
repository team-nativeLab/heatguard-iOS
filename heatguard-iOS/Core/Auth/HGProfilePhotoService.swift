import Foundation
import UIKit

struct HGProfilePhotoService {
    private let client: HGAPIClient
    private let session: URLSession

    init(client: HGAPIClient = HGAPIClient(), session: URLSession = .shared) {
        self.client = client
        self.session = session
    }

    func loadPhoto() async throws -> UIImage? {
        let response: HGProfilePhotoResponse = try await client.get(
            path: HGAPIPath.teamProfilePhoto,
            requiresAuthentication: true
        )
        guard let rawURL = response.photoURL else { return nil }
        guard let url = URL(string: rawURL), url.scheme?.lowercased() == "https" else {
            throw HGProfilePhotoError.invalidURL
        }

        let (data, urlResponse) = try await session.data(from: url)
        guard let httpResponse = urlResponse as? HTTPURLResponse,
              (200 ... 299).contains(httpResponse.statusCode),
              httpResponse.mimeType?.hasPrefix("image/") == true,
              let image = UIImage(data: data) else {
            throw HGProfilePhotoError.downloadFailed
        }
        return image
    }

    func uploadPhoto(_ image: UIImage) async throws {
        let data = try Self.jpegData(from: image)
        let upload: HGProfilePhotoUploadResponse = try await client.send(
            HGProfilePhotoUploadRequest(contentType: "image/jpeg", size: data.count),
            method: "POST",
            path: HGAPIPath.teamProfilePhotoUploads,
            requiresAuthentication: true
        )
        guard let url = URL(string: upload.uploadURL), url.scheme?.lowercased() == "https" else {
            throw HGProfilePhotoError.invalidURL
        }
        guard upload.requiredHeaders.contains(where: {
            $0.key.caseInsensitiveCompare("Content-Type") == .orderedSame
        }), let contentLength = upload.requiredHeaders.first(where: {
            $0.key.caseInsensitiveCompare("Content-Length") == .orderedSame
        })?.value, Int(contentLength) == data.count else {
            throw HGProfilePhotoError.invalidUploadContract
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        for (name, value) in upload.requiredHeaders {
            request.setValue(value, forHTTPHeaderField: name)
        }

        let response: URLResponse
        do {
            (_, response) = try await session.upload(for: request, from: data)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw HGProfilePhotoError.uploadFailed(statusCode: nil)
        }
        guard let httpResponse = response as? HTTPURLResponse,
              (200 ... 299).contains(httpResponse.statusCode) else {
            throw HGProfilePhotoError.uploadFailed(statusCode: (response as? HTTPURLResponse)?.statusCode)
        }

        let _: HGProfilePhotoResponse = try await client.send(
            HGProfilePhotoFinalizeRequest(uploadID: upload.uploadID),
            method: "PUT",
            path: HGAPIPath.teamProfilePhoto,
            requiresAuthentication: true
        )
    }

    func removePhoto() async throws {
        try await client.sendVoid(
            method: "DELETE",
            path: HGAPIPath.teamProfilePhoto,
            requiresAuthentication: true
        )
    }

    private static func jpegData(from image: UIImage) throws -> Data {
        let maximumDimension: CGFloat = 2_048
        let sourceSize = image.size
        guard sourceSize.width > 0, sourceSize.height > 0 else {
            throw HGProfilePhotoError.invalidImage
        }

        let scale = min(1, maximumDimension / max(sourceSize.width, sourceSize.height))
        let targetSize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let resizedImage = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: targetSize))
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        for quality in stride(from: 0.9, through: 0.4, by: -0.1) {
            if let data = resizedImage.jpegData(compressionQuality: quality), data.count <= 5 * 1_024 * 1_024 {
                return data
            }
        }
        throw HGProfilePhotoError.invalidImage
    }
}

private struct HGProfilePhotoUploadRequest: Encodable {
    let contentType: String
    let size: Int
}

private struct HGProfilePhotoFinalizeRequest: Encodable {
    let uploadID: String

    enum CodingKeys: String, CodingKey {
        case uploadID = "uploadId"
    }
}

private struct HGProfilePhotoUploadResponse: Decodable {
    let uploadID: String
    let uploadURL: String
    let requiredHeaders: [String: String]

    enum CodingKeys: String, CodingKey {
        case uploadID = "uploadId"
        case uploadURL = "uploadUrl"
        case requiredHeaders
    }
}

private struct HGProfilePhotoResponse: Decodable {
    let photoURL: String?

    enum CodingKeys: String, CodingKey {
        case photoURL = "photoUrl"
    }
}

private enum HGProfilePhotoError: LocalizedError {
    case invalidImage
    case invalidURL
    case invalidUploadContract
    case downloadFailed
    case uploadFailed(statusCode: Int?)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            "사진을 5MB 이하 JPEG로 변환하지 못했습니다."
        case .invalidURL:
            "프로필 사진 서버 주소가 올바르지 않습니다."
        case .invalidUploadContract:
            "서버 업로드 규격과 사진 크기가 일치하지 않습니다."
        case .downloadFailed:
            "프로필 사진을 불러오지 못했습니다."
        case .uploadFailed:
            "프로필 사진 업로드에 실패했습니다. 잠시 후 다시 시도해주세요."
        }
    }
}
