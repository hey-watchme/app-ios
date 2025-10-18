//
//  FeedbackFormView.swift
//  ios_watchme_v9
//
//  お問い合わせ・通報用の共通フォーム
//

import SwiftUI
import UIKit

// フィードバックのコンテキスト
enum FeedbackContext {
    case general                           // 一般的なお問い合わせ
    case reportComment(commentId: String, commentText: String)  // コメント通報
    case bugReport                         // バグ報告
    case other                             // その他
}

struct FeedbackFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userAccountManager: UserAccountManager

    let context: FeedbackContext

    @State private var selectedCategory: MessageCategory
    @State private var messageBody: String = ""
    @State private var isSubmitting: Bool = false
    @State private var showSuccessAlert: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""

    // コンテキストに応じた初期化
    init(context: FeedbackContext) {
        self.context = context

        // コンテキストに応じてデフォルトカテゴリを設定
        switch context {
        case .general:
            _selectedCategory = State(initialValue: .inquiry)
        case .reportComment:
            _selectedCategory = State(initialValue: .reportContent)
        case .bugReport:
            _selectedCategory = State(initialValue: .bugReport)
        case .other:
            _selectedCategory = State(initialValue: .other)
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // コンテキスト情報の表示（コメント通報時）
                    if case .reportComment(_, let commentText) = context {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("通報対象のコメント")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            Text(commentText)
                                .font(.body)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }

                    // カテゴリ選択
                    VStack(alignment: .leading, spacing: 8) {
                        Text("カテゴリ")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        Picker("カテゴリ", selection: $selectedCategory) {
                            ForEach(MessageCategory.allCases, id: \.self) { category in
                                Text(category.displayName).tag(category)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal)

                    // メッセージ入力
                    VStack(alignment: .leading, spacing: 8) {
                        Text("メッセージ")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        ZStack(alignment: .topLeading) {
                            if messageBody.isEmpty {
                                Text("詳細をご記入ください...")
                                    .foregroundColor(.gray.opacity(0.6))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 8)
                            }

                            TextEditor(text: $messageBody)
                                .frame(minHeight: 150)
                                .scrollContentBackground(.hidden)
                                .background(Color.clear)
                        }
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal)

                    // 送信ボタン
                    Button(action: submitFeedback) {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(isSubmitting ? "送信中..." : "送信する")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(messageBody.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(messageBody.isEmpty || isSubmitting)
                    .padding(.horizontal)
                    .padding(.top, 10)
                }
                .padding(.vertical)
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
            .alert("送信完了", isPresented: $showSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("お問い合わせを受け付けました。\nご連絡ありがとうございます。")
            }
            .alert("エラー", isPresented: $showErrorAlert) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // ナビゲーションタイトル
    private var navigationTitle: String {
        switch context {
        case .general:
            return "お問い合わせ"
        case .reportComment:
            return "コメントを通報"
        case .bugReport:
            return "バグを報告"
        case .other:
            return "お問い合わせ"
        }
    }

    // フィードバック送信
    private func submitFeedback() {
        guard !messageBody.isEmpty else { return }

        // ユーザーIDを取得
        guard let userId = userAccountManager.currentUser?.profile?.userId else {
            errorMessage = "ユーザー情報が取得できませんでした。"
            showErrorAlert = true
            return
        }

        isSubmitting = true

        // デバイス情報を取得
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let osVersion = UIDevice.current.systemVersion
        let deviceModel = UIDevice.current.model

        // コンテキストタイプと対象IDを決定
        let contextType: MessageContextType
        var targetCommentId: String? = nil

        switch context {
        case .general:
            contextType = .general
        case .reportComment(let commentId, _):
            contextType = .comment
            targetCommentId = commentId
        case .bugReport:
            contextType = .bug
        case .other:
            contextType = .general
        }

        // リクエストを作成
        let request = FeedbackRequest(
            userId: userId,
            category: selectedCategory.rawValue,
            messageBody: messageBody,
            contextType: contextType.rawValue,
            targetCommentId: targetCommentId,
            targetUserId: nil,
            appVersion: appVersion,
            osVersion: "iOS \(osVersion)",
            deviceModel: deviceModel
        )

        // Supabaseに送信
        Task {
            do {
                try await SupabaseDataManager.submitFeedback(request: request)
                await MainActor.run {
                    isSubmitting = false
                    showSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = "送信に失敗しました: \(error.localizedDescription)"
                    showErrorAlert = true
                }
            }
        }
    }
}

// プレビュー
#Preview("一般的なお問い合わせ") {
    let deviceManager = DeviceManager()
    let userAccountManager = UserAccountManager(deviceManager: deviceManager)

    return FeedbackFormView(context: .general)
        .environmentObject(userAccountManager)
}

#Preview("コメント通報") {
    let deviceManager = DeviceManager()
    let userAccountManager = UserAccountManager(deviceManager: deviceManager)

    return FeedbackFormView(context: .reportComment(
        commentId: "test-comment-id",
        commentText: "これは不適切なコメントのサンプルテキストです。"
    ))
    .environmentObject(userAccountManager)
}
