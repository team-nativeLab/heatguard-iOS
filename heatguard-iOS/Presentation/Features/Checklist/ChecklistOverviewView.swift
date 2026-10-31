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
        [siteName, teamName].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                summaryCard
                HStack {
                    Text("오늘 회차").font(HGFont.bold(17, relativeTo: .headline)).foregroundStyle(HGColor.primaryText)
                    Spacer()
                    Text(rounds.map { "총 \($0.summary.totalRounds)회차" } ?? "회차 정보를 불러오는 중")
                        .font(HGFont.regular(11, relativeTo: .caption)).foregroundStyle(HGColor.secondaryText)
                }
                if isLoading && rounds == nil {
                    ProgressView("회차 정보를 불러오는 중...").tint(HGColor.primary)
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else if let rounds, rounds.items.isEmpty {
                    emptyState("오늘 예정된 체크 회차가 없습니다.")
                } else if let rounds {
                    ZStack(alignment: .leading) {
                        if rounds.items.count > 1 {
                            GeometryReader { geometry in
                                Rectangle()
                                    .fill(HGColor.homeTimelineLine)
                                    .frame(width: 2, height: max(0, geometry.size.height - 78))
                                    .position(x: 13, y: geometry.size.height / 2)
                            }
                            .allowsHitTesting(false)
                        }
                        VStack(spacing: 10) {
                            ForEach(rounds.items) { round in
                                Button { onOpenChecklist(round.roundId, rounds.date) } label: {
                                    HStack(spacing: 12) {
                                        statusIcon(round.status)
                                            .frame(width: 26)
                                        HStack(spacing: 10) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(round.roundId)
                                                    .font(HGFont.bold(17, relativeTo: .subheadline))
                                                    .foregroundStyle(HGColor.primaryText)
                                                Text(roundSubtitle(round))
                                                    .font(HGFont.regular(12, relativeTo: .caption))
                                                    .foregroundStyle(round.status == .missed ? HGColor.error : HGColor.secondaryText)
                                                    .lineLimit(1)
                                                    .minimumScaleFactor(0.8)
                                            }
                                            Spacer(minLength: 4)
                                            Text(statusText(round.status))
                                                .font(HGFont.semiBold(12, relativeTo: .caption))
                                                .foregroundStyle(statusColor(round.status))
                                                .padding(.horizontal, 11)
                                                .padding(.vertical, 5)
                                                .background(statusColor(round.status).opacity(0.10), in: Capsule())
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(HGColor.homeChevron)
                                        }
                                        .padding(.horizontal, 16)
                                        .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
                                        .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 18))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 18)
                                                .stroke(round.status == .inProgress ? HGColor.primary : .clear, lineWidth: 1.5)
                                        }
                                        .shadow(color: HGColor.cardShadow.opacity(0.12), radius: 8, x: 0, y: 3)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.plain)
                                .accessibilityElement(children: .combine)
                                .accessibilityHint("회차별 체크리스트 열기")
                            }
                        }
                    }
                } else {
                    emptyState("회차 정보를 불러오지 못했습니다.")
                    Button("다시 시도") { Task { await loadRounds() } }
                        .font(HGFont.semiBold(13, relativeTo: .caption)).foregroundStyle(HGColor.primary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 24)
        }
        .background(HGColor.appBackground.ignoresSafeArea())
        .hgRouteNavigationHeader(title: "체크리스트")
        .task { await loadRounds() }
        .onAppear { if rounds != nil { Task { await loadRounds() } } }
        .alert(error?.title ?? "체크리스트 오류", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("다시 시도") { Task { await loadRounds() } }
            Button("확인", role: .cancel) {}
        } message: { Text(error?.alertMessage ?? "") }
    }

    private var summaryCard: some View {
        let summary = rounds?.summary
        let progress = min(max(CGFloat(summary?.progressPercent ?? 0) / 100, 0), 1)
        return ZStack {
            GeometryReader { geometry in
                Circle()
                    .fill(.white.opacity(0.055))
                    .frame(width: geometry.size.width * 0.8)
                    .offset(x: -geometry.size.width * 0.34, y: -geometry.size.height * 0.62)
                Circle()
                    .fill(.white.opacity(0.055))
                    .frame(width: geometry.size.width * 0.68)
                    .offset(x: geometry.size.width * 0.58, y: geometry.size.height * 0.46)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(summarySubtitle)
                            .font(HGFont.medium(11, relativeTo: .caption))
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(summary.map { String($0.completedRounds) } ?? "—")
                                .font(HGFont.bold(30, relativeTo: .largeTitle))
                                .foregroundStyle(.white)
                            Text("/ \(summary.map { String($0.totalRounds) } ?? "—")회차 완료")
                                .font(HGFont.medium(13, relativeTo: .headline))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                    Spacer(minLength: 8)
                    ZStack {
                        Circle().stroke(.white.opacity(0.28), lineWidth: 7)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(.white, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text(summary.map { "\($0.progressPercent)%" } ?? "—")
                            .font(HGFont.bold(15, relativeTo: .subheadline))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 76, height: 76)
                }
                Spacer(minLength: 2)
                HStack(spacing: 0) {
                    stat(title: "완료", value: summary.map { String($0.completedRounds) } ?? "—")
                    statDivider
                    stat(title: "미완료", value: summary.map { String($0.missedRounds) } ?? "—")
                    statDivider
                    stat(title: "남은 회차", value: summary.map { String($0.remainingRounds) } ?? "—")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 174)
        .background(
            LinearGradient(
                colors: [Color(red: 0.247, green: 0.576, blue: 0.969), Color(red: 0.110, green: 0.384, blue: 0.839)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: HGColor.primary.opacity(0.22), radius: 12, y: 8)
    }

    private var summarySubtitle: String {
        let date = rounds.map { dateTitle($0.date) } ?? "오늘"
        return [date, location].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func dateTitle(_ value: String) -> String {
        let parser = DateFormatter()
        parser.calendar = Calendar(identifier: .gregorian)
        parser.timeZone = TimeZone(identifier: "Asia/Seoul")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: value) else { return value }
        parser.locale = Locale(identifier: "ko_KR")
        parser.dateFormat = "M월 d일 (E)"
        return parser.string(from: date)
    }

    @ViewBuilder
    private func statusIcon(_ status: HGChecklistRoundStatus) -> some View {
        switch status {
        case .completed, .missed:
            Image(systemName: status == .completed ? "checkmark" : "exclamationmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(statusColor(status), in: Circle())
        case .inProgress:
            Circle()
                .fill(HGColor.primary.opacity(0.18))
                .frame(width: 34, height: 34)
                .overlay {
                    Circle().fill(HGColor.primary).frame(width: 20, height: 20)
                        .overlay { Circle().fill(.white).frame(width: 6, height: 6) }
                }
        case .scheduled:
            Circle()
                .fill(HGColor.surface)
                .frame(width: 22, height: 22)
                .overlay { Circle().stroke(HGColor.homeTimelineBorder, lineWidth: 1.5) }
        }
    }

    private func roundSubtitle(_ round: HGChecklistRoundSummary) -> String {
        switch round.status {
        case .completed:
            if let time = displayTime(round.completedAt) {
                return "\(round.totalItems)개 항목 · \(time) 완료"
            }
            return "\(round.totalItems)개 항목 · 완료"
        case .missed:
            return "\(round.checkedItems) / \(round.totalItems) 체크 · 기한 지남"
        case .inProgress:
            let endTime = displayTime(round.endsAt).map { " · \($0)까지" } ?? ""
            return "\(round.checkedItems) / \(round.totalItems) 체크\(endTime)"
        case .scheduled:
            let startTime = displayTime(round.startsAt) ?? round.roundId
            return "\(startTime)부터 체크할 수 있어요"
        }
    }

    private func displayTime(_ isoDate: String?) -> String? {
        guard let isoDate,
              let timeSeparator = isoDate.firstIndex(of: "T") else { return nil }
        let timeStart = isoDate.index(after: timeSeparator)
        let timeEnd = isoDate.index(timeStart, offsetBy: 5, limitedBy: isoDate.endIndex) ?? isoDate.endIndex
        let value = String(isoDate[timeStart..<timeEnd])
        return value.count == 5 ? value : nil
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
        }.frame(maxWidth: .infinity)
    }

    private var statDivider: some View { Rectangle().fill(.white.opacity(0.2)).frame(width: 1, height: 24) }

    private func emptyState(_ text: String) -> some View {
        Text(text).font(HGFont.regular(13, relativeTo: .subheadline)).foregroundStyle(HGColor.secondaryText)
            .frame(maxWidth: .infinity, minHeight: 88).background(HGColor.surface, in: RoundedRectangle(cornerRadius: 14))
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
