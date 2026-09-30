import SwiftUI

struct InquiryView: View {
    @State private var title = ""
    @State private var content = ""
    @State private var inquiries: [HGInquirySummary] = []
    @State private var selectedStatus: HGInquiryStatus?
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var nextCursor: String?
    @State private var hasMore = false
    @State private var listRequestID = UUID()
    @State private var failedToLoadMore = false
    @State private var isSubmitting = false
    @State private var error: HGErrorPresentation?
    @State private var isComplete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                inquiryForm
                inquiryList
            }
            .padding(24)
        }
        .background(HGColor.appBackground)
        .navigationTitle("문의하기")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadInquiries() }
        .alert(error?.title ?? "문의 오류", isPresented: errorAlert) {
            Button("다시 시도") {
                Task {
                    if failedToLoadMore { await loadMoreInquiries() }
                    else { await loadInquiries() }
                }
            }
            Button("확인", role: .cancel) {}
        } message: { Text(error?.alertMessage ?? "") }
        .alert("문의가 등록되었습니다.", isPresented: $isComplete) {
            Button("확인", role: .cancel) {}
        }
        .dismissKeyboardOnBackgroundTap()
    }

    private var inquiryForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            HGTextField(title: "제목", placeholder: "제목을 입력해주세요", text: $title, fieldHeight: 48)
            VStack(alignment: .leading, spacing: 8) {
                Text("내용")
                    .font(HGFont.semiBold(13, relativeTo: .caption))
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $content)
                        .font(HGFont.regular(14))
                        .scrollContentBackground(.hidden)
                    if content.isEmpty {
                        Text("궁금한 점이나 불편한 점을 자세히 적어주세요")
                            .font(HGFont.regular(14))
                            .foregroundStyle(HGColor.secondaryText)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
                .padding(12)
                .frame(height: 140)
                .background(HGColor.fieldBackground, in: RoundedRectangle(cornerRadius: 12))
                Text("답변은 아래 문의 목록에서 확인할 수 있어요")
                    .font(HGFont.regular(11, relativeTo: .caption2))
                    .foregroundStyle(HGColor.secondaryText)
            }
            HGPrimaryButton(
                title: isSubmitting ? "등록 중..." : "문의 등록",
                isEnabled: isFormValid && !isSubmitting
            ) {
                Task { await submitInquiry() }
            }
        }
    }

    private var inquiryList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("내 문의 목록")
                    .font(HGFont.bold(16, relativeTo: .headline))
                Spacer()
                Text(hasMore ? "\(inquiries.count)건 이상" : "\(inquiries.count)건")
                    .font(HGFont.regular(12, relativeTo: .caption))
                    .foregroundStyle(HGColor.secondaryText)
            }

            statusSelector

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else if inquiries.isEmpty {
                Text("등록한 문의가 없어요.")
                    .font(HGFont.regular(12, relativeTo: .caption))
                    .foregroundStyle(HGColor.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 16))
            } else {
                VStack(spacing: 0) {
                    ForEach(inquiries) { inquiry in
                        NavigationLink {
                            InquiryDetailView(inquiryID: inquiry.id)
                        } label: {
                            InquiryRow(inquiry: inquiry)
                        }
                        .buttonStyle(.plain)

                        if inquiry.id != inquiries.last?.id {
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

    private var statusSelector: some View {
        HStack(spacing: 8) {
            InquiryStatusChip(title: "전체", isSelected: selectedStatus == nil) {
                selectedStatus = nil
                Task { await loadInquiries() }
            }
            ForEach(HGInquiryStatus.allCases) { status in
                InquiryStatusChip(title: status.title, isSelected: selectedStatus == status) {
                    selectedStatus = status
                    Task { await loadInquiries() }
                }
            }
            Spacer()
        }
    }

    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
            let page = try await HGInquiryService().fetchInquiries(status: selectedStatus)
            guard listRequestID == requestID else { return }
            inquiries = page.items
            nextCursor = page.page.nextCursor
            hasMore = page.page.hasMore && page.page.nextCursor != nil
            failedToLoadMore = false
            error = nil
        } catch {
            guard listRequestID == requestID else { return }
            failedToLoadMore = true
            self.error = HGErrorPresentation(error: error)
        }
    }

    @MainActor
    private func loadMoreInquiries() async {
        guard !isLoadingMore, hasMore, let nextCursor else { return }
        let requestID = listRequestID
        let status = selectedStatus
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await HGInquiryService().fetchInquiries(status: status, cursor: nextCursor)
            guard listRequestID == requestID else { return }
            let existingIDs = Set(inquiries.map(\.inquiryID))
            inquiries.append(contentsOf: page.items.filter { !existingIDs.contains($0.inquiryID) })
            self.nextCursor = page.page.nextCursor
            hasMore = page.page.hasMore && page.page.nextCursor != nil
            error = nil
        } catch {
            guard listRequestID == requestID else { return }
            self.error = HGErrorPresentation(error: error)
        }
    }

    @MainActor
    private func submitInquiry() async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            _ = try await HGInquiryService().createInquiry(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                content: content.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            title = ""
            content = ""
            isComplete = true
            await loadInquiries()
        } catch {
            failedToLoadMore = false
            self.error = HGErrorPresentation(error: error)
        }
    }
}

private struct InquiryStatusChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(HGFont.medium(11, relativeTo: .caption))
                .foregroundStyle(isSelected ? .white : HGColor.secondaryText)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(isSelected ? HGColor.primary : HGColor.surface, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct InquiryRow: View {
    let inquiry: HGInquirySummary

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(inquiry.status.title)
                    .font(HGFont.medium(10, relativeTo: .caption2))
                    .foregroundStyle(inquiry.status == .answered ? HGColor.primary : HGColor.secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(HGColor.homeMetricIconBackground, in: Capsule())
                Text(inquiry.title)
                    .font(HGFont.medium(13, relativeTo: .subheadline))
                    .foregroundStyle(HGColor.primaryText)
                Text(inquiry.createdAt.formattedInquiryDate)
                    .font(HGFont.regular(11, relativeTo: .caption2))
                    .foregroundStyle(HGColor.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(HGColor.homeChevron)
        }
        .padding(16)
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
                ScrollView {
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
                }
            } else {
                ContentUnavailableView("문의 정보를 불러올 수 없습니다", systemImage: "exclamationmark.bubble")
            }
        }
        .background(HGColor.appBackground)
        .navigationTitle("문의 상세")
        .navigationBarTitleDisplayMode(.inline)
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
        guard let date = hgISO8601Date else { return self }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }
}
