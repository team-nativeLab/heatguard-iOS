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
                VStack(alignment: .leading, spacing: 14) {
                    summaryCard()

                    schedule()

                    Text("관리자가 설정한 항목이에요. 확인한 항목을 눌러 체크하세요.")
                        .font(HGFont.medium(12, relativeTo: .caption))
                        .foregroundStyle(HGColor.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    checklistItems(rowHeight: rowHeight)
                }
                .padding(.top, compact ? 4 : 12)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(HGColor.surface)
                .padding(.horizontal, 24)
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

    private var activeMinute: Int? {
        let scheduled = times.compactMap(minuteValue).sorted()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        let now = calendar.dateComponents([.hour, .minute], from: Date())
        let currentMinute = (now.hour ?? 0) * 60 + (now.minute ?? 0)
        return scheduled.first(where: { $0 >= currentMinute }) ?? scheduled.last
    }

    private var activeTime: String? {
        guard let activeMinute else { return nil }
        return String(format: "%02d:%02d", activeMinute / 60, activeMinute % 60)
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

    private func minuteValue(for rawTime: String) -> Int? {
        let parts = rawTime.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":")
        guard parts.count >= 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0..<24).contains(hour),
              (0..<60).contains(minute) else { return nil }
        return hour * 60 + minute
    }

    private func summaryCard() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                Text(activeTime.map { "\($0) 체크" } ?? "오늘 체크")
                    .font(HGFont.bold(18, relativeTo: .headline))
                    .foregroundStyle(HGColor.primaryText)

                Spacer(minLength: 8)

                Text(isComplete ? "완료" : "진행 중")
                    .font(HGFont.medium(11, relativeTo: .caption))
                    .foregroundStyle(isComplete ? HGColor.checklistSuccess : HGColor.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        isComplete ? HGColor.successBackground : HGColor.photoSelectionBackground,
                        in: Capsule()
                    )
            }

            Text(locationSubtitle)
                .font(HGFont.regular(13, relativeTo: .caption))
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
                Text(isLoading ? "체크 항목 불러오는 중" : "체크리스트 \(checkedCount) / \(items.count) 완료")
            }
            .font(HGFont.medium(12, relativeTo: .caption))
            .foregroundStyle(isComplete ? HGColor.checklistSuccess : HGColor.primary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var progress: CGFloat {
        guard !items.isEmpty else { return 0 }
        return CGFloat(checkedCount) / CGFloat(items.count)
    }

    @ViewBuilder
    private func schedule() -> some View {
        if times.isEmpty {
            Text("체크 시간이 설정되지 않았어요.")
                .font(HGFont.regular(11, relativeTo: .caption2))
                .foregroundStyle(HGColor.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 34)
        } else {
            HGChecklistFlowLayout(spacing: 6) {
                ForEach(Array(times.enumerated()), id: \.offset) { _, rawTime in
                    let time = rawTime.trimmingCharacters(in: .whitespacesAndNewlines)
                    let displayTime = formatTime(time)
                    let isActive = minuteValue(for: time) == activeMinute
                    let isUpcoming = activeMinute.map { active in
                        minuteValue(for: time).map { $0 > active } ?? false
                    } ?? false

                    HStack(spacing: 4) {
                        if isActive {
                            Text("●")
                                .font(HGFont.bold(8, relativeTo: .caption2))
                        }
                        Text(displayTime)
                            .font(HGFont.medium(12, relativeTo: .caption))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .foregroundStyle(isActive ? Color.white : (isUpcoming ? HGColor.placeholder : HGColor.primaryText))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        isActive ? HGColor.primary : HGColor.surface,
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isActive ? Color.clear : HGColor.homeTimelineLine, lineWidth: 1)
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
                        .fill(item.checked ? HGColor.primary : HGColor.surface)
                    Circle()
                        .stroke(
                            item.checked ? HGColor.primary : Color(red: 201 / 255, green: 207 / 255, blue: 219 / 255),
                            lineWidth: item.checked ? 0 : 1.5
                        )
                    if item.checked {
                        Text("✓")
                            .font(HGFont.bold(13, relativeTo: .caption))
                            .foregroundStyle(Color.white)
                    }
                }
                .frame(width: 24, height: 24)

                Text(item.text)
                    .font(item.checked ? HGFont.regular(14, relativeTo: .subheadline) : HGFont.medium(14, relativeTo: .subheadline))
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
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
        .accessibilityLabel(item.text)
        .accessibilityValue(item.checked ? "체크됨" : "체크 안 됨")
        .accessibilityHint("두 번 탭하여 체크 상태를 변경합니다")
    }
}

private struct HGChecklistFlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        var cursorX: CGFloat = 0
        var cursorY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if cursorX > 0, cursorX + size.width > width {
                cursorX = 0
                cursorY += lineHeight + spacing
                lineHeight = 0
            }
            cursorX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return CGSize(width: width, height: cursorY + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var cursorX = bounds.minX
        var cursorY = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if cursorX > bounds.minX, cursorX + size.width > bounds.maxX {
                cursorX = bounds.minX
                cursorY += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(
                at: CGPoint(x: cursorX, y: cursorY),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )
            cursorX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
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
