import SwiftUI
import UIKit

struct UnlockSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let repo: Repo

    @State private var code = ""
    @State private var busy = false
    @State private var errorText: String?
    @State private var showCode = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                VStack(spacing: 20) {
                    header

                    VStack(alignment: .leading, spacing: 8) {
                        Text("解锁码")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.textSub)

                        HStack(spacing: 10) {
                            Group {
                                if showCode {
                                    TextField("请输入解锁码", text: $code)
                                } else {
                                    SecureField("请输入解锁码", text: $code)
                                }
                            }
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.system(size: 16, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card2))

                            Button {
                                showCode.toggle()
                            } label: {
                                Image(systemName: showCode ? "eye.slash.fill" : "eye.fill")
                                    .foregroundColor(Theme.textSub)
                                    .frame(width: 46, height: 46)
                                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card2))
                            }
                        }

                        if let e = errorText {
                            Label(e, systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                        }
                    }

                    Button {
                        submit()
                    } label: {
                        HStack(spacing: 8) {
                            if busy {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "key.fill")
                                Text("解锁")
                            }
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(code.isEmpty
                                      ? AnyShapeStyle(Theme.card2)
                                      : AnyShapeStyle(Theme.gradient))
                        )
                    }
                    .disabled(code.isEmpty || busy)

                    Text("解锁码请向源作者获取，不要公开分享")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSub.opacity(0.8))

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("解锁源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(Theme.gradient).frame(width: 68, height: 68).opacity(0.9)
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
            }
            Text(repo.name.isEmpty ? "此软件源" : repo.name)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
            Text(repo.url)
                .font(.system(size: 11))
                .foregroundColor(Theme.textSub)
                .lineLimit(1)
        }
        .padding(.top, 6)
    }

    private func submit() {
        busy = true
        errorText = nil
        Task {
            let ok = await store.unlock(repo.id, code: code)
            await MainActor.run {
                busy = false
                if ok {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    dismiss()
                } else {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    errorText = store.errorMessage ?? "解锁码无效"
                    store.errorMessage = nil
                }
            }
        }
    }
}
