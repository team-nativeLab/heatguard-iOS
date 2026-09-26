import SwiftUI

struct InquiryView: View {
    @State private var title = ""
    @State private var content = ""
    private let inquiries: [InquiryItem] = []
    @State private var showsUnsupportedMessage = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HGTextField(title: "제목", placeholder: "제목을 입력해주세요", text: $title, fieldHeight: 48)
                VStack(alignment: .leading, spacing: 8) {
                    Text("내용").font(HGFont.semiBold(13, relativeTo: .caption))
                    TextEditor(text: $content).font(HGFont.regular(14)).padding(12).frame(height: 140).scrollContentBackground(.hidden).background(HGColor.fieldBackground, in: RoundedRectangle(cornerRadius: 12))
                    Text("답변은 등록한 이메일과 아래 목록에서 확인할 수 있어요").font(HGFont.regular(11, relativeTo: .caption2)).foregroundStyle(HGColor.secondaryText)
                }
                HGPrimaryButton(title: "문의 등록", isEnabled: !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) { submitInquiry() }
                HStack { Text("내 문의 목록").font(HGFont.bold(16, relativeTo: .headline)); Spacer(); Text("\(inquiries.count)건").font(HGFont.regular(12, relativeTo: .caption)).foregroundStyle(HGColor.secondaryText) }
                if inquiries.isEmpty {
                    Text("문의 내역 API가 준비되면 등록한 문의를 확인할 수 있어요.")
                        .font(HGFont.regular(12, relativeTo: .caption))
                        .foregroundStyle(HGColor.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 16))
                } else {
                    VStack(spacing: 0) { ForEach(inquiries) { inquiry in InquiryRow(item: inquiry); if inquiry.id != inquiries.last?.id { Divider().padding(.leading, 16) } } }.background(HGColor.surface, in: RoundedRectangle(cornerRadius: 16))
                }
            }.padding(24)
        }
        .background(HGColor.appBackground).navigationTitle("문의하기").navigationBarTitleDisplayMode(.inline)
        .alert("문의 기능을 준비 중입니다.", isPresented: $showsUnsupportedMessage) { Button("확인", role: .cancel) {} } message: { Text("작업자 문의 등록·조회 API가 제공되면 문의를 보낼 수 있어요.") }
        .dismissKeyboardOnBackgroundTap().keyboardDismissToolbar()
    }
    private func submitInquiry() { showsUnsupportedMessage = true }
}
private struct InquiryItem: Identifiable { let id = UUID(); let title: String; let date: String; let isAnswered: Bool }
private struct InquiryRow: View { let item: InquiryItem; var body: some View { HStack { VStack(alignment: .leading, spacing: 5) { HStack(spacing: 6) { Text(item.isAnswered ? "답변 완료" : "답변 대기").font(HGFont.medium(10, relativeTo: .caption2)).foregroundStyle(item.isAnswered ? HGColor.primary : HGColor.secondaryText).padding(.horizontal, 8).padding(.vertical, 4).background(HGColor.homeMetricIconBackground, in: Capsule()); Text(item.title).font(HGFont.medium(13, relativeTo: .subheadline)) }; Text(item.date).font(HGFont.regular(11, relativeTo: .caption2)).foregroundStyle(HGColor.secondaryText) }; Spacer(); Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(HGColor.homeChevron) }.padding(16) } }
