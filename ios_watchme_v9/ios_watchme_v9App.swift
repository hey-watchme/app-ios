//
//  ios_watchme_v9App.swift
//  ios_watchme_v9
//
//  Created by Kaya Matsumoto on 2025/06/11.
//

import SwiftUI
import AVFoundation

@main
struct ios_watchme_v9App: App {
    @StateObject private var authManager = SupabaseAuthManager()
    
    var body: some Scene {
        WindowGroup {
            MainAppView()
                .environmentObject(authManager)
                .onAppear {
                    requestMicrophonePermission()
                }
        }
    }
    
    private func requestMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                if granted {
                    print("マイクアクセスが許可されました")
                } else {
                    print("マイクアクセスが拒否されました")
                }
            }
        }
    }
}

// メインアプリビュー（ログイン状態に応じて画面切り替え）
struct MainAppView: View {
    @EnvironmentObject var authManager: SupabaseAuthManager
    @State private var showLogin = false
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                // ログイン済み：メイン機能画面
                ContentView()
                    .environmentObject(authManager)
                    .onAppear {
                        print("📱 MainAppView: 認証済み状態 - ContentView表示")
                    }
            } else {
                // 未ログイン：ログイン画面表示ボタン
                VStack(spacing: 20) {
                    VStack(spacing: 10) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        Text("WatchMe")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("音声録音・アップロードアプリ")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 100)
                    
                    Spacer()
                    
                    VStack(spacing: 16) {
                        Text("ログインして録音を開始")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            showLogin = true
                        }) {
                            HStack {
                                Image(systemName: "person.circle.fill")
                                Text("ログイン / サインアップ")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .padding(.horizontal, 40)
                    }
                    
                    Spacer()
                    
                    Text("Supabase認証を使用")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 50)
                }
                .onAppear {
                    print("📱 MainAppView: 未認証状態 - ログイン画面表示")
                }
            }
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
        .onChange(of: authManager.isAuthenticated) { oldValue, newValue in
            print("🔄 MainAppView: 認証状態変化 \(oldValue) → \(newValue)")
            if newValue && showLogin {
                // ログイン成功時にシートを閉じる
                showLogin = false
                print("✅ ログイン成功 - メイン画面に遷移")
            }
        }
    }
}
