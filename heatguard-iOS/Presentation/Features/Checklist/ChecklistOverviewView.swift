import SwiftUI

struct ChecklistOverviewView: View {
    let times: [String]
    let checkedCount: Int?
    let totalCount: Int?
    let siteName: String?
    let teamName: String?
    let onOpenChecklist: (String?) -> Void

    private var progress: CGFloat {
        guard let checkedCount, let totalCount, totalCount > 0 else { return 0 }
        return CGFloat(checkedCount) / CGFloat(totalCount)
    }

    private var activeTime: String? {
        let scheduled = times.compactMap { time -> (String, Int)? in
            let parts = time.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":")
            guard parts.count >= 2,
                  let hour = Int(parts[0]),
                  let minute = Int(parts[1]),
                  (0..<24).contains(hour),
                  (0..<60).contains(minute) else { return nil }
            return (displayTime(time), hour * 60 + minute)
        }
        .sorted { $0.1 < $1.1 }

        guard !scheduled.isEmpty else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        let now = calendar.dateComponents([.hour, .minute], from: Date())
        let currentMinute = (now.hour ?? 0) * 60 + (now.minute ?? 0)
        return scheduled.first(where: { $0.1 >= currentMinute })?.0
    }

    private func hasPassed(_ rawTime: String) -> Bool {
        let parts = rawTime.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":")
        guard parts.count >= 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        let now = calendar.dateComponents([.hour, .minute], from: Date())
        return hour * 60 + minute < (now.hour ?? 0) * 60 + (now.minute ?? 0)
    }

    private var scheduleCaption: String {
        let minutes = times.compactMap { rawTime -> Int? in
            let parts = rawTime.split(separator: ":")
            guard parts.count >= 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else { return nil }
            return hour * 60 + minute
        }.sorted()
        let intervals = Set(zip(minutes, minutes.dropFirst()).map { $1 - $0 })
        guard intervals.count == 1, let interval = intervals.first, interval > 0, interval % 60 == 0 else {
            return "설정된 시간에 체크"
        }
        return "\(interval / 60)시간마다 체크"
    }

    private var location: String {
        [siteName, teamName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    summaryCard

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("오늘 회차")
                                .font(HGFont.bold(17, relativeTo: .headline))
                                .foregroundStyle(HGColor.primaryText)
                            Spacer()
                            Text(scheduleCaption)
                                .font(HGFont.regular(10, relativeTo: .caption))
                                .foregroundStyle(HGColor.secondaryText)
                        }

                        if times.isEmpty {
                            Text("체크 시간이 설정되지 않았어요.")
                                .font(HGFont.regular(14, relativeTo: .subheadline))
                                .foregroundStyle(HGColor.secondaryText)
                                .frame(maxWidth: .infinity, minHeight: 88)
                                .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 14))
                        } else {
                            VStack(spacing: 8) {
                                ForEach(Array(times.enumerated()), id: \.offset) { _, time in
                                    timeRow(time, isActive: displayTime(time) == activeTime, isPast: hasPassed(time))
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }

        }
        .background(HGColor.appBackground.ignoresSafeArea())
        .hgRouteNavigationHeader(title: "체크리스트")
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(location.isEmpty ? summaryContext : "\(summaryContext) · \(location)")
                        .font(HGFont.medium(10, relativeTo: .caption))
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(checkedCount.map(String.init) ?? "—")
                            .font(HGFont.bold(28, relativeTo: .largeTitle))
                            .foregroundStyle(.white)
                        Text("/ \(totalCount.map(String.init) ?? "—")개 항목 완료")
                            .font(HGFont.medium(12, relativeTo: .headline))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                Spacer(minLength: 8)
                progressRing
            }

            Spacer(minLength: 0)

            HStack(spacing: 0) {
                stat(title: "완료 항목", value: checkedCount.map(String.init) ?? "—")
                statDivider
                stat(title: "남은 항목", value: remainingCount.map(String.init) ?? "—")
                statDivider
                stat(title: "전체 항목", value: totalCount.map(String.init) ?? "—")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 112)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.247, green: 0.576, blue: 0.969),
                    Color(red: 0.110, green: 0.384, blue: 0.839)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18)
        )
        .shadow(color: HGColor.primary.opacity(0.22), radius: 12, y: 8)
    }

    private var progressRing: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.28), lineWidth: 5)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(.white, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(totalCount.map { total in total == 0 ? "0%" : "\(Int(progress * 100))%" } ?? "—")
                .font(HGFont.bold(12, relativeTo: .caption))
                .foregroundStyle(.white)
        }
        .frame(width: 46, height: 46)
        .accessibilityLabel("오늘 체크 항목 진행률")
    }

    private var summaryContext: String {
        let date = Date.now.formatted(.dateTime.locale(Locale(identifier: "ko_KR")).month(.defaultDigits).day())
        let weekday = Date.now.formatted(
            .dateTime.locale(Locale(identifier: "ko_KR")).weekday(.abbreviated)
        )
        return "\(date) (\(weekday))"
    }

    private var remainingCount: Int? {
        guard let checkedCount, let totalCount else { return nil }
        return max(totalCount - checkedCount, 0)
    }

    private func stat(title: String, value: String) -> some View {
        VStack(alignment: .center, spacing: 2) {
            Text(title)
                .font(HGFont.regular(11, relativeTo: .caption2))
                .foregroundStyle(.white.opacity(0.78))
            Text(value)
                .font(HGFont.bold(16, relativeTo: .headline))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.2))
            .frame(width: 1, height: 24)
    }

    private func timeRow(_ rawTime: String, isActive: Bool, isPast: Bool) -> some View {
        Button {
            onOpenChecklist(displayTime(rawTime))
        } label: {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isActive ? HGColor.primary : HGColor.surface)
                    .stroke(isActive ? HGColor.primary : HGColor.homeTimelineBorder, lineWidth: 1.5)
                    .frame(width: 15, height: 15)
                if isActive {
                    Circle()
                        .fill(.white)
                        .frame(width: 5, height: 5)
                }
            }
            .frame(width: 20)

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(displayTime(rawTime))
                        .font(HGFont.bold(12, relativeTo: .subheadline))
                        .foregroundStyle(HGColor.primaryText)
                    Text(isPast ? "회차별 결과를 불러올 수 없어요" : "시간을 눌러 체크 항목을 확인하세요")
                        .font(HGFont.regular(9, relativeTo: .caption))
                        .foregroundStyle(HGColor.secondaryText)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Text(isActive ? "다음" : (isPast ? "상태 미제공" : "예정"))
                    .font(HGFont.medium(9, relativeTo: .caption))
                    .foregroundStyle(isActive ? HGColor.primary : HGColor.secondaryText)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(isActive ? HGColor.photoSelectionBackground : HGColor.appBackground, in: Capsule())
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(HGColor.homeChevron)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isActive ? HGColor.primary : .clear, lineWidth: 1)
            }
        }
        .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private func displayTime(_ rawTime: String) -> String {
        let parts = rawTime.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":")
        guard parts.count >= 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0..<24).contains(hour),
              (0..<60).contains(minute) else { return rawTime }
        if minute == 0 { return String(format: "%02d시", hour) }
        return String(format: "%02d:%02d", hour, minute)
    }

}

#Preview {
    NavigationStack {
        ChecklistOverviewView(
            times: ["08:00", "10:00", "12:00", "14:00"],
            checkedCount: 4,
            totalCount: 8,
            siteName: "A 건설현장",
            teamName: "작업팀",
            onOpenChecklist: { _ in }
        )
    }
}
