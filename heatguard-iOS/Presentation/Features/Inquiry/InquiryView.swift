import SwiftUI

struct InquiryView: View {
    @State private var title = ""
    @State private var content = ""
    @State private var inquiries: [InquiryItem] = [
        .init(title: "앱에서 사진 업로드가 안 돼요", date: "2026.09.25", isAnswered: true),
        .init(title: "온도계 기록 수정 요청", date: "2026.09.26", isAnswered: false)
    ]
    @State private var showsSuccess = false

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
                VStack(spacing: 0) { ForEach(inquiries) { inquiry in InquiryRow(item: inquiry); if inquiry.id != inquiries.last?.id { Divider().padding(.leading, 16) } } }.background(HGColor.surface, in: RoundedRectangle(cornerRadius: 16))
            }.padding(24)
        }
        .background(HGColor.appBackground).navigationTitle("문의하기").navigationBarTitleDisplayMode(.inline)
        .alert("문의가 등록되었습니다.", isPresented: $showsSuccess) { Button("확인", role: .cancel) {} } message: { Text("답변을 등록한 이메일과 문의 목록에서 확인할 수 있어요.") }
        .dismissKeyboardOnBackgroundTap().keyboardDismissToolbar()
    }
    private func submitInquiry() { inquiries.insert(.init(title: title, date: Date.now.formatted(.dateTime.year().month().day()), isAnswered: false), at: 0); title = ""; content = ""; showsSuccess = true }
}
private struct InquiryItem: Identifiable { let id = UUID(); let title: String; let date: String; let isAnswered: Bool }
private struct InquiryRow: View { let item: InquiryItem; var body: some View { HStack { VStack(alignment: .leading, spacing: 5) { HStack(spacing: 6) { Text(item.isAnswered ? "답변 완료" : "답변 대기").font(HGFont.medium(10, relativeTo: .caption2)).foregroundStyle(item.isAnswered ? HGColor.primary : HGColor.secondaryText).padding(.horizontal, 8).padding(.vertical, 4).background(HGColor.homeMetricIconBackground, in: Capsule()); Text(item.title).font(HGFont.medium(13, relativeTo: .subheadline)) }; Text(item.date).font(HGFont.regular(11, relativeTo: .caption2)).foregroundStyle(HGColor.secondaryText) }; Spacer(); Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(HGColor.homeChevron) }.padding(16) } }
