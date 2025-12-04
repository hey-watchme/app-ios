//
//  SubjectFormView.swift
//  ios_watchme_v9
//
//  Simplified and optimized subject form view
//

import SwiftUI

struct SubjectFormView: View {
    @StateObject private var viewModel: SubjectFormViewModel
    @Environment(\.dismiss) private var dismiss

    init(
        deviceID: String,
        editingSubject: Subject?,
        dataManager: SupabaseDataManager,
        deviceManager: DeviceManager,
        userAccountManager: UserAccountManager
    ) {
        _viewModel = StateObject(wrappedValue: SubjectFormViewModel(
            deviceID: deviceID,
            editingSubject: editingSubject,
            dataManager: dataManager,
            deviceManager: deviceManager,
            userAccountManager: userAccountManager
        ))
    }

    var body: some View {
        NavigationView {
            Form {
                // Name field (Required)
                Section {
                    HStack {
                        Text("名前")
                        Text("*")
                            .foregroundColor(.red)
                        Spacer()
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)

                    TextField("例：田中太郎", text: $viewModel.formData.name)
                        .disabled(viewModel.isViewOnly)
                }

                // Basic Information
                Section("基本情報") {
                    // Age
                    HStack {
                        Text("年齢")
                        Spacer()
                        TextField("例：25", text: $viewModel.formData.age)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .disabled(viewModel.isViewOnly)
                    }

                    // Gender
                    Picker("性別", selection: $viewModel.formData.gender) {
                        Text("選択しない").tag("")
                        ForEach(SubjectFormConstants.genderOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .disabled(viewModel.isViewOnly)

                    // Prefecture
                    Picker("都道府県", selection: $viewModel.formData.prefecture) {
                        Text("選択しない").tag("")
                        ForEach(SubjectFormConstants.prefectureOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .disabled(viewModel.isViewOnly)

                    // City
                    HStack {
                        Text("市区町村")
                        Spacer()
                        TextField("例：横浜市", text: $viewModel.formData.city)
                            .multilineTextAlignment(.trailing)
                            .disabled(viewModel.isViewOnly)
                    }
                }

                // Notes
                Section("メモ") {
                    TextField(
                        "補足情報を入力",
                        text: $viewModel.formData.notes,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                    .disabled(viewModel.isViewOnly)
                }

                // Delete button (edit mode only)
                if viewModel.isEditing && !viewModel.isViewOnly {
                    Section {
                        Button(role: .destructive) {
                            viewModel.showingDeleteConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("観測対象を削除")
                            }
                        }
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(viewModel.isViewOnly ? "閉じる" : "キャンセル") {
                        dismiss()
                    }
                }

                if !viewModel.isViewOnly {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(viewModel.isEditing ? "更新" : "登録") {
                            Task {
                                await viewModel.save()
                            }
                        }
                        .disabled(!viewModel.formData.isValid || viewModel.isLoading)
                    }
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.3))
                }
            }
            .alert("削除確認", isPresented: $viewModel.showingDeleteConfirmation) {
                Button("キャンセル", role: .cancel) { }
                Button("削除", role: .destructive) {
                    Task {
                        await viewModel.deleteSubject()
                    }
                }
            } message: {
                Text("この観測対象を完全に削除します。この操作は取り消せません。")
            }
            .alert(
                viewModel.isEditing ? "更新完了" : "登録完了",
                isPresented: $viewModel.showingSuccessAlert
            ) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text(viewModel.isEditing ? "観測対象を更新しました" : "観測対象を登録しました")
            }
            .alert("エラー", isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { _ in viewModel.errorMessage = nil }
            )) {
                Button("OK") { }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
    }

    private var navigationTitle: String {
        if viewModel.isViewOnly {
            return "観測対象の詳細"
        } else if viewModel.isEditing {
            return "観測対象を編集"
        } else {
            return "観測対象を追加"
        }
    }
}