import Foundation
import UIKit

struct HGStoredRecordDraft {
    let draft: HGRecordDraft
    let images: [UIImage]
}

struct HGRecordDraftStore {
    private let fileManager: FileManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func save(draft: HGRecordDraft, images: [UIImage]) throws {
        guard !images.isEmpty else { throw HGRecordDraftStoreError.photoRequired }

        try clear()
        try fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: photosDirectory, withIntermediateDirectories: true)

        let photoFileNames = try images.enumerated().map { index, image in
            guard let data = image.jpegData(compressionQuality: 0.85) else {
                throw HGRecordDraftStoreError.photoEncoding
            }

            let fileName = "photo-\(index + 1).jpg"
            try data.write(to: photosDirectory.appending(path: fileName), options: .atomic)
            return fileName
        }

        let storedDraft = StoredDraft(draft: draft, photoFileNames: photoFileNames)
        let data = try encoder.encode(storedDraft)
        try data.write(to: draftFileURL, options: .atomic)
    }

    func load() throws -> HGStoredRecordDraft? {
        guard fileManager.fileExists(atPath: draftFileURL.path) else { return nil }

        let data = try Data(contentsOf: draftFileURL)
        let storedDraft = try decoder.decode(StoredDraft.self, from: data)
        let images = storedDraft.photoFileNames.compactMap { fileName in
            UIImage(contentsOfFile: photosDirectory.appending(path: fileName).path)
        }

        guard !images.isEmpty else {
            throw HGRecordDraftStoreError.unavailablePhotos
        }

        return HGStoredRecordDraft(draft: storedDraft.draft, images: images)
    }

    func clear() throws {
        guard fileManager.fileExists(atPath: storageDirectory.path) else { return }
        try fileManager.removeItem(at: storageDirectory)
    }

    private var storageDirectory: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "HeatGuardTemporaryRecord")
    }

    private var photosDirectory: URL {
        storageDirectory.appending(path: "photos")
    }

    private var draftFileURL: URL {
        storageDirectory.appending(path: "draft.json")
    }
}

private struct StoredDraft: Codable {
    let draft: HGRecordDraft
    let photoFileNames: [String]
}

enum HGRecordDraftStoreError: LocalizedError {
    case photoRequired
    case photoEncoding
    case unavailablePhotos

    var errorDescription: String? {
        switch self {
        case .photoRequired:
            return "임시저장할 사진을 선택해주세요."
        case .photoEncoding:
            return "선택한 사진을 임시저장하지 못했습니다."
        case .unavailablePhotos:
            return "임시저장한 사진을 불러오지 못했습니다."
        }
    }
}
