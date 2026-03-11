//
//  ToastManager.swift
//  ios_watchme_v9
//
//  グローバルトーストシステム
//  アプリ全体で共有する通知バナーの管理
//

import SwiftUI

// MARK: - ToastMessage（トーストメッセージの定義）

struct ToastMessage: Equatable {
    enum ToastType: Equatable {
        case success    // 成功（緑）
        case error      // エラー（赤）
        case info       // 情報（青）
        case uploading(progress: Double)  // 送信中（プログレスバー付き）- 互換性のため残す
        case progress(phase: String, progress: Double)  // フェーズ付きプログレス（推奨）
    }

    let id: UUID
    let type: ToastType
    let title: String
    let subtitle: String?
    let autoDismiss: Bool

    init(
        type: ToastType,
        title: String,
        subtitle: String? = nil,
        autoDismiss: Bool = true
    ) {
        self.id = UUID()
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.autoDismiss = autoDismiss
    }

    // Equatableの実装（idを除外して比較）
    static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - ToastManager（グローバルシングルトン）

@MainActor
class ToastManager: ObservableObject {
    static let shared = ToastManager()

    @Published private(set) var currentToast: ToastMessage?
    private var dismissTask: Task<Void, Never>?

    private init() {}

    /// トーストを表示
    func show(_ toast: ToastMessage) {
        // 既存の自動非表示タスクをキャンセル
        dismissTask?.cancel()

        // 新しいトーストを表示
        currentToast = toast

        print("🍞 [Toast] 表示: \(toast.title)")

        // 自動非表示が有効な場合、8秒後に消す
        if toast.autoDismiss {
            dismissTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(8))
                guard !Task.isCancelled else { return }
                self?.dismiss()
            }
        }
    }

    /// トーストを非表示
    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil

        if currentToast != nil {
            print("🍞 [Toast] 非表示")
            currentToast = nil
        }
    }

    /// 便利メソッド：成功トースト
    func showSuccess(title: String, subtitle: String? = nil) {
        show(ToastMessage(type: .success, title: title, subtitle: subtitle))
    }

    /// 便利メソッド：エラートースト
    func showError(title: String, subtitle: String? = nil) {
        show(ToastMessage(type: .error, title: title, subtitle: subtitle))
    }

    /// 便利メソッド：情報トースト
    func showInfo(title: String, subtitle: String? = nil) {
        show(ToastMessage(type: .info, title: title, subtitle: subtitle))
    }

    /// 便利メソッド：アップロード中トースト（互換性のため残す）
    func showUploading(title: String, subtitle: String? = nil, progress: Double) {
        show(ToastMessage(
            type: .uploading(progress: progress),
            title: title,
            subtitle: subtitle,
            autoDismiss: false  // 送信中は自動非表示しない
        ))
    }

    /// 便利メソッド：フェーズ付きプログレストースト（推奨）
    func showProgressWithPhase(phase: String, subtitle: String? = nil, progress: Double) {
        show(ToastMessage(
            type: .progress(phase: phase, progress: progress),
            title: phase,
            subtitle: subtitle,
            autoDismiss: false  // プログレス中は自動非表示しない
        ))
    }
}

// MARK: - ToastOverlay（トーストを表示するビュー）

struct ToastOverlay: View {
    @ObservedObject var toastManager: ToastManager

    var body: some View {
        VStack {
            if let toast = toastManager.currentToast {
                toastView(for: toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: toast.id)
            }
            Spacer()
        }
        .allowsHitTesting(false)  // タップを下のビューに通過させる
        .zIndex(9999)  // 最前面に表示
    }

    @ViewBuilder
    private func toastView(for toast: ToastMessage) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // アイコン
                Image(systemName: iconName(for: toast.type))
                    .font(.title3)
                    .foregroundColor(iconColor(for: toast.type))

                VStack(alignment: .leading, spacing: 4) {
                    Text(toast.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    if let subtitle = toast.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(Color(white: 0.72))
                            .lineLimit(2)
                    }
                }

                Spacer()
            }

            // プログレスバー（送信中またはフェーズ付きプログレス）
            if case .uploading(let progress) = toast.type {
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: progressTint(for: toast.type)))
            } else if case .progress(_, let progress) = toast.type {
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: progressTint(for: toast.type)))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.darkElevated.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.16), Color.white.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: Color.black.opacity(0.32), radius: 14, x: 0, y: 6)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // アイコン名を取得
    private func iconName(for type: ToastMessage.ToastType) -> String {
        switch type {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        case .info:
            return "info.circle.fill"
        case .uploading:
            return "arrow.up.circle.fill"
        case .progress:
            return "arrow.up.circle.fill"
        }
    }

    // アイコン色を取得
    private func iconColor(for type: ToastMessage.ToastType) -> Color {
        switch type {
        case .success:
            return .accentEmerald
        case .error:
            return .accentCoral
        case .info:
            return .accentTeal
        case .uploading:
            return .accentTeal
        case .progress:
            return .accentTeal
        }
    }

    private func progressTint(for type: ToastMessage.ToastType) -> Color {
        switch type {
        case .success:
            return .accentEmerald
        case .error:
            return .accentCoral
        case .info, .uploading, .progress:
            return .accentTeal
        }
    }
}
