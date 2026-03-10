//
//  DeviceSetupGuideOverlay.swift
//  ios_watchme_v9
//
//  デバイス未登録時のガイドオーバーレイ
//  ダークテーマ対応（Oura Ring風）
//

import SwiftUI
import UIKit

// UIKitのぼかし効果を使うカスタムビュー
struct BackgroundBlurView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
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
            // ダーク半透明オーバーレイ
            Color.black.opacity(0.75)
                .ignoresSafeArea()

            // 中央のモーダルウィンドウ（左右にも余白を持たせる）
            VStack(spacing: 20) {
                // テキスト部分
                VStack(spacing: 8) {
                    Text("音声分析を\nはじめてみよう")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("あなたの声から、気分・行動・感情を分析します。")
                        .font(.subheadline)
                        .foregroundColor(Color(white: 0.56))
                        .multilineTextAlignment(.center)
                }

                // 上部の2つのボタンを横並びに
                HStack(spacing: 12) {
                    // 1. スマホのマイクで測定
                    Button(action: onSelectThisDevice) {
                        VStack(spacing: 8) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 48))
                            Text("スマホのマイク\nで測定")
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .padding(.horizontal, 10)
                        .background(Color.accentTeal)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }

                    // 2. QRコードでデバイス追加
                    Button(action: onScanQR) {
                        VStack(spacing: 8) {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 48))
                            Text("QRコードで\nデバイス追加")
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .padding(.horizontal, 10)
                        .background(Color.darkElevated)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.12), Color.white.opacity(0.04)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                    }
                }

                // 3. デモを体験するバナー
                Button(action: onViewSample) {
                    VStack(spacing: 4) {
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
                                    Color.accentTeal.opacity(0.6),
                                    Color.accentTeal.opacity(0.3)
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
            .frame(maxWidth: 350)
            .background(Color.darkSurface)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 30)
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
        Color.darkBase
            .ignoresSafeArea()

        VStack {
            Text("ダッシュボード背景")
                .font(.largeTitle)
                .foregroundColor(.white)
            Rectangle()
                .fill(Color.darkCard)
                .frame(height: 200)
                .cornerRadius(12)
                .padding()
        }

        DeviceSetupGuideOverlay(
            onSelectThisDevice: { print("このデバイス") },
            onViewSample: { print("サンプル") },
            onScanQR: { print("QRコード") }
        )
    }
}
