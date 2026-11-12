import SwiftUI

struct HomeTimeline: View {
    let rounds: HGChecklistRounds?
    let fallbackTimes: [String]
    let now: Date
    let onOpenRound: (String, String) -> Void

    private var selectedRoundID: String? {
        guard let rounds else { return nil }
        return rounds.items.first(where: { $0.status == .inProgress })?.roundId
            ?? nextScheduledRound?.roundId
            ?? rounds.items.last?.roundId
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
            if rounds?.items.contains(where: { $0.status == .inProgress }) == true {
                return "현재 체크 시간이에요"
            }
            return rounds == nil ? "체크 시간 정보를 불러오는 중" : "오늘 예정된 다음 체크가 없습니다"
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
        VStack(alignment: .leading, spacing: 12) {
            Text(nextCheckCaption)
                .font(HGFont.regular(11, relativeTo: .caption2))
                .foregroundStyle(HGColor.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .accessibilityIdentifier("home.checklist.next-check-caption")

            if let rounds, !rounds.items.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(Array(rounds.items.enumerated()), id: \.element.roundId) { index, round in
                                roundNode(round, date: rounds.date)
                                    .id(round.roundId)

                                if index < rounds.items.count - 1 {
                                    Capsule()
                                        .fill(connectorColor(for: round.status))
                                        .frame(width: 20, height: 2)
                                        .offset(y: -9)
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .frame(height: 50)
                    .onAppear { scrollToSelected(using: proxy, in: rounds) }
                    .onChange(of: selectedRoundID) { _, _ in
                        scrollToSelected(using: proxy, in: rounds)
                    }
                }
            } else if fallbackTimes.isEmpty {
                Text(rounds == nil ? "체크 일정을 불러오는 중..." : "오늘 예정된 체크가 없습니다")
                    .font(HGFont.regular(11, relativeTo: .caption2))
                    .foregroundStyle(HGColor.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                legacyTimeline
            }
        }
    }

    private var legacyTimeline: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(fallbackTimes.enumerated()), id: \.offset) { index, time in
                    VStack(spacing: 7) {
                        Circle()
                            .fill(HGColor.surface)
                            .overlay {
                                Circle().stroke(HGColor.homeTimelineBorder, lineWidth: 1.5)
                            }
                            .frame(width: 12, height: 12)
                        Text(time)
                            .font(HGFont.regular(9, relativeTo: .caption2))
                            .foregroundStyle(HGColor.secondaryText)
                    }
                    .frame(width: 46)

                    if index < fallbackTimes.count - 1 {
                        Capsule().fill(HGColor.homeTimelineLine).frame(width: 20, height: 2).offset(y: -9)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 50)
    }

    private func roundNode(_ round: HGChecklistRoundSummary, date: String) -> some View {
        let isSelected = selectedRoundID == round.roundId
        let color = statusColor(round.status)

        return Button {
            onOpenRound(round.roundId, date)
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
                    } else if round.status == .missed {
                        Image(systemName: "xmark")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                Text(displayTime(roundDate(round.startsAt)) ?? round.roundId)
                    .font(isSelected ? HGFont.bold(11, relativeTo: .caption2) : HGFont.regular(9, relativeTo: .caption2))
                    .foregroundStyle(color)
            }
            .frame(width: 46, height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(displayTime(roundDate(round.startsAt)) ?? round.roundId) \(statusText(round.status))")
    }

    private func scrollToSelected(using proxy: ScrollViewProxy, in rounds: HGChecklistRounds) {
        guard let selectedRoundID,
              rounds.items.contains(where: { $0.roundId == selectedRoundID }) else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            proxy.scrollTo(selectedRoundID, anchor: .center)
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
}
