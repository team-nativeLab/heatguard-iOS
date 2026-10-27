import SwiftUI

struct InquiryView: View {
    @State private var inquiries: [HGInquirySummary] = []
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var nextCursor: String?
    @State private var hasMore = false
    @State private var listRequestID = UUID()
    @State private var failedToLoadMore = false
    @State private var error: HGErrorPresentation?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("등록한 문의와 답변을 여기서 확인할 수 있어요")
                    .font(HGFont.regular(14))
                    .foregroundStyle(HGColor.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("내 문의 목록")
                            .font(HGFont.bold(16, relativeTo: .headline))
                            .foregroundStyle(HGColor.primaryText)
                        Spacer()
                        Text("\(inquiries.count)건")
                            .font(HGFont.regular(12, relativeTo: .caption))
                            .foregroundStyle(HGColor.secondaryText)
                    }

                    if isLoading {
                        VStack(spacing: 0) {
                            ForEach(0..<3, id: \.self) { index in
                                InquiryLoadingRow()
                                if index < 2 { Divider().padding(.leading, 16) }
                            }
                        }
                        .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 16))
                        .accessibilityLabel("문의 목록을 불러오는 중")
                    } else if inquiries.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "bubble.left")
                                .font(.system(size: 24, weight: .regular))
                                .foregroundStyle(HGColor.secondaryText)
                            Text("등록한 문의가 없어요")
                                .font(HGFont.medium(14))
                                .foregroundStyle(HGColor.secondaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 16))
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(inquiries.enumerated()), id: \.element.id) { index, inquiry in
                                NavigationLink {
                                    InquiryDetailView(inquiryID: inquiry.id)
                                } label: {
                                    InquiryRow(inquiry: inquiry)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("inquiry.list.row.\(inquiry.id)")

                                if index < inquiries.count - 1 {
                                    Divider().padding(.leading, 16)
                                }
                            }
                        }
                        .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 16))
                    }

                    if !isLoading && hasMore {
                        Button {
                            Task { await loadMoreInquiries() }
                        } label: {
                            HStack(spacing: 8) {
                                if isLoadingMore { ProgressView() }
                                Text(isLoadingMore ? "불러오는 중..." : "더 보기")
                            }
                            .font(HGFont.medium(13, relativeTo: .subheadline))
                            .foregroundStyle(HGColor.primary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .disabled(isLoadingMore)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .background(HGColor.appBackground)
        .scrollContentBackground(.hidden)
        .hgNavigationTitle("문의하기")
        .task { await loadInquiries() }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            NavigationLink {
                InquiryRegistrationView(onRegistered: { Task { await loadInquiries() } })
            } label: {
                Text("문의 등록하기")
                    .font(HGFont.medium(16))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: HGLayout.primaryButtonHeight)
                    .background(HGColor.primary, in: RoundedRectangle(cornerRadius: HGLayout.primaryButtonCornerRadius))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("inquiry.list.register")
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .background(HGColor.appBackground)
        }
        .alert(error?.title ?? "문의 오류", isPresented: errorAlert) {
            Button("다시 시도") {
                Task {
                    if failedToLoadMore { await loadMoreInquiries() } else { await loadInquiries() }
                }
            }
            Button("확인", role: .cancel) {}
        } message: {
            Text(error?.alertMessage ?? "")
        }
    }

    private var errorAlert: Binding<Bool> {
        Binding(get: { error != nil }, set: { if !$0 { error = nil } })
    }

    @MainActor
    private func loadInquiries() async {
        let requestID = UUID()
        listRequestID = requestID
        failedToLoadMore = false
        isLoading = true
        defer {
            if listRequestID == requestID { isLoading = false }
        }
        do {
            let page = try await HGInquiryService().fetchInquiries()
            guard listRequestID == requestID else { return }
            inquiries = page.items
            nextCursor = page.page.nextCursor
            hasMore = page.page.hasMore && page.page.nextCursor != nil
            error = nil
        } catch {
            guard listRequestID == requestID else { return }
            self.error = HGErrorPresentation(error: error)
        }
    }

    @MainActor
    private func loadMoreInquiries() async {
        guard !isLoadingMore, hasMore, let nextCursor else { return }
        let requestID = listRequestID
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await HGInquiryService().fetchInquiries(cursor: nextCursor)
            guard listRequestID == requestID else { return }
            let existingIDs = Set(inquiries.map(\.inquiryID))
            inquiries.append(contentsOf: page.items.filter { !existingIDs.contains($0.inquiryID) })
            self.nextCursor = page.page.nextCursor
            hasMore = page.page.hasMore && page.page.nextCursor != nil
            failedToLoadMore = false
            error = nil
        } catch {
            guard listRequestID == requestID else { return }
            failedToLoadMore = true
            self.error = HGErrorPresentation(error: error)
        }
    }
}

private struct InquiryLoadingRow: View {
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                Capsule().fill(HGColor.metricBackground).frame(width: 64, height: 16)
                RoundedRectangle(cornerRadius: 4).fill(HGColor.metricBackground).frame(width: 190, height: 14)
                RoundedRectangle(cornerRadius: 4).fill(HGColor.metricBackground).frame(width: 70, height: 12)
            }
            Spacer()
            Circle().fill(HGColor.metricBackground).frame(width: 10, height: 10)
        }
        .padding(16)
        .accessibilityHidden(true)
    }
}

private struct InquiryRow: View {
    let inquiry: HGInquirySummary

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(inquiry.status.title)
                        .font(HGFont.medium(10, relativeTo: .caption2))
                        .foregroundStyle(inquiry.status == .answered ? HGColor.answered : HGColor.homeHeatLevelText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            inquiry.status == .answered ? HGColor.answered.opacity(0.12) : HGColor.homeHeatLevelText.opacity(0.12),
                            in: Capsule()
                        )
                    Text(inquiry.title)
                        .font(HGFont.bold(13, relativeTo: .subheadline))
                        .foregroundStyle(HGColor.primaryText)
                        .lineLimit(1)
                }
                Text(inquiry.createdAt.formattedInquiryDate)
                    .font(HGFont.regular(11, relativeTo: .caption))
                    .foregroundStyle(HGColor.secondaryText)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(HGColor.homeChevron)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 62)
    }
}

struct InquiryDetailView: View {
    let inquiryID: String
    @State private var inquiry: HGInquiryDetail?
    @State private var isLoading = true
    @State private var error: HGErrorPresentation?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let inquiry {
                List {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(inquiry.status.title)
                            .font(HGFont.medium(11, relativeTo: .caption))
                            .foregroundStyle(HGColor.primary)
                        Text(inquiry.title)
                            .font(HGFont.bold(20, relativeTo: .title2))
                        Text(inquiry.createdAt.formattedInquiryDate)
                            .font(HGFont.regular(12, relativeTo: .caption))
                            .foregroundStyle(HGColor.secondaryText)
                        Divider()
                        Text(inquiry.content)
                            .font(HGFont.regular(14, relativeTo: .body))
                        repliesSection(inquiry.replies)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(HGColor.appBackground)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            } else {
                ContentUnavailableView("문의 정보를 불러올 수 없습니다", systemImage: "exclamationmark.bubble")
            }
        }
        .background(HGColor.appBackground)
        .hgNavigationTitle("문의 상세")
        .task { await loadInquiry() }
        .alert(error?.title ?? "문의 조회 오류", isPresented: errorAlert) {
            Button("다시 시도") { Task { await loadInquiry() } }
            Button("확인", role: .cancel) {}
        } message: { Text(error?.alertMessage ?? "") }
    }

    @ViewBuilder
    private func repliesSection(_ replies: [HGInquiryReply]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("답변")
                .font(HGFont.bold(16, relativeTo: .headline))
            if replies.isEmpty {
                Text("아직 등록된 답변이 없어요.")
                    .font(HGFont.regular(13, relativeTo: .subheadline))
                    .foregroundStyle(HGColor.secondaryText)
            } else {
                ForEach(replies) { reply in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(reply.content)
                            .font(HGFont.regular(14, relativeTo: .body))
                        if let answeredAt = reply.answeredAt {
                            Text(answeredAt.formattedInquiryDate)
                                .font(HGFont.regular(11, relativeTo: .caption2))
                                .foregroundStyle(HGColor.secondaryText)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    private var errorAlert: Binding<Bool> {
        Binding(get: { error != nil }, set: { if !$0 { error = nil } })
    }

    @MainActor
    private func loadInquiry() async {
        isLoading = true
        defer { isLoading = false }
        do {
            inquiry = try await HGInquiryService().fetchInquiry(id: inquiryID)
            error = nil
        } catch {
            self.error = HGErrorPresentation(error: error)
        }
    }
}

private extension String {
    var formattedInquiryDate: String {
        HGDateFormatting.day(self)
    }
}
