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
                            VStack(spacing: 0) {
                                ForEach(Array(times.enumerated()), id: \.offset) { index, time in
                                    timeRow(time, isFirst: index == 0, isLast: index == times.count - 1)
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
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(Date.now.formatted(.dateTime.month(.abbreviated).day()).replacingOccurrences(of: ".", with: "") + " 오늘")
                        .font(HGFont.medium(13, relativeTo: .caption))
                        .foregroundStyle(.white.opacity(0.82))
                    Text("오늘의 체크리스트")
                        .font(HGFont.bold(18, relativeTo: .title3))
                        .foregroundStyle(.white)
                    let location = [siteName, teamName]
                        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                        .joined(separator: " · ")
                    if !location.isEmpty {
                        Text(location)
                            .font(HGFont.regular(12, relativeTo: .caption))
                            .foregroundStyle(.white.opacity(0.82))
                    }
                }
                Spacer()
                progressRing
            }

            HStack(spacing: 0) {
                stat(title: "완료", value: checkedCount.map(String.init) ?? "—")
                Spacer(minLength: 8)
                stat(title: "전체 항목", value: totalCount.map(String.init) ?? "—")
                Spacer(minLength: 8)
                stat(title: "남은 항목", value: remainingCount.map(String.init) ?? "—")
            }
            .padding(.top, 2)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [HGColor.primary, HGColor.primary.opacity(0.78)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18)
        )
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
        .frame(width: 48, height: 48)
        .accessibilityLabel("오늘 체크 항목 진행률")
    }

    private var remainingCount: Int? {
        guard let checkedCount, let totalCount else { return nil }
        return max(totalCount - checkedCount, 0)
    }

    private func stat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(HGFont.regular(11, relativeTo: .caption2))
                .foregroundStyle(.white.opacity(0.78))
            Text(value)
                .font(HGFont.bold(17, relativeTo: .headline))
                .foregroundStyle(.white)
        }
    }

    private func timeRow(_ rawTime: String, isFirst: Bool, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Circle().fill(HGColor.primary).frame(width: 12, height: 12)
                if !isLast {
                    Rectangle().fill(HGColor.homeTimelineLine).frame(width: 2, height: 48)
                }
            }
            .padding(.top, 4)

            VStack(alignment: .leading, spacing: 5) {
                Text(String(rawTime.trimmingCharacters(in: .whitespacesAndNewlines).prefix(5)))
                    .font(HGFont.bold(15, relativeTo: .subheadline))
                    .foregroundStyle(HGColor.primaryText)
                Text("오늘 체크 항목")
                    .font(HGFont.regular(12, relativeTo: .caption))
                    .foregroundStyle(HGColor.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(HGColor.homeChevron)
                .padding(.top, 6)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HGColor.surface, in: UnevenRoundedRectangle(
            topLeadingRadius: isFirst ? 14 : 0,
            bottomLeadingRadius: isLast ? 14 : 0,
            bottomTrailingRadius: isLast ? 14 : 0,
            topTrailingRadius: isFirst ? 14 : 0
        ))
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpenChecklist)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
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
