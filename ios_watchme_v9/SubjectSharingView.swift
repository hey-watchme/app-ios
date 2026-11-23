//
//  SubjectSharingView.swift
//  ios_watchme_v9
//
//  Sharing a subject (platform docs/product/accounts-subjects-devices.md, step 5):
//  who is linked, inviting with a one-time QR (30 minutes), reading an invite QR,
//  taking someone off, and leaving. Owners record, edit and invite; viewers only look.
//

import SwiftUI
import AVFoundation

// MARK: - The section on the subject screen

struct SubjectSharingSection: View {
    let entry: SubjectEntry
    /// Called after the user left the subject (the screen closes).
    var onLeft: () -> Void

    @EnvironmentObject private var subjectManager: SubjectManager
    @EnvironmentObject private var userAccountManager: UserAccountManager
    @EnvironmentObject private var toastManager: ToastManager

    @State private var members: [SubjectMember] = []
    @State private var loadFailed = false
    @State private var showInvite = false
    @State private var memberToRemove: SubjectMember? = nil
    @State private var showLeaveConfirm = false
    @State private var isWorking = false

    private var me: SubjectMember? { members.first(where: { $0.isMe }) }
    private var otherOwners: [SubjectMember] { members.filter { $0.isOwner && !$0.isMe } }
    private var canLeave: Bool { entry.isViewer || !otherOwners.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("共有")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(white: 0.56))
            VStack(spacing: 0) {
                ForEach(members) { member in
                    memberRow(member)
                    Divider().background(Color.white.opacity(0.08))
                }
                if loadFailed {
                    Text("共有している人を読み込めませんでした")
                        .font(.system(size: 13))
                        .foregroundColor(Color(white: 0.56))
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Divider().background(Color.white.opacity(0.08))
                }
                if entry.isOwner {
                    actionRow(title: "分析対象の共有", systemImage: "qrcode", color: .accentTeal) {
                        showInvite = true
                    }
                }
                if canLeave {
                    if entry.isOwner { Divider().background(Color.white.opacity(0.08)) }
                    actionRow(title: "共有をやめる", systemImage: "rectangle.portrait.and.arrow.right", color: .accentCoral) {
                        showLeaveConfirm = true
                    }
                }
            }
            .padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.darkCard))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))

            if let footnote {
                Text(footnote)
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .disabled(isWorking)
        .task(id: entry.subjectId) { await load() }
        .sheet(isPresented: $showInvite, onDismiss: { Task { await load() } }) {
            SubjectInviteSheet(entry: entry)
                .environmentObject(subjectManager)
        }
        .alert("\(memberToRemove?.displayName ?? "")さんを外しますか？", isPresented: Binding(
            get: { memberToRemove != nil }, set: { if !$0 { memberToRemove = nil } }
        )) {
            Button("キャンセル", role: .cancel) { memberToRemove = nil }
            Button("外す", role: .destructive) {
                if let member = memberToRemove { remove(member) }
                memberToRemove = nil
            }
        } message: {
            Text("この分析対象の記録が見られなくなります。録音と分析結果は残ります。")
        }
        .alert("共有をやめますか？", isPresented: $showLeaveConfirm) {
            Button("キャンセル", role: .cancel) { }
            Button("共有をやめる", role: .destructive) { leave() }
        } message: {
            Text("\(entry.displayName)の記録が、このアカウントから見られなくなります。録音と分析結果はほかの人のために残ります。もう一度見るには、招待してもらう必要があります。")
        }
    }

    /// Only for situations the list does not explain; how invites work is on the QR screen.
    private var footnote: String? {
        if entry.isViewer {
            return "見るだけの共有です。録音とプロフィールの編集は、録音・編集できる人が行います。"
        }
        if !canLeave && members.count > 1 {
            return "録音・編集できる人がほかにいないため、共有をやめられません。分析対象を削除すると、共有している人も見られなくなります。"
        }
        return nil
    }

    private func memberRow(_ member: SubjectMember) -> some View {
        HStack(spacing: 12) {
            Image(systemName: member.isOwner ? "person.crop.circle.fill" : "eye.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(member.isOwner ? .accentTeal : Color(white: 0.56))
            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayName + (member.isMe ? "（あなた）" : ""))
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                Text(member.isOwner ? "録音・編集できる" : "見るだけ")
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.56))
            }
            Spacer()
            if entry.isOwner && !member.isMe {
                Button("外す") { memberToRemove = member }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.accentCoral)
                    .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 10)
    }

    private func actionRow(title: String, systemImage: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(color)
                Spacer()
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func load() async {
        do {
            let found = try await subjectManager.members(of: entry.subjectId)
            await MainActor.run { members = found; loadFailed = false }
        } catch {
            print("❌ Failed to load members: \(error)")
            await MainActor.run { loadFailed = true }
        }
    }

    private func remove(_ member: SubjectMember) {
        isWorking = true
        Task {
            do {
                let network = NetworkManager(userAccountManager: userAccountManager, subjectManager: subjectManager)
                try await network.removeSubjectMember(subjectId: entry.subjectId, userId: member.userId)
                await load()
                await MainActor.run { toastManager.showSuccess(title: "\(member.displayName)さんを外しました") }
            } catch {
                await MainActor.run { toastManager.showError(title: "外せませんでした", subtitle: error.localizedDescription) }
            }
            await MainActor.run { isWorking = false }
        }
    }

    private func leave() {
        isWorking = true
        Task {
            do {
                let network = NetworkManager(userAccountManager: userAccountManager, subjectManager: subjectManager)
                _ = try await network.deleteSubject(subjectId: entry.subjectId)
                await MainActor.run { subjectManager.forgetSubject(entry.subjectId) }
                if let userId = userAccountManager.currentUser?.id {
                    await subjectManager.loadSubjects(for: userId)
                }
                await MainActor.run {
                    isWorking = false
                    toastManager.showSuccess(title: "\(entry.displayName)の共有をやめました")
                    onLeft()
                }
            } catch {
                await MainActor.run {
                    isWorking = false
                    toastManager.showError(title: "共有をやめられませんでした", subtitle: error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - Invite (owner shows a QR)

struct SubjectInviteSheet: View {
    let entry: SubjectEntry

    @EnvironmentObject private var subjectManager: SubjectManager
    @Environment(\.dismiss) private var dismiss

    @State private var role = "viewer"
    @State private var invite: SubjectInvite? = nil
    @State private var isCreating = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let invite {
                        qrView(invite)
                    } else {
                        rolePicker
                    }
                }
                .padding(20)
            }
            .background(Color.darkBase.ignoresSafeArea())
            .navigationTitle("\(entry.displayName)を共有")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.darkBase, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    CloseButton { dismiss() }
                }
            }
        }
    }

    private var rolePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("招待する人にできること")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(white: 0.56))
            roleOption("viewer", title: "見るだけ", detail: "記録と分析結果を見られます。録音・プロフィールの編集・招待はできません。")
            roleOption("owner", title: "録音・編集もできる", detail: "あなたと同じように、録音・プロフィールの編集・ほかの人の招待ができます。")

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundColor(.accentCoral)
            }

            Button(action: create) {
                HStack {
                    if isCreating {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "qrcode")
                        Text("招待の QR を作る")
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color.safeColor("AppAccentColor"))
                .cornerRadius(12)
            }
            .disabled(isCreating)
            .padding(.top, 8)
        }
    }

    private func roleOption(_ value: String, title: String, detail: String) -> some View {
        Button { role = value } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: role == value ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(role == value ? .accentTeal : Color(white: 0.45))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Text(detail)
                        .font(.system(size: 13))
                        .foregroundColor(Color(white: 0.56))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.darkCard))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(role == value ? Color.accentTeal.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func qrView(_ invite: SubjectInvite) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, Int(invite.expiresAt.timeIntervalSince(context.date)))
            VStack(spacing: 16) {
                Text(role == "owner" ? "録音・編集もできる招待" : "見るだけの招待")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                if remaining > 0, let image = QRCodeService.image(for: invite.url) {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(12)
                        .frame(maxWidth: 280)
                    Text("あと \(remaining / 60):\(String(format: "%02d", remaining % 60)) 有効・1 回だけ使えます")
                        .font(.system(size: 13).monospacedDigit())
                        .foregroundColor(Color(white: 0.56))
                    Text("相手の iPhone で WatchMe を開き、「分析対象」→「QR を読んで共有に参加」で読み取ってもらってください。")
                        .font(.system(size: 13))
                        .foregroundColor(Color(white: 0.56))
                        .multilineTextAlignment(.center)
                } else {
                    Text("この QR は期限が切れました")
                        .font(.system(size: 14))
                        .foregroundColor(Color(white: 0.56))
                    Button("もう一度作る") { self.invite = nil }
                        .foregroundColor(.accentTeal)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func create() {
        isCreating = true
        errorMessage = nil
        Task {
            do {
                let made = try await subjectManager.createInvite(subjectId: entry.subjectId, role: role)
                await MainActor.run { invite = made; isCreating = false }
            } catch {
                print("❌ Failed to create an invite: \(error)")
                await MainActor.run {
                    errorMessage = "招待を作れませんでした。通信状況を確かめて、もう一度お試しください。"
                    isCreating = false
                }
            }
        }
    }
}

// MARK: - Join (read an invite QR)

struct JoinSubjectSheet: View {
    @EnvironmentObject private var subjectManager: SubjectManager
    @EnvironmentObject private var userAccountManager: UserAccountManager
    @EnvironmentObject private var toastManager: ToastManager
    @Environment(\.dismiss) private var dismiss

    /// Called with the joined subject's name after a successful join.
    var onJoined: () -> Void = {}

    @State private var cameraAllowed: Bool? = nil
    @State private var isJoining = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                switch cameraAllowed {
                case .some(true):
                    QRScannerView { text in handle(text) }
                        .ignoresSafeArea()
                    overlay
                case .some(false):
                    Text("カメラを使えません。設定アプリで WatchMe のカメラを許可してください。")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(32)
                case .none:
                    ProgressView().tint(.white)
                }
            }
            .navigationTitle("QR を読んで共有に参加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.darkBase, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    CloseButton { dismiss() }
                }
            }
        }
        .task { await askCamera() }
    }

    private var overlay: some View {
        VStack {
            Spacer()
            VStack(spacing: 8) {
                if isJoining {
                    ProgressView().tint(.white)
                    Text("参加しています…")
                } else if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.accentCoral)
                    Button("もう一度読む") { self.errorMessage = nil }
                        .foregroundColor(.accentTeal)
                } else {
                    Text("共有する人の画面に出ている QR を写してください")
                }
            }
            .font(.system(size: 14))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.7)))
            .padding(20)
        }
    }

    private func askCamera() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: cameraAllowed = true
        case .notDetermined: cameraAllowed = await AVCaptureDevice.requestAccess(for: .video)
        default: cameraAllowed = false
        }
    }

    private func handle(_ text: String) {
        guard !isJoining, errorMessage == nil else { return }
        guard let code = SubjectInvite.code(in: text) else {
            errorMessage = "WatchMe の招待の QR ではありません"
            return
        }
        guard let userId = userAccountManager.currentUser?.id else { return }
        isJoining = true
        HapticManager.shared.playSelectionHaptic()
        Task {
            do {
                let name = try await subjectManager.join(code: code, userId: userId)
                await MainActor.run {
                    toastManager.showSuccess(title: "\(name)の共有に参加しました")
                    dismiss()
                    onJoined()
                }
            } catch {
                await MainActor.run {
                    isJoining = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

/// Camera preview that reports each QR code it reads.
private struct QRScannerView: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerController {
        let controller = ScannerController()
        controller.onCode = onCode
        return controller
    }

    func updateUIViewController(_ controller: ScannerController, context: Context) {
        controller.onCode = onCode
    }

    final class ScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
        var onCode: ((String) -> Void)?
        private let session = AVCaptureSession()
        private var preview: AVCaptureVideoPreviewLayer?
        private var lastCode: String?
        private var lastTime = Date.distantPast

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
            guard let camera = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: camera),
                  session.canAddInput(input) else { return }
            session.addInput(input)
            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else { return }
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]

            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(layer)
            preview = layer
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            preview?.frame = view.bounds
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            let session = self.session
            DispatchQueue.global(qos: .userInitiated).async { if !session.isRunning { session.startRunning() } }
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            let session = self.session
            DispatchQueue.global(qos: .userInitiated).async { if session.isRunning { session.stopRunning() } }
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard let text = (objects.first as? AVMetadataMachineReadableCodeObject)?.stringValue else { return }
            // The same code stays in view; report it again only after a pause.
            if text == lastCode && Date().timeIntervalSince(lastTime) < 3 { return }
            lastCode = text
            lastTime = Date()
            onCode?(text)
        }
    }
}
