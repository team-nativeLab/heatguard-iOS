import SwiftUI

struct NotificationDetailView: View {
    let notification: HGNotification
    private let loadCurrentCall: () async throws -> HGEmergencyCall?
    @State private var currentCall: HGEmergencyCall?
    @State private var isLoading = false
    @State private var error: HGErrorPresentation?

    init(
        notification: HGNotification,
        loadCurrentCall: @escaping () async throws -> HGEmergencyCall? = {
            try await HGEmergencyCallService().fetchCurrentCall()
        }
    ) {
        self.notification = notification
        self.loadCurrentCall = loadCurrentCall
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 14) {
                Text(notification.category.title)
                    .font(HGFont.medium(13))
                    .foregroundStyle(HGColor.primary)
                Text(notification.title)
                    .font(HGFont.bold(20, relativeTo: .title2))
                    .foregroundStyle(HGColor.primaryText)
                if let date = notification.createdAt.hgISO8601Date {
                    Text(date.formatted(date: .numeric, time: .shortened))
                        .font(HGFont.regular(13))
                        .foregroundStyle(HGColor.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 16))

            if notification.type == .emergencyAcknowledged {
                VStack(alignment: .leading, spacing: 12) {
                    Text("긴급 호출 상태")
                        .font(HGFont.semiBold(16))
                    if isLoading {
                        ProgressView("상태 확인 중...")
                    } else if let error {
                        Text(error.message)
                        Button("다시 시도") { Task { await load() } }
                    } else if let call = notification.relatedEmergencyCall(currentCall) {
                        Text(call.status == .acknowledged ? "관리자가 호출을 접수했어요" : "도움을 요청하고 있어요")
                    } else {
                        Text("이 알림에 해당하는 현재 호출 정보를 확인할 수 없어요.")
                    }
                }
                .font(HGFont.regular(14))
                .foregroundStyle(HGColor.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 16))
            } else if notification.destination == .detail {
                Text("알림 내용을 확인해주세요. 연결된 상세 정보는 제공되지 않았어요.")
                    .font(HGFont.regular(14))
                    .foregroundStyle(HGColor.secondaryText)
            }
        }
        .padding(24)
        .background(HGColor.appBackground)
        .navigationTitle("알림 상세")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @MainActor private func load() async {
        guard notification.type == .emergencyAcknowledged,
              let id = notification.resourceID, !id.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            currentCall = try await loadCurrentCall()
            error = nil
        } catch is CancellationError {
            return
        } catch {
            self.error = HGErrorPresentation(error: error)
        }
    }
}

#Preview {
    NavigationStack {
        NotificationDetailView(notification: HGNotification(
            notificationID: "preview", title: "현장관리자가 긴급호출을 접수했습니다.",
            resourceID: "call", createdAt: "2026-10-04T00:00:00Z",
            type: .emergencyAcknowledged, category: .emergency, read: true
        ), loadCurrentCall: { HGEmergencyCall(id: "call", status: .acknowledged) })
    }
}
