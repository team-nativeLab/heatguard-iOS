import SwiftUI

struct ChecklistOverviewView: View {
    let siteName: String?
    let teamName: String?
    let onOpenChecklist: (String, String) -> Void

    @State private var rounds: HGChecklistRounds?
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
        [siteName, teamName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private var scheduleCaption: String {
        guard let rounds, rounds.items.count > 1 else { return "회차별 체크" }
        let minutes = rounds.items.compactMap { round -> Int? in
            let parts = round.roundId.split(separator: ":")
            guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else { return nil }
            return hour * 60 + minute
        }.sorted()
        let intervals = Set(zip(minutes, minutes.dropFirst()).map { $1 - $0 })
        guard intervals.count == 1, let interval = intervals.first, interval > 0, interval % 60 == 0 else {
            return "회차별 체크"
        }
        return "\(interval / 60)시간마다 체크"
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    summaryCard

                    HStack {
                        Text("오늘 회차")
                            .font(HGFont.bold(17, relativeTo: .headline))
                            .foregroundStyle(HGColor.primaryText)
                        Spacer()
                        Text(scheduleCaption)
                            .font(HGFont.regular(11, relativeTo: .caption))
                            .foregroundStyle(HGColor.secondaryText)
                    }

                    if isLoading && rounds == nil {
                        ProgressView("회차 정보를 불러오는 중...")
                            .tint(HGColor.primary)
                            .frame(maxWidth: .infinity, minHeight: 120)
                    } else if let rounds, rounds.items.isEmpty {
                        emptyState("오늘 예정된 체크 회차가 없습니다.")
                    } else if let rounds {
                        VStack(spacing: 8) {
                            ForEach(Array(rounds.items.enumerated()), id: \.element.id) { index, round in
                                roundRow(round, date: rounds.date, isLast: index == rounds.items.count - 1)
                            }
                        }
                    } else if error != nil {
                        emptyState("회차 정보를 불러오지 못했습니다.")
                        Button("다시 시도") { Task { await loadRounds() } }
                            .font(HGFont.semiBold(13, relativeTo: .caption))
                            .foregroundStyle(HGColor.primary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 22)
                .padding(.bottom, 24)
            }
        }
        .background(HGColor.appBackground.ignoresSafeArea())
        .hgRouteNavigationHeader(title: "체크리스트")
        .task { await loadRounds() }
        .onAppear {
            if rounds != nil { Task { await loadRounds() } }
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

    private var summaryCard: some View {
        let summary = rounds?.summary
        let progress = CGFloat(summary?.progressPercent ?? 0) / 100
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(location.isEmpty ? dateContext : "\(dateContext) · \(location)")
                        .font(HGFont.medium(10, relativeTo: .caption))
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(summary.map { String($0.completedRounds) } ?? "—")
                            .font(HGFont.bold(34, relativeTo: .largeTitle))
                            .foregroundStyle(.white)
                        Text("/ \(summary.map { String($0.totalRounds) } ?? "—")회차 완료")
                            .font(HGFont.medium(16, relativeTo: .headline))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                Spacer(minLength: 8)
                ZStack {
                    Circle().stroke(.white.opacity(0.28), lineWidth: 5)
                    Circle().trim(from: 0, to: progress)
                        .stroke(.white, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(summary.map { "\($0.progressPercent)%" } ?? "—")
                        .font(HGFont.bold(12, relativeTo: .caption))
                        .foregroundStyle(.white)
                }
                .frame(width: 64, height: 64)
            }
            Spacer(minLength: 0)
            HStack(spacing: 0) {
                stat(title: "완료", value: summary.map { String($0.completedRounds) } ?? "—")
                statDivider
                stat(title: "미완료", value: summary.map { String($0.missedRounds) } ?? "—")
                statDivider
                stat(title: "남은 회차", value: summary.map { String($0.remainingRounds) } ?? "—")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 168)
        .background(
            LinearGradient(
                colors: [Color(red: 0.247, green: 0.576, blue: 0.969), Color(red: 0.110, green: 0.384, blue: 0.839)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22)
        )
        .shadow(color: HGColor.primary.opacity(0.22), radius: 12, y: 8)
    }

    private var dateContext: String {
        guard let date = rounds?.date else { return "오늘" }
        let parts = date.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else { return date }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        components.timeZone = HGDateFormatting.timeZone
        guard let dateValue = HGDateFormatting.calendar.date(from: components) else { return date }
        return HGDateFormatting.string(from: dateValue, format: "M월 d일 (E)")
    }

    private func roundRow(_ round: HGChecklistRoundSummary, date: String, isLast: Bool) -> some View {
        Button { onOpenChecklist(round.roundId, date) } label: {
            HStack(spacing: 8) {
                VStack(spacing: 0) {
                    statusIcon(round.status)
                        .frame(width: 20, height: 20)
                    if !isLast {
                        Rectangle()
                            .fill(HGColor.homeTimelineLine)
                            .frame(width: 1)
                            .frame(maxHeight: .infinity)
                    }
                }
                .frame(width: 24, height: 58)

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(HGDateFormatting.time(round.startsAt))
                            .font(HGFont.bold(15, relativeTo: .subheadline))
                            .foregroundStyle(HGColor.primaryText)
                        Spacer()
                        Text(statusText(round.status))
                            .font(HGFont.medium(10, relativeTo: .caption2))
                            .foregroundStyle(statusColor(round.status))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(statusColor(round.status).opacity(0.10), in: Capsule())
                    }
                    Text(roundSubtitle(round))
                        .font(HGFont.regular(10, relativeTo: .caption2))
                        .foregroundStyle(round.status == .missed ? HGColor.error : HGColor.secondaryText)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(HGColor.homeChevron)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(round.status == .inProgress ? HGColor.primary : .clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
    }

    private func roundSubtitle(_ round: HGChecklistRoundSummary) -> String {
        let counts = "\(round.checkedItems) / \(round.totalItems) 체크"
        switch round.status {
        case .completed:
            guard let completedAt = round.completedAt else { return "\(round.totalItems)개 항목 · 완료" }
            return "\(round.totalItems)개 항목 · \(HGDateFormatting.time(completedAt)) 완료"
        case .missed:
            return "\(counts) · 기한 지남"
        case .inProgress:
            return "\(counts) · \(HGDateFormatting.time(round.endsAt))까지"
        case .scheduled:
            return "\(HGDateFormatting.time(round.startsAt))부터 체크할 수 있어요"
        }
    }

    @ViewBuilder
    private func statusIcon(_ status: HGChecklistRoundStatus) -> some View {
        switch status {
        case .completed:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(HGColor.checklistSuccess)
        case .missed:
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(HGColor.error)
        case .inProgress:
            Image(systemName: "circle.inset.filled").foregroundStyle(HGColor.primary)
        case .scheduled:
            Image(systemName: "circle").foregroundStyle(HGColor.homeTimelineBorder)
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
        case .inProgress: HGColor.primary
        case .completed: HGColor.checklistSuccess
        case .missed: HGColor.error
        }
    }

    private func stat(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(HGFont.bold(16, relativeTo: .headline)).foregroundStyle(.white)
            Text(title).font(HGFont.regular(11, relativeTo: .caption2)).foregroundStyle(.white.opacity(0.78))
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle().fill(.white.opacity(0.2)).frame(width: 1, height: 24)
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
            rounds = try await service.fetchRounds()
            error = nil
        } catch is CancellationError {
            return
        } catch {
            self.error = HGChecklistAPIErrorPresentation.make(from: error)
        }
        isLoading = false
    }
}
