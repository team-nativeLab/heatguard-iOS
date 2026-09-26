import UIKit

enum HGPhotoRecordSaveOutcome {
    case photoRequired
    case success(HGRecordSaveResult)
    case failure(HGRecordSaveFailure)
}

enum HGPhotoRecordSaveAction {
    static func perform(
        draft: HGRecordDraft,
        images: [UIImage]
    ) async -> HGPhotoRecordSaveOutcome {
        guard !images.isEmpty else {
            return .photoRequired
        }

        do {
            return .success(try await HGRecordUploadService().save(draft, images: images))
        } catch {
            return .failure(HGRecordSaveFailure(error: error))
        }
    }
}
