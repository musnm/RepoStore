import SwiftUI

struct AddRepoView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var url = ""
    @State private var code = ""
    @FocusState private var focus: Int?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        VStack(spacing: 10) {
                            ZStack {
                                Circle().fill(Theme.gradient)
                                    .frame(width: 70, height: 70).opacity(0.85)
                                Image(systemName: "link.badge.plus")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Text("添加软件源")
                                .font(.system(size: 19, weight: .bold))
                                .foregroundColor(.white)
                            Text("粘贴源地址，支持 JSON 格式源")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.textSub)
                        }
                        .padding(.top, 10)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("源地址")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Theme.textSub)
                            TextField("https://example.com/repo.json", text: $url)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(.white)
                                .focused($focus, equals: 0)
                                .padding(14)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card2))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 4) {
                                Text("解锁码")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Theme.textSub)
                                Text("选填")
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.textSub.opacity(0.6))
                            }
                            SecureField("如果该源需要解锁，在这里输入", text: $code)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(.white)
                                .focused($focus, equals: 1)
                                .padding(14)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card2))
                        }

                        Button {
                            add()
                        } label: {
                            Text("添加")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(
                                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                                        .fill(url.isEmpty
                                              ? AnyShapeStyle(Theme.card2)
                                              : AnyShapeStyle(Theme.gradient))
                                )
                        }
                        .disabled(url.isEmpty)

                        Spacer()
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear { focus = 0 }
        }
    }

    private func add() {
        var u = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !u.isEmpty else { return }
        if !u.lowercased().hasPrefix("http") { u = "https://" + u }
        store.addRepo(url: u)

        let enteredCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        if !enteredCode.isEmpty, let repo = store.repos.last {
            Task { _ = await store.unlock(repo.id, code: enteredCode) }
        }
        dismiss()
    }
}
