//
//  WorkPhotoView.swift
//  heatguard-iOS
//

import SwiftUI

struct WorkPhotoView: View {
    @State private var memo = ""

    let onSave: () -> Void

    init(onSave: @escaping () -> Void = {}) {
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            VStack(alignment: .leading, spacing: 0) {
                Text("작업 전 · 중 사진")
                    .font(HGFont.bold(20, relativeTo: .title2))
                    .foregroundStyle(.black)

                Text("작업 현장과 보호조치를 확인 할 수 있는\n사진을 촬영해 주세요")
                    .font(HGFont.regular(14, relativeTo: .subheadline))
                    .foregroundStyle(.black)
                    .padding(.top, 10)

                HGPhotoCaptureSection()
                    .padding(.top, 15)

                memoSection
                    .padding(.top, 25)
            }
            .padding(.top, 45)

            Spacer(minLength: 0)

            HGPrimaryButton(title: "기록 저장", height: 48, action: onSave)
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
        .padding(.horizontal, 25)
        .padding(.top, 24)
        .background(HGColor.appBackground)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HGScreenHeader()
    }

    private var memoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("메모")
                    .font(HGFont.semiBold(16, relativeTo: .body))
                    .foregroundStyle(.black)

                Text("(선택)")
                    .font(HGFont.medium(13, relativeTo: .caption))
                    .foregroundStyle(photoText)
            }

            TextEditor(text: $memo)
                .font(HGFont.medium(13, relativeTo: .caption))
                .foregroundStyle(HGColor.primaryText)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .frame(height: 114)
                .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .topLeading) {
                    if memo.isEmpty {
                        Text("작업 전 · 중 특이사항이 있다면 입력해주세요")
                            .font(HGFont.medium(13, relativeTo: .caption))
                            .foregroundStyle(Color(red: 174 / 255, green: 179 / 255, blue: 196 / 255))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 15)
                            .allowsHitTesting(false)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(red: 234 / 255, green: 234 / 255, blue: 234 / 255), lineWidth: 1)
                }
        }
        .padding(.horizontal, 7)
    }

}

#Preview {
    NavigationStack {
        WorkPhotoView()
    }
}
