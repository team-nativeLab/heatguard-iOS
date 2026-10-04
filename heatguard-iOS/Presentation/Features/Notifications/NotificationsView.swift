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
                VStack(spacing: 10) {
                    Image("bell")
                        .resizable().scaledToFit().frame(width: 36, height: 36)
                        .frame(width: 72, height: 72)
                        .background(HGColor.homeActionIconBackground, in: Circle())
                    Text("아직 받은 알림이 없어요")
                        .font(HGFont.bold(16, relativeTo: .headline))
                        .foregroundStyle(HGColor.primaryText)
                    Text("폭염 경보나 기록 알림이 오면 여기에 모아서 보여드려요")
                        .font(HGFont.regular(13, relativeTo: .subheadline))
                        .foregroundStyle(HGColor.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 24)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(groupedNotifications, id: \.date) { group in
                            Text(group.dateLabel)
                                .font(HGFont.medium(12, relativeTo: .caption))
                                .foregroundStyle(HGColor.secondaryText)
                            VStack(spacing: 0) {
                                ForEach(group.items) { notification in
                                    Button { Task { await open(notification) } } label: {
                                        NotificationRow(notification: notification)
                                    }
                                    .buttonStyle(.plain)
                                    if notification.id != group.items.last?.id { Divider() }
                                }
                            }
                            .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 16))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        if hasMore && nextCursor != nil {
                            Button { Task { await loadMore() } } label: {
                                HStack(spacing: 8) {
                                    if isLoadingMore { ProgressView() }
                                    Text(isLoadingMore ? "불러오는 중..." : "더 보기")
                                }
                                .font(HGFont.medium(13, relativeTo: .subheadline))
                                .foregroundStyle(HGColor.primary)
                                .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .disabled(isLoadingMore)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 14)
                }
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

    private var groupedNotifications: [NotificationDayGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: notifications) { notification in
            notification.createdAt.hgISO8601Date.map(calendar.startOfDay(for:)) ?? .distantPast
        }
        return grouped.keys.sorted(by: >).map { date in
            let label: String
            if calendar.isDateInToday(date) { label = "오늘" }
            else if calendar.isDateInYesterday(date) { label = "어제" }
            else { label = "" }
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ko_KR")
            formatter.dateFormat = "M월 d일 (E)"
            let dateLabel = label.isEmpty ? formatter.string(from: date) : "\(label) · \(formatter.string(from: date))"
            return NotificationDayGroup(date: date, dateLabel: dateLabel, items: grouped[date] ?? [])
        }
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
            onSelect(notification)
        } catch {
            failedToLoadMore = false
            self.error = HGErrorPresentation(error: error)
        }
    }

    private var errorAlert: Binding<Bool> {
        Binding(get: { error != nil }, set: { if !$0 { error = nil } })
    }

}

private struct NotificationDayGroup {
    let date: Date
    let dateLabel: String
    let items: [HGNotification]
}

private struct NotificationRow: View {
    let notification: HGNotification

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: notification.category == .emergency ? "exclamationmark.triangle.fill" : notification.category == .record ? "thermometer.medium" : "bell.fill")
                .font(.system(size: 20))
                .foregroundStyle(notification.category == .emergency ? HGColor.error : HGColor.primary)
                .frame(width: 44, height: 44)
                .background(notification.category == .emergency ? HGColor.saveFailureIconBackground : HGColor.homeActionIconBackground, in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 6) {
                Text(notification.title)
                    .font(HGFont.semiBold(14, relativeTo: .subheadline))
                    .foregroundStyle(HGColor.primaryText)
            }
            Spacer(minLength: 4)
            Text(notification.createdAt.notificationTimeText)
                .font(HGFont.regular(12, relativeTo: .caption))
                .foregroundStyle(HGColor.secondaryText)
            if !notification.read {
                Circle().fill(HGColor.primary).frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(notification.read ? HGColor.surface : Color(red: 244 / 255, green: 247 / 255, blue: 254 / 255))
        .contentShape(Rectangle())
    }
}

private extension String {
    var notificationTimeText: String {
        guard let date = hgISO8601Date else { return self }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
