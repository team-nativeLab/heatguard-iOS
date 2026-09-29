import SwiftUI

struct NotificationsView: View {
    let onSelect: (HGNotification) -> Void
    let onUnreadCountChanged: (Int) -> Void

    @State private var category: HGNotificationCategory = .all
    @State private var notifications: [HGNotification] = []
    @State private var nextCursor: String?
    @State private var hasMore = false
    @State private var unreadCount = 0
    @State private var markingReadIDs: Set<String> = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var listRequestID = UUID()
    @State private var failedToLoadMore = false
    @State private var error: HGErrorPresentation?
    @State private var selectedNotice: String?

    init(onSelect: @escaping (HGNotification) -> Void = { _ in }, onUnreadCountChanged: @escaping (Int) -> Void = { _ in }) {
        self.onSelect = onSelect
        self.onUnreadCountChanged = onUnreadCountChanged
    }

    var body: some View {
        VStack(spacing: 0) {
            categoryPicker
                .padding(.horizontal, 24)
            if isLoading && notifications.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if notifications.isEmpty {
                ContentUnavailableView("알림이 없어요", systemImage: "bell", description: Text("새로운 기록과 답변이 도착하면 여기에 표시돼요."))
            } else {
                List {
                    ForEach(notifications) { notification in
                        Button { Task { await open(notification) } } label: {
                            NotificationRow(notification: notification)
                        }
                        .buttonStyle(.plain)
                        .listRowSeparator(.visible)
                    }
                    if hasMore && nextCursor != nil {
                        HStack {
                            Spacer()
                            if isLoadingMore { ProgressView() }
                            else { Button("더 보기") { Task { await loadMore() } } }
                            Spacer()
                        }
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .refreshable { await loadFirstPage() }
            }
        }
        .background(HGColor.appBackground)
        .navigationTitle("알림")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadFirstPage() }
        .onChange(of: category) { _, _ in Task { await loadFirstPage() } }
        .alert(error?.title ?? "알림 조회 오류", isPresented: errorAlert) {
            Button("다시 시도") {
                Task {
                    if failedToLoadMore { await loadMore() }
                    else { await loadFirstPage() }
                }
            }
            Button("확인", role: .cancel) {}
        } message: { Text(error?.alertMessage ?? "") }
        .alert("알림", isPresented: noticeAlert) {
            Button("확인", role: .cancel) {}
        } message: { Text(selectedNotice ?? "") }
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(HGNotificationCategory.allCases) { item in
                    Button { category = item } label: {
                        Text(item.title)
                            .font(HGFont.medium(12, relativeTo: .caption))
                            .foregroundStyle(category == item ? .white : HGColor.secondaryText)
                            .padding(.horizontal, 15).frame(height: 32)
                            .background(category == item ? HGColor.primary : HGColor.surface, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 6)
    }

    @MainActor private func loadFirstPage() async {
        let requestID = UUID()
        listRequestID = requestID
        failedToLoadMore = false
        isLoading = true
        defer {
            if listRequestID == requestID { isLoading = false }
        }
        do {
            let page = try await HGNotificationService().fetch(category: category)
            guard listRequestID == requestID else { return }
            notifications = page.items
            nextCursor = page.page.nextCursor
            hasMore = page.page.hasMore && page.page.nextCursor != nil
            unreadCount = page.unreadCount
            onUnreadCountChanged(unreadCount)
            error = nil
        } catch let requestError {
            guard listRequestID == requestID else { return }
            error = HGErrorPresentation(error: requestError)
        }
    }

    @MainActor private func loadMore() async {
        guard !isLoadingMore, hasMore, let nextCursor else { return }
        let requestID = listRequestID
        let selectedCategory = category
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await HGNotificationService().fetch(category: selectedCategory, cursor: nextCursor)
            guard listRequestID == requestID else { return }
            let existingIDs = Set(notifications.map(\.id))
            notifications.append(contentsOf: page.items.filter { !existingIDs.contains($0.id) })
            self.nextCursor = page.page.nextCursor
            hasMore = page.page.hasMore && page.page.nextCursor != nil
            failedToLoadMore = false
            unreadCount = page.unreadCount
            onUnreadCountChanged(unreadCount)
            error = nil
        } catch let requestError {
            guard listRequestID == requestID else { return }
            failedToLoadMore = true
            error = HGErrorPresentation(error: requestError)
        }
    }

    @MainActor private func open(_ notification: HGNotification) async {
        do {
            if !notification.read {
                guard markingReadIDs.insert(notification.id).inserted else { return }
                defer { markingReadIDs.remove(notification.id) }
                try await HGNotificationService().markRead(id: notification.id)
                unreadCount = max(0, unreadCount - 1)
                onUnreadCountChanged(unreadCount)
                if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                    notifications[index] = HGNotification(
                        notificationID: notification.notificationID,
                        title: notification.title,
                        resourceID: notification.resourceID,
                        createdAt: notification.createdAt,
                        type: notification.type,
                        category: notification.category,
                        read: true
                    )
                }
            }
            switch notification.type {
            case .recordCreated, .inquiryAnswered:
                onSelect(notification)
            case .emergencyAcknowledged, .unknown:
                selectedNotice = notification.title
            }
        } catch {
            failedToLoadMore = false
            self.error = HGErrorPresentation(error: error)
        }
    }

    private var errorAlert: Binding<Bool> {
        Binding(get: { error != nil }, set: { if !$0 { error = nil } })
    }

    private var noticeAlert: Binding<Bool> {
        Binding(get: { selectedNotice != nil }, set: { if !$0 { selectedNotice = nil } })
    }
}

private struct NotificationRow: View {
    let notification: HGNotification

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(notification.read ? Color.clear : HGColor.primary)
                .frame(width: 8, height: 8)
                .padding(.top, 7)
            VStack(alignment: .leading, spacing: 6) {
                Text(notification.title)
                    .font(HGFont.semiBold(14, relativeTo: .subheadline))
                    .foregroundStyle(HGColor.primaryText)
                HStack {
                    Text(notification.category.title)
                    Spacer()
                    Text(notification.createdAt.notificationDateText)
                }
                .font(HGFont.regular(11, relativeTo: .caption2))
                .foregroundStyle(HGColor.secondaryText)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(HGColor.secondaryText)
                .padding(.top, 3)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

private extension String {
    var notificationDateText: String {
        guard let date = hgISO8601Date else { return self }
        return date.formatted(date: .numeric, time: .shortened)
    }
}
