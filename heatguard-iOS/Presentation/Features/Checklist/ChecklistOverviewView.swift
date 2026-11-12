import SwiftUI

struct ChecklistOverviewView: View {
    let siteName: String?
    let teamName: String?
    let onOpenChecklist: (String, String) -> Void

    @State private var rounds: HGChecklistRounds?
    @State private var selectedRoundID: String?
    @State private var now = Date()
    @State private var isLoading = true
    @State private var error: HGErrorPresentation?
    private let service: HGChecklistService

    init(
        siteName: String?,
        teamName: String?,
        service: HGChecklistService = HGChecklistService(),
        onOpenChecklist: @escaping (String, String) -> Void
    ) {
        self.siteName = siteName
        self.teamName = teamName
        self.service = service
        self.onOpenChecklist = onOpenChecklist
    }

    private var location: String {
        [siteName, teamName].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private var selectedRound: HGChecklistRoundSummary? {
        guard let rounds, let selectedRoundID else { return nil }
        return rounds.items.first { $0.roundId == selectedRoundID }
    }

    private var nextScheduledRound: HGChecklistRoundSummary? {
        rounds?.items
            .filter { $0.status == .scheduled }
            .filter { roundDate($0.startsAt).map { $0 > now } ?? false }
            .min { (roundDate($0.startsAt) ?? .distantFuture) < (roundDate($1.startsAt) ?? .distantFuture) }
    }

    private var nextCheckCaption: String {
        guard let nextScheduledRound,
              let startsAt = roundDate(nextScheduledRound.startsAt) else {
            return rounds?.items.contains(where: { $0.status == .inProgress }) == true
                ? "현재 체크 시간이에요"
                : "오늘 예정된 다음 체크가 없습니다"
        }

        let remainingMinutes = max(0, Int(ceil(startsAt.timeIntervalSince(now) / 60)))
        let duration: String
        if remainingMinutes >= 60 {
            let hours = remainingMinutes / 60
            let minutes = remainingMinutes % 60
            duration = minutes == 0 ? "\(hours)시간" : "\(hours)시간 \(minutes)분"
        } else {
            duration = remainingMinutes == 0 ? "1분 이내" : "\(remainingMinutes)분"
        }
        return "다음 체크까지 \(duration) · \(displayClock(startsAt)) 예정"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if isLoading && rounds == nil {
                    ProgressView("회차 정보를 불러오는 중...")
                        .tint(HGColor.primary)
                        .frame(maxWidth: .infinity, minHeight: 160)
                } else if let rounds, rounds.items.isEmpty {
                    emptyState("오늘 예정된 체크 회차가 없습니다.")
                } else if let rounds {
                    timelineCard(rounds)
                    selectedRoundCard(rounds)
                    progressSummary(rounds)
                } else {
                    emptyState("회차 정보를 불러오지 못했습니다.")
                    Button("다시 시도") { Task { await loadRounds() } }
                        .font(HGFont.semiBold(13, relativeTo: .caption))
                        .foregroundStyle(HGColor.primary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 24)
        }
        .background(HGColor.appBackground.ignoresSafeArea())
        .hgRouteNavigationHeader(title: "체크리스트")
        .task { await loadRounds() }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { break }
                now = Date()
                await refreshRounds()
            }
        }
        .alert(
            error?.title ?? "체크리스트 오류",
            isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })
        ) {
            Button("다시 시도") { Task { await loadRounds() } }
            Button("확인", role: .cancel) {}
        } message: {
            Text(error?.alertMessage ?? "")
        }
    }

    private func timelineCard(_ rounds: HGChecklistRounds) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(nextCheckCaption)
                .font(HGFont.medium(14, relativeTo: .subheadline))
                .foregroundStyle(HGColor.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .accessibilityIdentifier("checklist.next-check-caption")

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(Array(rounds.items.enumerated()), id: \.element.roundId) { index, round in
                            timelineNode(round, date: rounds.date)
                                .id(round.roundId)

                            if index < rounds.items.count - 1 {
                                Capsule()
                                    .fill(connectorColor(for: round.status))
                                    .frame(width: 28, height: 2)
                                    .offset(y: -10)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .frame(height: 62)
                .onAppear { scrollToSelected(using: proxy, in: rounds) }
                .onChange(of: selectedRoundID) { _, _ in
                    scrollToSelected(using: proxy, in: rounds)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 18))
    }

    private func timelineNode(_ round: HGChecklistRoundSummary, date: String) -> some View {
        let isSelected = selectedRoundID == round.roundId
        let color = statusColor(round.status)

        return Button {
            selectedRoundID = round.roundId
            onOpenChecklist(round.roundId, date)
        } label: {
            VStack(spacing: 7) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(color.opacity(0.16))
                            .frame(width: 30, height: 30)
                    }
                    Circle()
                        .fill(nodeFill(for: round.status))
                        .frame(width: isSelected ? 16 : 12, height: isSelected ? 16 : 12)
                    Circle()
                        .stroke(color, lineWidth: 1.5)
                        .frame(width: isSelected ? 16 : 12, height: isSelected ? 16 : 12)
                        .opacity(round.status == .scheduled ? 1 : 0)
                    if round.status == .completed {
                        Image(systemName: "checkmark")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.white)
                    } else if round.status == .missed {
                        Image(systemName: "xmark")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                Text(displayTime(roundDate(round.startsAt)) ?? round.roundId)
                    .font(isSelected ? HGFont.bold(13, relativeTo: .caption) : HGFont.medium(12, relativeTo: .caption))
                    .foregroundStyle(color)
            }
            .frame(width: 54, height: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(displayTime(roundDate(round.startsAt)) ?? round.roundId) \(statusText(round.status))")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func selectedRoundCard(_ rounds: HGChecklistRounds) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(selectedRound.map { displayTime(roundDate($0.startsAt)) ?? $0.roundId } ?? "체크 회차")
                    .font(HGFont.bold(17, relativeTo: .headline))
                    .foregroundStyle(HGColor.primaryText)
                Spacer()
                if let selectedRound {
                    Text(statusText(selectedRound.status))
                        .font(HGFont.semiBold(11, relativeTo: .caption))
                        .foregroundStyle(statusColor(selectedRound.status))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(statusColor(selectedRound.status).opacity(0.10), in: Capsule())
                }
            }

            if let selectedRound {
                Text(roundSubtitle(selectedRound))
                    .font(HGFont.regular(12, relativeTo: .caption))
                    .foregroundStyle(selectedRound.status == .missed ? HGColor.error : HGColor.secondaryText)

                Button {
                    onOpenChecklist(selectedRound.roundId, rounds.date)
                } label: {
                    HStack {
                        Text("이 시간 체크리스트 열기")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(HGFont.semiBold(13, relativeTo: .subheadline))
                    .foregroundStyle(HGColor.primary)
                    .padding(.top, 3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func progressSummary(_ rounds: HGChecklistRounds) -> some View {
        HStack(spacing: 0) {
            stat(title: "완료", value: String(rounds.summary.completedRounds), color: HGColor.primary)
            statDivider
            stat(title: "미완료", value: String(rounds.summary.missedRounds), color: HGColor.error)
            statDivider
            stat(title: "남은 회차", value: String(rounds.summary.remainingRounds), color: HGColor.secondaryText)
        }
        .padding(.vertical, 13)
        .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func stat(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value).font(HGFont.bold(16, relativeTo: .headline)).foregroundStyle(color)
            Text(title).font(HGFont.regular(11, relativeTo: .caption2)).foregroundStyle(HGColor.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle().fill(HGColor.homeTimelineLine).frame(width: 1, height: 24)
    }

    private func scrollToSelected(using proxy: ScrollViewProxy, in rounds: HGChecklistRounds) {
        guard let selectedRoundID,
              rounds.items.contains(where: { $0.roundId == selectedRoundID }) else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            proxy.scrollTo(selectedRoundID, anchor: .center)
        }
    }

    private func preferredRoundID(in rounds: HGChecklistRounds) -> String? {
        rounds.items.first(where: { $0.status == .inProgress })?.roundId
            ?? rounds.items.first(where: {
                $0.status == .scheduled && (roundDate($0.startsAt).map { $0 >= now } ?? false)
            })?.roundId
            ?? rounds.items.last?.roundId
    }

    private func roundSubtitle(_ round: HGChecklistRoundSummary) -> String {
        switch round.status {
        case .completed:
            if let time = displayTime(round.completedAt.flatMap(roundDate)) {
                return "\(round.totalItems)개 항목 · \(time) 완료"
            }
            return "\(round.totalItems)개 항목 · 완료"
        case .missed:
            return "\(round.checkedItems) / \(round.totalItems) 체크 · 기한 지남"
        case .inProgress:
            let endTime = roundDate(round.endsAt)
                .flatMap(displayTime)
                .map { " · \($0)까지" } ?? ""
            return "\(round.checkedItems) / \(round.totalItems) 체크\(endTime)"
        case .scheduled:
            let startTime = roundDate(round.startsAt).flatMap(displayTime) ?? round.roundId
            return "\(startTime)부터 체크할 수 있어요"
        }
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
        case .inProgress, .completed: HGColor.primary
        case .missed: HGColor.error
        }
    }

    private func nodeFill(for status: HGChecklistRoundStatus) -> Color {
        switch status {
        case .scheduled: HGColor.surface
        case .inProgress, .completed, .missed: statusColor(status)
        }
    }

    private func connectorColor(for status: HGChecklistRoundStatus) -> Color {
        switch status {
        case .completed, .inProgress: HGColor.primary
        case .missed: HGColor.error
        case .scheduled: HGColor.homeTimelineLine
        }
    }

    private func roundDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private func displayTime(_ date: Date?) -> String? {
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "HH시"
        return formatter.string(from: date)
    }

    private func displayClock(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(HGFont.regular(13, relativeTo: .subheadline))
            .foregroundStyle(HGColor.secondaryText)
            .frame(maxWidth: .infinity, minHeight: 88)
            .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    @MainActor
    private func loadRounds() async {
        isLoading = true
        do {
            let fetchedRounds = try await service.fetchRounds()
            rounds = fetchedRounds
            if let selectedRoundID,
               fetchedRounds.items.contains(where: { $0.roundId == selectedRoundID }) == false {
                self.selectedRoundID = preferredRoundID(in: fetchedRounds)
            } else if selectedRoundID == nil {
                selectedRoundID = preferredRoundID(in: fetchedRounds)
            }
            error = nil
        } catch is CancellationError {
            return
        } catch {
            self.error = HGChecklistAPIErrorPresentation.make(from: error)
        }
        isLoading = false
    }

    @MainActor
    private func refreshRounds() async {
        guard let rounds else { return }
        do {
            let refreshedRounds = try await service.fetchRounds(date: rounds.date)
            let previousSelection = selectedRoundID
            let previousStatus = rounds.items.first(where: { $0.roundId == previousSelection })?.status
            self.rounds = refreshedRounds

            guard let previousSelection,
                  let refreshedRound = refreshedRounds.items.first(where: { $0.roundId == previousSelection }) else {
                selectedRoundID = preferredRoundID(in: refreshedRounds)
                return
            }

            if previousStatus == .inProgress || previousStatus == .scheduled,
               refreshedRound.status == .missed || refreshedRound.status == .completed {
                let laterRounds = refreshedRounds.items.filter {
                    (roundDate($0.startsAt) ?? .distantPast) > (roundDate(refreshedRound.startsAt) ?? .distantPast)
                }
                selectedRoundID = laterRounds.first(where: { $0.status == .inProgress })?.roundId
                    ?? laterRounds.first(where: { $0.status == .scheduled })?.roundId
                    ?? preferredRoundID(in: refreshedRounds)
            } else {
                selectedRoundID = previousSelection
            }
        } catch is CancellationError {
            return
        } catch {
            // Retain the last successful server timeline; a later poll retries.
        }
    }
}
