import SwiftUI

struct ChecklistView: View {
    @Environment(\.dismiss) private var dismiss

    let times: [String]
    let siteName: String?
    let teamName: String?
    @State private var selectedTime: String?
    @State private var rounds: [HGChecklistRoundSummary] = []
    @State private var selectedRound: HGChecklistRound?
    @State private var selectedRoundIndex = 0
    @State private var now = Date()
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
        selectedTime: String? = nil,
        service: HGChecklistService = HGChecklistService(),
        onProgressChanged: @escaping (Int, Int) -> Void = { _, _ in }
    ) {
        self.times = times
        self.siteName = siteName
        self.teamName = teamName
        _selectedTime = State(initialValue: selectedTime)
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
        .task { await loadRounds() }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                now = Date()
            }
        }
        .alert(
            error?.title ?? "체크리스트 오류",
            isPresented: Binding(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            )
        ) {
            if loadFailed {
                Button("다시 시도") {
                    Task { await loadRounds() }
                }
            }
            Button("확인", role: .cancel) {}
        } message: {
            Text(error?.alertMessage ?? "")
        }
    }

    private var checkedCount: Int {
        selectedRound?.items.filter(\.checked).count ?? 0
    }

    private var isComplete: Bool {
        selectedRound?.isComplete ?? false
    }

    private var buttonTitle: String {
        if isLoading { return "체크 항목 불러오는 중..." }
        guard let selectedRound, !selectedRound.items.isEmpty else { return "체크 항목 없음" }
        return isComplete ? "체크 완료" : "체크 완료 (\(checkedCount)/\(selectedRound.totalItems))"
    }

    private var locationSubtitle: String {
        let names = [siteName, teamName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return names.isEmpty ? "오늘 확인할 체크 항목" : names.joined(separator: " · ")
    }

    private var currentMinute: Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        let components = calendar.dateComponents([.hour, .minute], from: now)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private var today: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: now)
    }

    private var preferredRoundIndex: Int {
        guard !rounds.isEmpty else { return 0 }
        if let inProgress = rounds.firstIndex(where: { $0.status == .inProgress }) { return inProgress }
        if let upcoming = rounds.firstIndex(where: {
            $0.status == .scheduled && (roundDate($0.startsAt)?.timeIntervalSince(now) ?? -.infinity) >= 0
        }) { return upcoming }
        return rounds.indices.last ?? 0
    }

    private var selectedRoundStatusColor: Color {
        guard let selectedRound else { return HGColor.secondaryText }
        return statusColor(selectedRound.status)
    }

    private var selectedTimeCaption: String {
        guard let selectedRound else { return "오늘 체크 항목" }
        return "\(displayRoundTime(selectedRound.startsAt)) · \(selectedRound.checkedItems)/\(selectedRound.totalItems) 완료"
    }

    private func statusColor(_ status: HGChecklistRoundStatus) -> Color {
        switch status {
        case .completed, .inProgress: HGColor.primary
        case .missed: HGColor.error
        case .scheduled: HGColor.secondaryText
        }
    }

    private func roundAccessibilityLabel(for round: HGChecklistRoundSummary) -> String {
        let time = displayRoundTime(round.startsAt)
        return "\(time) \(round.status.rawValue) \(round.checkedItems)/\(round.totalItems)"
    }

    private func connectorColor(for status: HGChecklistRoundStatus) -> Color {
        switch status {
        case .completed: HGColor.primary
        case .missed: HGColor.error
        case .inProgress, .scheduled: HGColor.homeTimelineLine
        }
    }

    private func roundDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private func displayRoundTime(_ value: String) -> String {
        guard let date = roundDate(value) else { return formatTime(value) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "HH시"
        return formatter.string(from: date)
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
                Text(selectedTimeCaption)
                    .font(HGFont.bold(18, relativeTo: .headline))
                    .foregroundStyle(HGColor.primaryText)

                Spacer(minLength: 8)

                Text(selectedRound?.status == .missed ? "미완료" : (isComplete ? "완료" : "진행 중"))
                    .font(HGFont.medium(11, relativeTo: .caption))
                    .foregroundStyle(selectedRoundStatusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(HGColor.photoSelectionBackground, in: Capsule())
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
                        .fill(HGColor.primary)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 6)
            .animation(.easeInOut(duration: 0.2), value: checkedCount)

            HStack {
                Text(isLoading ? "체크 항목 불러오는 중" : "체크리스트 \(checkedCount) / \(selectedRound?.totalItems ?? 0) 완료")
            }
            .font(HGFont.medium(12, relativeTo: .caption))
            .foregroundStyle(HGColor.primary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var progress: CGFloat {
        guard let selectedRound, selectedRound.totalItems > 0 else { return 0 }
        return CGFloat(selectedRound.checkedItems) / CGFloat(selectedRound.totalItems)
    }

    @ViewBuilder
    private func schedule() -> some View {
        if rounds.isEmpty {
            Text("오늘 체크 회차가 설정되지 않았어요.")
                .font(HGFont.regular(11, relativeTo: .caption2))
                .foregroundStyle(HGColor.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 34)
        } else {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(Array(rounds.enumerated()), id: \.element.id) { index, round in
                            let isSelected = selectedRoundIndex == index
                            let color = statusColor(round.status)

                            Button {
                                selectedRoundIndex = index
                                selectedTime = displayRoundTime(round.startsAt)
                                Task { await selectRound(at: index) }
                            } label: {
                                VStack(spacing: 7) {
                                    ZStack {
                                        if isSelected {
                                            Circle().fill(color.opacity(0.16)).frame(width: 28, height: 28)
                                        }
                                        Circle()
                                            .fill(round.status == .scheduled ? HGColor.surface : color)
                                            .frame(width: isSelected ? 16 : 12, height: isSelected ? 16 : 12)
                                        if round.status == .scheduled {
                                            Circle()
                                                .stroke(color, lineWidth: 1.5)
                                                .frame(width: isSelected ? 16 : 12, height: isSelected ? 16 : 12)
                                        } else if round.status == .completed {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 7, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    Text(displayRoundTime(round.startsAt))
                                        .font(isSelected ? HGFont.bold(13, relativeTo: .caption) : HGFont.medium(12, relativeTo: .caption))
                                        .foregroundStyle(color)
                                }
                                .frame(width: 58)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .id(round.id)
                            .accessibilityLabel(roundAccessibilityLabel(for: round))
                            .accessibilityAddTraits(isSelected ? .isSelected : [])

                            if index < rounds.count - 1 {
                                Rectangle()
                                    .fill(connectorColor(for: round.status))
                                    .frame(width: 28, height: 2)
                                    .offset(y: -10)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .frame(height: 52)
                .onAppear {
                    guard rounds.indices.contains(selectedRoundIndex) else { return }
                    proxy.scrollTo(rounds[selectedRoundIndex].id, anchor: .center)
                }
                .onChange(of: selectedRoundIndex) { _, newValue in
                    guard rounds.indices.contains(newValue) else { return }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(rounds[newValue].id, anchor: .center)
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
                    Button("다시 시도") { Task { await loadRounds() } }
                        .font(HGFont.semiBold(13, relativeTo: .caption))
                        .foregroundStyle(HGColor.primary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: min(rowHeight * 3, 150))
        } else {
            VStack(spacing: 0) {
                ForEach(selectedRound?.items ?? []) { item in
                    HGChecklistItemRow(
                        item: item,
                        isSaving: updatingItemIDs.contains(item.id),
                        height: rowHeight
                    ) {
                        Task { await toggleRoundItem(item) }
                    }

                    if item.id != selectedRound?.items.last?.id {
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
    private func loadRounds() async {
        isLoading = true
        loadFailed = false
        error = nil
        defer { isLoading = false }

        do {
            let response = try await service.fetchRounds(date: today)
            rounds = response.items
            selectedRoundIndex = preferredRoundIndex
            await loadSelectedRound()
            publishProgress()
        } catch is CancellationError {
            return
        } catch {
            loadFailed = true
            self.error = HGChecklistAPIErrorPresentation.make(from: error)
        }
    }

    @MainActor
    private func loadSelectedRound() async {
        guard rounds.indices.contains(selectedRoundIndex) else {
            selectedRound = nil
            return
        }
        do {
            selectedRound = try await service.fetchRound(id: rounds[selectedRoundIndex].id, date: today)
            publishProgress()
        } catch {
            loadFailed = true
            self.error = HGChecklistAPIErrorPresentation.make(from: error)
        }
    }

    @MainActor
    private func selectRound(at index: Int) async {
        guard rounds.indices.contains(index) else { return }
        selectedRoundIndex = index
        isLoading = true
        defer { isLoading = false }
        await loadSelectedRound()
    }

    @MainActor
    private func toggleRoundItem(_ item: HGChecklistRound.Item) async {
        guard let round = selectedRound,
              !updatingItemIDs.contains(item.id),
              let currentItem = round.items.first(where: { $0.id == item.id }) else { return }
        updatingItemIDs.insert(item.id)
        do {
            let refreshed = try await service.updateRoundItem(
                roundID: round.roundId,
                itemID: item.id,
                isChecked: !currentItem.checked,
                date: round.date
            )
            selectedRound = refreshed.round
            rounds = refreshed.rounds.items
            if let updatedIndex = rounds.firstIndex(where: { $0.id == refreshed.round.roundId }) {
                selectedRoundIndex = updatedIndex
            }
        } catch {
            self.error = HGChecklistAPIErrorPresentation.make(from: error)
        }
        updatingItemIDs.remove(item.id)
        publishProgress()
    }

    private func publishProgress() {
        onProgressChanged(
            rounds.reduce(0) { $0 + $1.checkedItems },
            rounds.reduce(0) { $0 + $1.totalItems }
        )
    }
}

private struct HGChecklistItemRow: View {
    let item: HGChecklistRound.Item
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
