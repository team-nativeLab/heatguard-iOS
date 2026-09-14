import SwiftUI

struct RestPhotoView: View {
    private let restPeriod = "13 : 00 ~ 13 : 30 (중간 휴식)"

    @State private var memo = ""
    @State private var showsSaveConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            header

            VStack(alignment: .leading, spacing: 0) {
                Text("휴식시간 사진")
                    .font(HGFont.bold(20, relativeTo: .title2))

                Text("휴식시간과 휴식 환경을 기록해주세요")
                    .font(HGFont.regular(14, relativeTo: .subheadline))
                    .padding(.top, 10)

                HGPhotoCaptureSection()
                    .padding(.top, 34)

                restForm
                    .padding(.top, 26)
            }
            .padding(.top, 45)

            Spacer(minLength: 0)

            HGPrimaryButton(title: "기록 저장", height: 48) {
                showsSaveConfirmation = true
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
        .padding(.horizontal, 25)
        .padding(.top, 24)
        .background(HGColor.appBackground)
        .toolbar(.hidden, for: .navigationBar)
        .alert("기록을 저장했습니다.", isPresented: $showsSaveConfirmation) {
            Button("확인", role: .cancel) {}
        }
    }

    private var header: some View {
        HStack {
            Button(action: {}) { Image("menu").resizable().scaledToFit().frame(width: 28, height: 28) }
                .buttonStyle(.plain)
            Spacer()
            Text("폭염가드").font(HGFont.bold(20, relativeTo: .title2))
            Spacer()
            Button(action: {}) { Image("bell").resizable().scaledToFit().frame(width: 28, height: 28) }
                .buttonStyle(.plain)
        }
        .frame(height: 28)
    }

    private var restForm: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("휴식 시간").font(HGFont.semiBold(16))
            Text(restPeriod)
                .font(HGFont.bold(13, relativeTo: .caption))
                .frame(maxWidth: .infinity, minHeight: 45, alignment: .leading)
                .padding(.horizontal, 15)
                .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay { RoundedRectangle(cornerRadius: 12).stroke(HGColor.inputBorder, lineWidth: 1) }
                .padding(.top, 12)
            HStack(spacing: 8) {
                Text("메모").font(HGFont.semiBold(16))
                Text("(선택)").font(HGFont.medium(13, relativeTo: .caption)).foregroundStyle(HGColor.secondaryText)
            }
            .padding(.top, 25)
            memoEditor.padding(.top, 12)
        }
        .padding(.horizontal, 7)
    }

    private var memoEditor: some View {
        TextEditor(text: $memo)
            .font(HGFont.medium(13, relativeTo: .caption))
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .frame(height: 74)
            .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .topLeading) {
                if memo.isEmpty {
                    Text("휴식 관련 메모를 입력해주세요")
                        .font(HGFont.medium(13, relativeTo: .caption))
                        .foregroundStyle(HGColor.secondaryText)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
            }
            .overlay { RoundedRectangle(cornerRadius: 12).stroke(HGColor.inputBorder, lineWidth: 1) }
    }
}

#Preview { NavigationStack { RestPhotoView() } }
