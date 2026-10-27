import SwiftUI

struct ChecklistOverviewView: View {
    let times: [String]
    let checkedCount: Int?
    let totalCount: Int?
    let siteName: String?
    let teamName: String?
    let onOpenChecklist: () -> Void

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

    private var location: String {
        [siteName, teamName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    summaryCard

                    VStack(alignment: .leading, spacing: 12) {
                        Text("오늘 체크 시간")
                            .font(HGFont.bold(17, relativeTo: .headline))
                            .foregroundStyle(HGColor.primaryText)

                        if times.isEmpty {
                            Text("체크 시간이 설정되지 않았어요.")
                                .font(HGFont.regular(14, relativeTo: .subheadline))
                                .foregroundStyle(HGColor.secondaryText)
                                .frame(maxWidth: .infinity, minHeight: 88)
                                .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 14))
                        } else {
                            VStack(spacing: 8) {
                                ForEach(Array(times.enumerated()), id: \.offset) { _, time in
                                    timeRow(time, isActive: displayTime(time) == activeTime)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 22)
                .padding(.bottom, 24)
            }

            HGPrimaryButton(title: "체크리스트 확인", action: onOpenChecklist)
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .background(HGColor.appBackground)
        }
        .background(HGColor.appBackground.ignoresSafeArea())
        .hgRouteNavigationHeader(title: "체크리스트")
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(summaryContext)
                        .font(HGFont.medium(12, relativeTo: .caption))
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if !location.isEmpty {
                        Text(location)
                            .font(HGFont.regular(11, relativeTo: .caption2))
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(checkedCount.map(String.init) ?? "—")
                            .font(HGFont.bold(34, relativeTo: .largeTitle))
                            .foregroundStyle(.white)
                        Text("/ \(totalCount.map(String.init) ?? "—")개 항목 완료")
                            .font(HGFont.medium(16, relativeTo: .headline))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                Spacer(minLength: 8)
                progressRing
            }

            Spacer(minLength: 0)

            HStack(spacing: 0) {
                stat(title: "완료", value: checkedCount.map(String.init) ?? "—")
                statDivider
                stat(title: "미완료", value: remainingCount.map(String.init) ?? "—")
                statDivider
                stat(title: "전체", value: totalCount.map(String.init) ?? "—")
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
                colors: [
                    Color(red: 0.247, green: 0.576, blue: 0.969),
                    Color(red: 0.110, green: 0.384, blue: 0.839)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22)
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
        .frame(width: 64, height: 64)
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

    private func timeRow(_ rawTime: String, isActive: Bool) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(isActive ? HGColor.primary : HGColor.homeTimelineBorder, lineWidth: 2)
                    .frame(width: 20, height: 20)
                if isActive {
                    Circle()
                        .fill(HGColor.primary)
                        .frame(width: 10, height: 10)
                }
            }
            .frame(width: 24)

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(displayTime(rawTime))
                        .font(HGFont.bold(15, relativeTo: .subheadline))
                        .foregroundStyle(HGColor.primaryText)
                    Text(isActive ? "다음 체크 시간" : "설정된 체크 시간")
                        .font(HGFont.regular(12, relativeTo: .caption))
                        .foregroundStyle(HGColor.secondaryText)
                }
                Spacer(minLength: 4)
                if isActive {
                    Text("다음")
                        .font(HGFont.medium(11, relativeTo: .caption))
                        .foregroundStyle(HGColor.primary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(HGColor.photoSelectionBackground, in: Capsule())
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(HGColor.homeChevron)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isActive ? HGColor.primary : .clear, lineWidth: 1.5)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpenChecklist)
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
            onOpenChecklist: {}
        )
    }
}
