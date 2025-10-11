//
//  DeviceSetupGuideOverlay.swift
//  ios_watchme_v9
//
//  デバイス未登録時のガイドオーバーレイ
//  すりガラス効果で背景のダッシュボードをぼかし、3つの選択肢を提示
//

import SwiftUI
import UIKit

// UIKitのぼかし効果を使うカスタムビュー
struct BackgroundBlurView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .prominent))
        return view
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

struct DeviceSetupGuideOverlay: View {
    let onSelectThisDevice: () -> Void
    let onViewSample: () -> Void
    let onScanQR: () -> Void

    @State private var isVisible = false

    var body: some View {
        ZStack {
            // シンプルな白の半透明オーバーレイ
            Color.white.opacity(0.8)  // 白の80%透明度
                .ignoresSafeArea()

            // 中央のモーダルウィンドウ（左右にも余白を持たせる）
            VStack(spacing: 20) {
                // テキスト部分（アイコンは削除）
                VStack(spacing: 8) {
                    Text("音声分析を\nはじめてみよう")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)

                    Text("あなたの声から、気分・行動・感情を分析します。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                // 上部の2つのボタンを横並びに
                HStack(spacing: 12) {
                    // 1. スマホのマイクで測定
                    Button(action: onSelectThisDevice) {
                        VStack(spacing: 8) {
                            Image(systemName: "mic.fill")  // マイクアイコンに変更
                                .font(.system(size: 48))  // 2倍のサイズ
                            Text("スマホのマイク\nで測定")
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)  // 2行まで表示
                                .fixedSize(horizontal: false, vertical: true)  // 垂直方向に自然なサイズ
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)  // 上下20ピクセルの余白
                        .padding(.horizontal, 10)  // 左右にも余白を追加
                        .background(Color.safeColor("AppAccentColor"))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }

                    // 2. QRコードでデバイス追加
                    Button(action: onScanQR) {
                        VStack(spacing: 8) {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 48))  // 2倍のサイズ
                            Text("QRコードで\nデバイス追加")
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)  // 2行まで表示
                                .fixedSize(horizontal: false, vertical: true)  // 垂直方向に自然なサイズ
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)  // 上下20ピクセルの余白
                        .padding(.horizontal, 10)  // 左右にも余白を追加
                        .background(Color.white)
                        .foregroundColor(.black)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.black, lineWidth: 2.0)  // 太めの黒い輪郭線
                        )
                        .cornerRadius(12)
                    }
                }

                // 3. デモを体験するバナー
                Button(action: onViewSample) {
                    VStack(spacing: 4) {
                        // バナー部分（後で画像に置き換え予定）
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("デモを体験する")
                                    .font(.headline)
                                    .foregroundColor(.white)

                                Text("サンプルデータ: 5歳の男の子")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            Spacer()
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.blue.opacity(0.8),
                                    Color.purple.opacity(0.8)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                }
            }
            .padding(30)
            .frame(maxWidth: 350)  // モーダルの最大幅を制限
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 30)  // 左右に余白を確保
            .opacity(isVisible ? 1.0 : 0)
            .scaleEffect(isVisible ? 1.0 : 0.95)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isVisible = true
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        // 背景としてダミーのダッシュボード
        Color.gray.opacity(0.1)
            .ignoresSafeArea()

        VStack {
            Text("ダッシュボード背景")
                .font(.largeTitle)
            Rectangle()
                .fill(Color.blue.opacity(0.3))
                .frame(height: 200)
                .cornerRadius(12)
                .padding()
        }

        // オーバーレイ
        DeviceSetupGuideOverlay(
            onSelectThisDevice: { print("このデバイス") },
            onViewSample: { print("サンプル") },
            onScanQR: { print("QRコード") }
        )
    }
}
