//
//  SubjectTabView.swift
//  ios_watchme_v9
//
//  観測対象タブ - 観測対象の情報表示・編集画面
//

import SwiftUI

struct SubjectTabView: View {
    @EnvironmentObject var userAccountManager: UserAccountManager
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var dataManager: SupabaseDataManager

    @State private var subject: Subject? = nil
    @State private var showSubjectEdit = false
    @State private var isLoading = true

    var body: some View {
        NavigationView {
            ScrollView {
                if isLoading {
                    // ローディング中
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("観測対象情報を取得中...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
                } else if let subject = subject {
                    // 観測対象が設定されている場合
                    VStack(spacing: 24) {
                        // プロフィール写真
                        AvatarView(type: .subject, id: subject.subjectId, size: 120)
                            .environmentObject(dataManager)
                            .padding(.top, 20)

                        // 基本情報
                        VStack(spacing: 16) {
                            // 名前
                            if let name = subject.name, !name.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("名前", systemImage: "person.fill")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text(name)
                                        .font(.body)
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(12)
                                }
                            }

                            // 年齢
                            if let age = subject.age {
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("年齢", systemImage: "calendar")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("\(age)歳")
                                        .font(.body)
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(12)
                                }
                            }

                            // 性別
                            if let gender = subject.gender, !gender.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("性別", systemImage: "person.2")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text(gender)
                                        .font(.body)
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(12)
                                }
                            }

                            // メモ
                            if let notes = subject.notes, !notes.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("メモ", systemImage: "note.text")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text(notes)
                                        .font(.body)
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal, 20)

                        // 編集ボタン
                        Button(action: {
                            showSubjectEdit = true
                        }) {
                            HStack {
                                Image(systemName: "pencil")
                                Text("観測対象を編集")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.safeColor("AppAccentColor"))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)

                        Spacer(minLength: 50)
                    }
                } else {
                    // 観測対象が未設定の場合
                    VStack(spacing: 20) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 80))
                            .foregroundColor(.gray)
                        Text("観測対象が未設定です")
                            .font(.title3)
                            .foregroundColor(.primary)
                        Text("このデバイスで観測する人物を登録してください")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        // 新規登録ボタン
                        Button(action: {
                            showSubjectEdit = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("観測対象を登録")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 12)
                            .background(Color.safeColor("AppAccentColor"))
                            .cornerRadius(12)
                        }
                        .padding(.top, 10)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
                }
            }
            .navigationTitle("観測対象")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task(id: deviceManager.selectedDeviceID) {
            await loadSubject()
        }
        .sheet(isPresented: $showSubjectEdit) {
            if let deviceId = deviceManager.selectedDeviceID {
                SubjectRegistrationView(
                    deviceID: deviceId,
                    isPresented: $showSubjectEdit,
                    editingSubject: subject
                )
                .environmentObject(dataManager)
                .environmentObject(deviceManager)
                .environmentObject(userAccountManager)
                .onDisappear {
                    // 編集後に再読み込み
                    Task {
                        await loadSubject()
                    }
                }
            }
        }
    }

    // 観測対象情報を取得
    private func loadSubject() async {
        guard let deviceId = deviceManager.selectedDeviceID else {
            await MainActor.run {
                subject = nil
                isLoading = false
            }
            return
        }

        await MainActor.run {
            isLoading = true
        }

        let fetchedSubject = await dataManager.fetchSubjectInfo(deviceId: deviceId)

        await MainActor.run {
            subject = fetchedSubject
            isLoading = false
        }
    }
}
