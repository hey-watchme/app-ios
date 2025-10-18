//
//  RecordingStoreTests.swift
//  ios_watchme_v9Tests
//
//  RecordingStoreのユニットテスト
//  UIから独立してビジネスロジックの正しさを検証
//

import XCTest
import Combine
@testable import ios_watchme_v9

class RecordingStoreTests: XCTestCase {
    var store: RecordingStore!
    var mockAudioService: MockAudioRecorderService!
    var mockUploaderService: MockUploaderService!
    var deviceManager: DeviceManager!
    var userAccountManager: UserAccountManager!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        cancellables = []

        // モックサービスの準備
        mockAudioService = MockAudioRecorderService()
        mockUploaderService = MockUploaderService()
        deviceManager = DeviceManager()
        userAccountManager = UserAccountManager(deviceManager: deviceManager)

        // RecordingStoreの初期化
        store = RecordingStore(
            audioService: mockAudioService,
            uploaderService: mockUploaderService,
            deviceManager: deviceManager,
            userAccountManager: userAccountManager
        )
    }

    override func tearDown() {
        cancellables = nil
        store = nil
        mockAudioService = nil
        mockUploaderService = nil
        super.tearDown()
    }

    // MARK: - 初期化テスト

    @MainActor
    func testInitialization() async {
        // 初期状態の確認
        XCTAssertFalse(store.state.isInitialized)
        XCTAssertFalse(store.state.isAudioSessionPrepared)

        // 初期化実行
        await store.initialize()

        // 初期化後の状態確認
        XCTAssertTrue(store.state.isInitialized)
        XCTAssertTrue(store.state.isAudioSessionPrepared)
    }

    // MARK: - 録音テスト

    @MainActor
    func testStartRecording() async {
        // 事前準備
        await store.initialize()
        userAccountManager.testSetAuthenticated(true)
        deviceManager.testSetSelectedDevice("test-device")

        // 録音開始前の状態確認
        XCTAssertFalse(store.state.isRecording)
        XCTAssertNil(store.state.recordingStartTime)

        // 録音開始
        await store.startRecording()

        // 録音開始後の状態確認
        XCTAssertTrue(store.state.isRecording)
        XCTAssertNotNil(store.state.recordingStartTime)
        XCTAssertFalse(store.state.currentSlot.isEmpty)
    }

    @MainActor
    func testStopRecording() async {
        // 録音開始
        await store.initialize()
        userAccountManager.testSetAuthenticated(true)
        deviceManager.testSetSelectedDevice("test-device")
        await store.startRecording()

        // 録音停止
        await store.stopRecording()

        // 録音停止後の状態確認
        XCTAssertFalse(store.state.isRecording)
        XCTAssertEqual(store.state.recordingDuration, 0)
    }

    // MARK: - アップロードテスト

    @MainActor
    func testBatchUploadSuccess() async {
        // テスト用録音ファイルを追加
        let recording1 = RecordingModel(fileName: "2025-10-17/10-00.wav", date: Date())
        let recording2 = RecordingModel(fileName: "2025-10-17/10-30.wav", date: Date())
        store.state.recordings = [recording1, recording2]

        // アップロード成功を設定
        mockUploaderService.shouldSucceed = true

        // 一括アップロード開始
        await store.startBatchUpload()

        // アップロード完了後の状態確認
        XCTAssertFalse(store.state.isUploading)
        XCTAssertEqual(store.state.uploadStats.success, 2)
        XCTAssertEqual(store.state.uploadStats.failure, 0)
        XCTAssertTrue(store.state.recordings.isEmpty) // 成功したファイルは削除される
    }

    @MainActor
    func testBatchUploadFailure() async {
        // テスト用録音ファイルを追加
        let recording = RecordingModel(fileName: "2025-10-17/11-00.wav", date: Date())
        store.state.recordings = [recording]

        // アップロード失敗を設定
        mockUploaderService.shouldSucceed = false

        // 一括アップロード開始
        await store.startBatchUpload()

        // アップロード完了後の状態確認
        XCTAssertFalse(store.state.isUploading)
        XCTAssertEqual(store.state.uploadStats.success, 0)
        XCTAssertEqual(store.state.uploadStats.failure, 1)
        XCTAssertEqual(store.state.recordings.count, 1) // 失敗したファイルは残る
    }

    // MARK: - エラーハンドリングテスト

    @MainActor
    func testStartRecordingWithoutPermission() async {
        // 権限なしの状態
        userAccountManager.testSetAuthenticated(false)

        // 録音開始
        await store.startRecording()

        // エラー確認
        XCTAssertFalse(store.state.isRecording)
        XCTAssertNotNil(store.state.errorMessage)
        XCTAssertTrue(store.state.showError)
    }

    @MainActor
    func testStartRecordingWithoutDevice() async {
        // デバイス未選択
        await store.initialize()
        userAccountManager.testSetAuthenticated(true)
        // deviceManager.selectedDeviceID = nil (デフォルト)

        // 録音開始
        await store.startRecording()

        // エラー確認
        XCTAssertFalse(store.state.isRecording)
        XCTAssertNotNil(store.state.errorMessage)
    }
}

// MARK: - Mock Services

class MockAudioRecorderService: AudioRecorderService {
    var shouldSucceed = true
    var prepareSessionCalled = false
    var startRecordingCalled = false
    var stopRecordingCalled = false

    override func prepareAudioSession() async throws {
        prepareSessionCalled = true
        if !shouldSucceed {
            throw RecordingError.startFailed
        }
    }

    override func startRecording(fileName: String) async throws {
        startRecordingCalled = true
        if !shouldSucceed {
            throw RecordingError.startFailed
        }
    }

    override func stopRecording() async throws -> URL {
        stopRecordingCalled = true
        if !shouldSucceed {
            throw RecordingError.notRecording
        }
        return URL(fileURLWithPath: "/tmp/test.wav")
    }

    override func loadRecordings() async throws -> [RecordingModel] {
        return []
    }
}

class MockUploaderService: UploaderService {
    var shouldSucceed = true

    override func uploadRecording(_ recording: RecordingModel) async throws {
        if !shouldSucceed {
            throw UploadError.serverError(statusCode: 500)
        }
    }
}

// MARK: - Test Helpers

extension UserAccountManager {
    func testSetAuthenticated(_ authenticated: Bool) {
        // テスト用のヘルパーメソッド
        // 実際の実装では適切なモック化が必要
    }
}

extension DeviceManager {
    func testSetSelectedDevice(_ deviceID: String?) {
        // テスト用のヘルパーメソッド
        // 実際の実装では適切なモック化が必要
    }
}