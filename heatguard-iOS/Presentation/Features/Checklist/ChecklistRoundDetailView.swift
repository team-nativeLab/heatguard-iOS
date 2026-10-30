import SwiftUI

struct ChecklistRoundDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let roundID: String
    let date: String
    let siteName: String?
    let teamName: String?
    private let service: HGChecklistService
    private let onRoundsUpdated: (HGChecklistRounds) -> Void
    private let onSelectRound: (String, String) -> Void

    @State private var round: HGChecklistRound?
    @State private var rounds: HGChecklistRounds?
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var error: HGErrorPresentation?

    init(
        roundID: String,
        date: String,
        siteName: String? = nil,
        teamName: String? = nil,
        service: HGChecklistService = HGChecklistService(),
        onRoundsUpdated: @escaping (HGChecklistRounds) -> Void = { _ in },
        onSelectRound: @escaping (String, String) -> Void = { _, _ in }
    ) {
        self.roundID = roundID
        self.date = date
        self.siteName = siteName
        self.teamName = teamName
        self.service = service
        self.onRoundsUpdated = onRoundsUpdated
        self.onSelectRound = onSelectRound
    }

    private var checkedCount: Int { round?.items.filter(\.checked).count ?? 0 }
    private var totalCount: Int { round?.items.count ?? 0 }
    private var isComplete: Bool { round?.isComplete == true }
    private var canEdit: Bool { round?.status == .inProgress && !isSaving && !isLoading }
    private var location: String {
        [siteName, teamName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    summaryCard
                    schedulePills
                    Text("관리자가 설정한 항목이에요. 확인한 항목을 눌러 체크하세요.")
                        .font(HGFont.medium(12, relativeTo: .caption))
                        .foregroundStyle(HGColor.secondaryText)
                    if isLoading && round == nil {
                        ProgressView("체크 항목을 불러오는 중...")
                            .tint(HGColor.primary)
                            .frame(maxWidth: .infinity, minHeight: 160)
                    } else if let round, round.items.isEmpty {
                        Text("등록된 체크 항목이 없어요.")
                            .font(HGFont.regular(13, relativeTo: .subheadline))
                            .foregroundStyle(HGColor.secondaryText)
                            .frame(maxWidth: .infinity, minHeight: 100)
                    } else if let round {
                        VStack(spacing: 0) {
                            ForEach(round.items.sorted { $0.sortOrder < $1.sortOrder }) { item in
                                itemRow(item)
                                if item.id != round.items.sorted(by: { $0.sortOrder < $1.sortOrder }).last?.id {
                                    Rectangle().fill(HGColor.homeTimelineLine).frame(height: 1)
                                }
                            }
                        }
                        .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 16)
                .padding(.bottom, 16)
            }
        }
        .background(HGColor.appBackground)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HGPrimaryButton(
                title: buttonTitle,
                isEnabled: isComplete && !isSaving,
                isLoading: isLoading || isSaving,
                disabledTint: HGColor.checklistDisabledButton
            ) { dismiss() }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(HGColor.appBackground)
        }
        .hgRouteNavigationHeader(title: "체크리스트")
        .task { await loadRound() }
        .alert(
            error?.title ?? "체크리스트 오류",
            isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })
        ) {
            Button("다시 시도") { Task { await loadRound() } }
            Button("확인", role: .cancel) {}
        } message: {
            Text(error?.alertMessage ?? "")
        }
    }

    private var buttonTitle: String {
        guard let round else { return isLoading ? "체크 항목 불러오는 중..." : "체크 항목 없음" }
        if round.items.isEmpty { return "체크 항목 없음" }
        if round.status == .completed { return "체크 완료" }
        if round.status == .missed { return "마감된 회차" }
        if round.status == .scheduled { return "시작 전 회차" }
        return isComplete ? "체크 완료" : "체크 완료 (\(checkedCount)/\(totalCount))"
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(roundID) 체크")
                    .font(HGFont.bold(18, relativeTo: .headline))
                    .foregroundStyle(HGColor.primaryText)
                Spacer()
                if let round {
                    Text(statusText(round.status))
                        .font(HGFont.medium(11, relativeTo: .caption))
                        .foregroundStyle(statusColor(round.status))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor(round.status).opacity(0.10), in: Capsule())
                }
            }
            Text(location.isEmpty ? date : location)
                .font(HGFont.regular(12, relativeTo: .caption))
                .foregroundStyle(HGColor.secondaryText)
            if !location.isEmpty {
                Text(date)
                    .font(HGFont.regular(10, relativeTo: .caption2))
                    .foregroundStyle(HGColor.secondaryText)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(HGColor.homeTimelineLine)
                    Capsule()
                        .fill(isComplete ? HGColor.checklistSuccess : HGColor.primary)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 6)
            Text("체크리스트 \(checkedCount) / \(totalCount) 완료 · \(round?.progressPercent ?? 0)%")
                .font(HGFont.medium(12, relativeTo: .caption))
                .foregroundStyle(isComplete ? HGColor.checklistSuccess : HGColor.primary)
        }
        .padding(16)
        .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private var progress: CGFloat {
        guard totalCount > 0 else { return 0 }
        return CGFloat((checkedCount * 100) / totalCount) / 100
    }

    private var schedulePills: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 58), spacing: 7)], alignment: .leading, spacing: 7) {
            ForEach(rounds?.items ?? []) { item in
                Button {
                    guard item.roundId != roundID else { return }
                    onSelectRound(item.roundId, date)
                } label: {
                    Text(roundPillTitle(item))
                        .font(HGFont.medium(10, relativeTo: .caption2))
                        .foregroundStyle(item.roundId == roundID ? HGColor.primary : pillColor(item.status))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .background(item.roundId == roundID ? HGColor.photoSelectionBackground : HGColor.surface, in: Capsule())
                        .overlay(Capsule().stroke(pillColor(item.status).opacity(0.22), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(item.roundId) \(statusText(item.status))")
                .accessibilityAddTraits(item.roundId == roundID ? [] : .isButton)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func itemRow(_ item: HGChecklistRound.Item) -> some View {
        Button { Task { await toggle(item) } } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(item.checked ? HGColor.primary : HGColor.surface)
                    Circle().stroke(item.checked ? HGColor.primary : HGColor.homeTimelineBorder, lineWidth: item.checked ? 0 : 1.5)
                    if item.checked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 22, height: 22)
                Text(item.text)
                    .font(HGFont.medium(13, relativeTo: .subheadline))
                    .foregroundStyle(item.checked ? HGColor.secondaryText : HGColor.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if isSaving {
                    ProgressView().controlSize(.small).tint(HGColor.primary)
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canEdit)
        .accessibilityLabel(item.text)
        .accessibilityValue(item.checked ? "체크됨" : "체크 안 됨")
    }

    private func statusText(_ status: HGChecklistRoundStatus) -> String {
        switch status {
        case .scheduled: "예정"
        case .inProgress: "진행 중"
        case .completed: "완료"
        case .missed: "미완료"
        }
    }

    private func statusColor(_ status: HGChecklistRoundStatus) -> Color {
        switch status {
        case .scheduled: HGColor.secondaryText
        case .inProgress: HGColor.primary
        case .completed: HGColor.checklistSuccess
        case .missed: HGColor.error
        }
    }

    private func pillColor(_ status: HGChecklistRoundStatus) -> Color {
        switch status {
        case .completed: HGColor.primary
        case .missed: HGColor.error
        case .inProgress: HGColor.primary
        case .scheduled: HGColor.secondaryText
        }
    }

    private func roundPillTitle(_ item: HGChecklistRoundSummary) -> String {
        let rawTime = HGDateFormatting.time(item.startsAt)
        let time = rawTime.hasSuffix(":00") ? String(rawTime.prefix(2)) + "시" : rawTime
        let marker: String
        switch item.status {
        case .completed: marker = "✓"
        case .missed: marker = "!"
        case .inProgress: marker = "●"
        case .scheduled: marker = ""
        }
        return marker.isEmpty ? time : "\(marker) \(time)"
    }

    @MainActor
    private func loadRound() async {
        isLoading = true
        do {
            async let roundRequest = service.fetchRound(id: roundID, date: date)
            async let roundsRequest = service.fetchRounds(date: date)
            let (loadedRound, loadedRounds) = try await (roundRequest, roundsRequest)
            round = loadedRound
            rounds = loadedRounds
            error = nil
        } catch is CancellationError {
            return
        } catch {
            self.error = HGChecklistAPIErrorPresentation.make(from: error)
        }
        isLoading = false
    }

    @MainActor
    private func toggle(_ item: HGChecklistRound.Item) async {
        guard canEdit, let index = round?.items.firstIndex(where: { $0.id == item.id }) else { return }
        let previousValue = item.checked
        round?.items[index].checked.toggle()
        isSaving = true
        do {
            let refreshed = try await service.updateRoundItem(
                roundID: roundID,
                itemID: item.id,
                isChecked: !previousValue
            )
            round?.items[index].checked = refreshed.checked
            do {
                async let updatedRound = service.fetchRound(id: roundID, date: date)
                async let updatedRounds = service.fetchRounds(date: date)
                let (loadedRound, loadedRounds) = try await (updatedRound, updatedRounds)
                round = loadedRound
                rounds = loadedRounds
                onRoundsUpdated(loadedRounds)
            } catch {
                self.error = HGErrorPresentation(
                    title: "저장은 완료됐지만 새로고침하지 못했습니다",
                    message: "체크 상태는 저장됐어요. 화면을 다시 열거나 다시 시도해 최신 진행률을 확인해주세요.",
                    diagnosticCode: HGChecklistAPIErrorPresentation.make(from: error).diagnosticCode
                )
                isSaving = false
                return
            }
            error = nil
        } catch is CancellationError {
            round?.items[index].checked = previousValue
        } catch {
            round?.items[index].checked = previousValue
            let presentation = HGChecklistAPIErrorPresentation.make(from: error)
            if case HGAPIError.server(_, 409, "ROUND_NOT_OPEN") = error {
                do {
                    async let updatedRound = service.fetchRound(id: roundID, date: date)
                    async let updatedRounds = service.fetchRounds(date: date)
                    let (loadedRound, loadedRounds) = try await (updatedRound, updatedRounds)
                    round = loadedRound
                    rounds = loadedRounds
                    onRoundsUpdated(loadedRounds)
                } catch {
                    // Keep the original 409 as the actionable error; the next retry will refresh again.
                }
            }
            self.error = presentation
        }
        isSaving = false
    }
}
