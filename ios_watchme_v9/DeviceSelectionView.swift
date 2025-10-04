//
//  DeviceSelectionView.swift
//  ios_watchme_v9
//
//  Created by Kaya Matsumoto on 2025/07/30.
//

import SwiftUI

struct DeviceSelectionView: View {
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var dataManager: SupabaseDataManager
    @EnvironmentObject var userAccountManager: UserAccountManager
    @Binding var isPresented: Bool
    @Binding var subjectsByDevice: [String: Subject]
    @State private var showQRScanner = false
    @State private var showAddDeviceAlert = false
    @State private var addDeviceError: String?
    @State private var showSuccessAlert = false
    @State private var addedDeviceId: String?
    
    var body: some View {
        NavigationView {
            VStack {
                if deviceManager.isLoading {
                    ProgressView("デバイス一覧を読み込み中...")
                        .padding()
                } else if deviceManager.userDevices.isEmpty {
                    // デバイスがない時のUI
                    VStack(spacing: 0) {
                        // 上部の余白（調整済み）
                        Spacer()
                            .frame(height: 50)

                        // メインメッセージ
                        Text("あなたの声から\n「こころ」をチェックしよう。")
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .padding(.bottom, 50)

                        // ボタンエリア
                        VStack(spacing: 16) {
                            // 1. このデバイスで測定するボタン
                            Button(action: {
                                handleRegisterCurrentDevice()
                            }) {
                                HStack {
                                    Image(systemName: "iphone")
                                        .font(.title3)
                                    Text("このデバイスで測定する")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.safeColor("AppAccentColor"))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }

                            // 2. サンプルを見るボタン
                            Button(action: {
                                // サンプルデバイスを選択
                                deviceManager.selectDevice(DeviceManager.sampleDeviceID)
                                // シートを閉じる
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    isPresented = false
                                }
                            }) {
                                HStack {
                                    Image(systemName: "eye")
                                        .font(.title3)
                                    Text("サンプルを見る")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.gray.opacity(0.2))
                                .foregroundColor(Color.safeColor("AppAccentColor"))
                                .cornerRadius(12)
                            }

                            // 3. QRコードでデバイスを追加ボタン
                            Button(action: {
                                showQRScanner = true
                            }) {
                                HStack {
                                    Image(systemName: "qrcode.viewfinder")
                                        .font(.title3)
                                    Text("QRコードでデバイスを追加")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.gray.opacity(0.2))
                                .foregroundColor(Color.safeColor("AppAccentColor"))
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 40)

                        Spacer()
                    }
                } else {
                    // デバイスがある時のリスト表示
                    List {
                        Section(header: Text("利用可能なデバイス")) {
                            DeviceSectionView(
                                devices: deviceManager.userDevices,
                                selectedDeviceID: deviceManager.selectedDeviceID,
                                subjectsByDevice: subjectsByDevice,
                                showSelectionUI: true,
                                onDeviceSelected: { deviceId in
                                    deviceManager.selectDevice(deviceId)
                                    // 少し遅延を入れてからシートを閉じる（アニメーション用）
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        isPresented = false
                                    }
                                }
                            )
                        }

                        Section {
                            Button(action: {
                                showQRScanner = true
                            }) {
                                HStack {
                                    Image(systemName: "qrcode.viewfinder")
                                        .font(.title3)
                                    Text("デバイスを追加")
                                        .font(.body)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                            }
                            .foregroundColor(.white)
                            .background(Color.safeColor("PrimaryActionColor"))
                            .cornerRadius(10)
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("デバイス選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        isPresented = false
                    }
                }
            }
            .sheet(isPresented: $showQRScanner) {
                QRCodeScannerView(isPresented: $showQRScanner) { scannedCode in
                    Task {
                        await handleQRCodeScanned(scannedCode)
                    }
                }
            }
            .alert("デバイス追加エラー", isPresented: $showAddDeviceAlert, presenting: addDeviceError) { _ in
                Button("OK", role: .cancel) { }
            } message: { error in
                Text(error)
            }
            .alert("デバイスを追加しました", isPresented: $showSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                if let deviceId = addedDeviceId {
                    Text("device_id: \(deviceId.prefix(8))... が閲覧可能になりました！")
                }
            }
        }
    }
    
    // MARK: - このデバイスを登録する処理
    private func handleRegisterCurrentDevice() {
        guard let userId = userAccountManager.currentUser?.profile?.userId else {
            addDeviceError = "ユーザー情報の取得に失敗しました"
            showAddDeviceAlert = true
            return
        }

        Task {
            // DeviceManagerのregisterDeviceメソッドを呼び出す
            await MainActor.run {
                deviceManager.registerDevice(userId: userId)
            }

            // 登録完了まで待機（最大5秒）
            var attempts = 0
            while deviceManager.isLoading && attempts < 50 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
                attempts += 1
            }

            await MainActor.run {
                // エラーチェック
                if let error = deviceManager.registrationError {
                    addDeviceError = error
                    showAddDeviceAlert = true
                } else if !deviceManager.userDevices.isEmpty {
                    // 登録成功 - デバイスが追加されたのでUIが自動的に更新される
                    print("✅ デバイス登録成功")
                } else {
                    addDeviceError = "デバイスの登録に失敗しました。もう一度お試しください。"
                    showAddDeviceAlert = true
                }
            }
        }
    }

    private func handleQRCodeScanned(_ code: String) async {
        // 既に追加済みかチェック
        if deviceManager.userDevices.contains(where: { $0.device_id == code }) {
            addDeviceError = "このデバイスは既に追加されています。"
            showAddDeviceAlert = true
            return
        }

        // デバイスを追加
        do {
            if let userId = userAccountManager.currentUser?.id {
                try await deviceManager.addDeviceByQRCode(code, for: userId)
                // 成功時のフィードバック
                addedDeviceId = code
                showSuccessAlert = true
            } else {
                addDeviceError = "ユーザー情報の取得に失敗しました。"
                showAddDeviceAlert = true
            }
        } catch {
            addDeviceError = "デバイスの追加に失敗しました: \(error.localizedDescription)"
            showAddDeviceAlert = true
        }
    }
}

// プレビュー用
struct DeviceSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        DeviceSelectionView(isPresented: .constant(true), subjectsByDevice: .constant([:]))
            .environmentObject(DeviceManager())
            .environmentObject(SupabaseDataManager())
            .environmentObject(UserAccountManager(deviceManager: DeviceManager()))
    }
}