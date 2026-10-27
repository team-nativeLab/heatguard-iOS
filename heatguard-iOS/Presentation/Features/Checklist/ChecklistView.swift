import SwiftUI

struct ChecklistView: View {
    @Environment(\.dismiss) private var dismiss

    let times: [String]
    let siteName: String?
    let teamName: String?
    private let service: HGChecklistService
    private let onProgressChanged: (Int, Int) -> Void

    @State private var items: [HGChecklistItem] = []
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var updatingItemIDs: Set<String> = []
    @State private var error: HGErrorPresentation?

    init(
        times: [String],
        siteName: String?,
        teamName: String?,
        service: HGChecklistService = HGChecklistService(),
        onProgressChanged: @escaping (Int, Int) -> Void = { _, _ in }
    ) {
        self.times = times
        self.siteName = siteName
        self.teamName = teamName
        self.service = service
        self.onProgressChanged = onProgressChanged
    }

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 700
            let rowHeight = checklistRowHeight(for: geometry.size.height)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    summaryCard(compact: compact)
                        .padding(.top, compact ? 4 : 6)

                    schedule(compact: compact)
                        .padding(.top, compact ? 10 : 14)

                    Text("관리자가 설정한 항목이에요. 확인한 항목을 눌러 체크하세요.")
                        .font(HGFont.regular(compact ? 10 : 11, relativeTo: .caption2))
                        .foregroundStyle(HGColor.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .padding(.top, compact ? 8 : 12)

                    checklistItems(rowHeight: rowHeight)
                        .padding(.top, compact ? 5 : 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, compact ? 8 : 12)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)
                .padding(.top, compact ? 4 : 12)
            }
            .background(HGColor.appBackground)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HGPrimaryButton(
                title: buttonTitle,
                isEnabled: isComplete && updatingItemIDs.isEmpty,
                isLoading: isLoading,
                disabledTint: HGColor.checklistDisabledButton
            ) {
                dismiss()
            }
            .padding(.horizontal, 28)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(HGColor.appBackground)
        }
        .background(HGColor.appBackground)
        .hgRouteNavigationHeader(title: "체크리스트")
        .task { await loadItems() }
        .alert(
            error?.title ?? "체크리스트 오류",
            isPresented: Binding(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            )
        ) {
            if loadFailed {
                Button("다시 시도") {
                    Task { await loadItems() }
                }
            }
            Button("확인", role: .cancel) {}
        } message: {
            Text(error?.alertMessage ?? "")
        }
    }

    private var checkedCount: Int {
        items.filter(\.checked).count
    }

    private var isComplete: Bool {
        !items.isEmpty && checkedCount == items.count
    }

    private var buttonTitle: String {
        if isLoading { return "체크 항목 불러오는 중..." }
        guard !items.isEmpty else { return "체크 항목 없음" }
        return isComplete ? "체크 완료" : "체크 완료 (\(checkedCount)/\(items.count))"
    }

    private var locationSubtitle: String {
        let names = [siteName, teamName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return names.isEmpty ? "오늘 확인할 체크 항목" : names.joined(separator: " · ")
    }

    private var activeTime: String? {
        let scheduled = times.compactMap { time -> (String, Int)? in
            let displayTime = time.trimmingCharacters(in: .whitespacesAndNewlines)
            let parts = displayTime.split(separator: ":")
            guard parts.count >= 2,
                  let hour = Int(parts[0]),
                  let minute = Int(parts[1]),
                  (0..<24).contains(hour),
                  (0..<60).contains(minute) else { return nil }
            return (formatTime(displayTime), hour * 60 + minute)
        }
        .sorted { $0.1 < $1.1 }

        guard !scheduled.isEmpty else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        let now = calendar.dateComponents([.hour, .minute], from: Date())
        let currentMinute = (now.hour ?? 0) * 60 + (now.minute ?? 0)
        return scheduled.first(where: { $0.1 >= currentMinute })?.0
    }

    private func formatTime(_ rawTime: String) -> String {
        let parts = rawTime.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":")
        guard parts.count >= 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0..<24).contains(hour),
              (0..<60).contains(minute) else { return rawTime }
        if minute == 0 { return String(format: "%02d시", hour) }
        return String(format: "%02d:%02d", hour, minute)
    }

    private func summaryCard(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 7 : 8) {
            HStack(alignment: .center) {
                Text(activeTime.map { "\($0) 체크" } ?? "오늘 체크")
                    .font(HGFont.bold(16, relativeTo: .headline))
                    .foregroundStyle(HGColor.primaryText)

                Spacer(minLength: 8)

                Text(isComplete ? "완료" : "진행 중")
                    .font(HGFont.medium(11, relativeTo: .caption))
                    .foregroundStyle(isComplete ? HGColor.checklistSuccess : HGColor.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        isComplete ? HGColor.successBackground : HGColor.photoSelectionBackground,
                        in: Capsule()
                    )
            }

            Text(locationSubtitle)
                .font(HGFont.regular(12, relativeTo: .caption))
                .foregroundStyle(HGColor.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(HGColor.homeTimelineLine)
                    Capsule()
                        .fill(isComplete ? HGColor.checklistSuccess : HGColor.primary)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 6)
            .animation(.easeInOut(duration: 0.2), value: checkedCount)

            HStack {
                Text("체크리스트")
                Spacer()
                Text(isLoading ? "불러오는 중" : "\(checkedCount) / \(items.count) 완료")
            }
            .font(HGFont.regular(11, relativeTo: .caption2))
            .foregroundStyle(HGColor.secondaryText)
        }
        .padding(.horizontal, 0)
        .padding(.vertical, compact ? 4 : 6)
    }

    private var progress: CGFloat {
        guard !items.isEmpty else { return 0 }
        return CGFloat(checkedCount) / CGFloat(items.count)
    }

    @ViewBuilder
    private func schedule(compact: Bool) -> some View {
        if times.isEmpty {
            Text("체크 시간이 설정되지 않았어요.")
                .font(HGFont.regular(11, relativeTo: .caption2))
                .foregroundStyle(HGColor.secondaryText)
                .frame(maxWidth: .infinity, minHeight: compact ? 34 : 40)
        } else {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 5),
                alignment: .leading,
                spacing: compact ? 3 : 5
            ) {
                ForEach(Array(times.enumerated()), id: \.offset) { _, rawTime in
                    let time = rawTime.trimmingCharacters(in: .whitespacesAndNewlines)
                    let displayTime = formatTime(time)
                    let isActive = displayTime == activeTime

                    HStack(spacing: 4) {
                        if isActive {
                            Circle()
                                .fill(.white)
                                .frame(width: 4, height: 4)
                        }
                        Text(displayTime)
                            .font(HGFont.medium(compact ? 10 : 11, relativeTo: .caption2))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .foregroundStyle(isActive ? Color.white : HGColor.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: compact ? 25 : 28)
                    .background(
                        isActive ? HGColor.primary : HGColor.surface,
                        in: Capsule()
                    )
                    .overlay {
                        Capsule().stroke(isActive ? Color.clear : HGColor.inputBorder, lineWidth: 1)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func checklistItems(rowHeight: CGFloat) -> some View {
        if isLoading {
            ProgressView("체크 항목을 불러오는 중...")
                .font(HGFont.regular(12, relativeTo: .caption))
                .tint(HGColor.primary)
                .frame(maxWidth: .infinity, minHeight: min(rowHeight * 3, 150))
        } else if items.isEmpty {
            VStack(spacing: 8) {
                Text(loadFailed ? "체크 항목을 불러오지 못했어요." : "등록된 체크 항목이 없어요.")
                    .font(HGFont.regular(13, relativeTo: .subheadline))
                    .foregroundStyle(HGColor.secondaryText)
                if loadFailed {
                    Button("다시 시도") { Task { await loadItems() } }
                        .font(HGFont.semiBold(13, relativeTo: .caption))
                        .foregroundStyle(HGColor.primary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: min(rowHeight * 3, 150))
        } else {
            VStack(spacing: 0) {
                ForEach(items) { item in
                    HGChecklistItemRow(
                        item: item,
                        isSaving: updatingItemIDs.contains(item.id),
                        height: rowHeight
                    ) {
                        Task { await toggle(item) }
                    }

                    if item.id != items.last?.id {
                        Divider()
                            .overlay(HGColor.inputBorder)
                    }
                }
            }
        }
    }

    private func checklistRowHeight(for availableHeight: CGFloat) -> CGFloat {
        let itemCount = max(items.count, 6)
        let reservedHeight: CGFloat = availableHeight < 700 ? 250 : 290
        let fittedHeight = (availableHeight - reservedHeight) / CGFloat(itemCount)
        return min(availableHeight < 700 ? 46 : 54, max(34, fittedHeight))
    }

    @MainActor
    private func loadItems() async {
        isLoading = true
        loadFailed = false
        error = nil
        defer { isLoading = false }

        do {
            items = try await service.fetchItems()
            publishProgress()
        } catch is CancellationError {
            return
        } catch {
            loadFailed = true
            self.error = HGErrorPresentation(error: error)
        }
    }

    @MainActor
    private func toggle(_ item: HGChecklistItem) async {
        guard !updatingItemIDs.contains(item.id),
              let index = items.firstIndex(where: { $0.id == item.id }) else { return }

        let previousValue = items[index].checked
        items[index] = HGChecklistItem(id: item.id, text: item.text, checked: !previousValue)
        updatingItemIDs.insert(item.id)
        publishProgress()

        do {
            let response = try await service.update(itemID: item.id, isChecked: !previousValue)
            if let updatedIndex = items.firstIndex(where: { $0.id == item.id }) {
                items[updatedIndex] = HGChecklistItem(
                    id: item.id,
                    text: item.text,
                    checked: response.checked
                )
            }
        } catch is CancellationError {
            restore(item, checked: previousValue)
        } catch {
            restore(item, checked: previousValue)
            loadFailed = false
            self.error = HGErrorPresentation(error: error)
        }

        updatingItemIDs.remove(item.id)
        publishProgress()
    }

    private func restore(_ item: HGChecklistItem, checked: Bool) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = HGChecklistItem(id: item.id, text: item.text, checked: checked)
    }

    private func publishProgress() {
        onProgressChanged(checkedCount, items.count)
    }
}

private struct HGChecklistItemRow: View {
    let item: HGChecklistItem
    let isSaving: Bool
    let height: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(item.checked ? HGColor.primary : .clear)
                    Circle()
                        .stroke(item.checked ? HGColor.primary : HGColor.homeTimelineBorder, lineWidth: 1.2)
                    if item.checked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 24, height: 24)

                Text(item.text)
                    .font(HGFont.medium(14, relativeTo: .subheadline))
                    .foregroundStyle(item.checked ? HGColor.secondaryText : HGColor.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 4)

                if isSaving {
                    ProgressView()
                        .controlSize(.small)
                        .tint(HGColor.primary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: height, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
        .accessibilityLabel(item.text)
        .accessibilityValue(item.checked ? "체크됨" : "체크 안 됨")
        .accessibilityHint("두 번 탭하여 체크 상태를 변경합니다")
    }
}

#Preview {
    NavigationStack {
        ChecklistView(
            times: ["08:00", "10:00", "12:00", "14:00", "16:00", "18:00", "20:00", "22:00"],
            siteName: "서울 현장",
            teamName: "안전 관리팀"
        )
    }
}
