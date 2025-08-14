//
//  DashboardViewModel.swift
//  ios_watchme_v9
//
//  Created by Claude on 2025/07/31.
//

import Foundation
import Combine
import SwiftUI

@MainActor
class DashboardViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var selectedDate: Date = Date()
    @Published var selectedDeviceID: String? = nil
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var currentFetchID: UUID = UUID()
    
    // MARK: - Display Data (ViewModelが管理する表示用データ)
    @Published private(set) var vibeReport: DailyVibeReport?
    @Published private(set) var behaviorReport: BehaviorReport?
    @Published private(set) var emotionReport: EmotionReport?
    @Published private(set) var subject: Subject?
    
    // MARK: - Dependencies
    @Published private(set) var dataManager: SupabaseDataManager
    @Published private(set) var deviceManager: DeviceManager
    
    // MARK: - Cache
    struct CachedData {
        let vibeReport: DailyVibeReport?
        let behaviorReport: BehaviorReport?
        let emotionReport: EmotionReport?
        let subject: Subject?
        let fetchedAt: Date
    }
    
    private var dataCache: [String: CachedData] = [:]
    private let cacheExpirationInterval: TimeInterval = 300 // 5分間のキャッシュ
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var fetchTask: Task<Void, Never>?
    private var preloadTasks: [String: Task<Void, Never>] = [:]
    
    // MARK: - Initialization
    init(dataManager: SupabaseDataManager, deviceManager: DeviceManager, initialDate: Date) {
        self.dataManager = dataManager
        self.deviceManager = deviceManager
        // デバイスのタイムゾーンで日付を正規化
        self.selectedDate = deviceManager.deviceCalendar.startOfDay(for: initialDate)
        self.selectedDeviceID = deviceManager.selectedDeviceID
        
        setupBindings()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // 日付とデバイスIDの変更を監視
        Publishers.CombineLatest($selectedDate, $selectedDeviceID)
            .debounce(for: .seconds(0.3), scheduler: RunLoop.main)
            .sink { [weak self] date, deviceID in
                Task { [weak self] in
                    await self?.fetchAllReports()
                }
            }
            .store(in: &cancellables)
        
        // DeviceManagerのselectedDeviceIDの変更も監視
        deviceManager.$selectedDeviceID
            .sink { [weak self] newDeviceID in
                self?.selectedDeviceID = newDeviceID
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    func onAppear() {
        // 初回データ取得
        Task {
            await fetchAllReports()
        }
    }
    
    func updateSelectedDate(_ date: Date) {
        // デバイスのタイムゾーンで日付を正規化
        self.selectedDate = deviceManager.deviceCalendar.startOfDay(for: date)
    }
    
    // MARK: - Cache Methods
    func getCachedData(for date: Date) -> CachedData? {
        guard let deviceId = selectedDeviceID ?? deviceManager.localDeviceIdentifier else {
            return nil
        }
        
        let cacheKey = makeCacheKey(deviceId: deviceId, date: date)
        
        // キャッシュから取得
        if let cached = dataCache[cacheKey],
           Date().timeIntervalSince(cached.fetchedAt) < cacheExpirationInterval {
            return cached
        }
        
        return nil
    }
    
    // MARK: - Preload Methods
    func preloadReports(for dates: [Date]) {
        guard let deviceId = selectedDeviceID ?? deviceManager.localDeviceIdentifier else {
            return
        }
        
        print("🔄 Preloading reports for \(dates.count) dates")
        
        for date in dates {
            let cacheKey = makeCacheKey(deviceId: deviceId, date: date)
            
            // キャッシュに存在し、有効期限内の場合はスキップ
            if let cached = dataCache[cacheKey],
               Date().timeIntervalSince(cached.fetchedAt) < cacheExpirationInterval {
                print("⏭️ Skipping preload for \(cacheKey) - already in cache")
                continue
            }
            
            // 既にプリロード中の場合はスキップ
            if preloadTasks[cacheKey] != nil {
                print("⏭️ Skipping preload for \(cacheKey) - already loading")
                continue
            }
            
            // プリロードタスクを開始
            print("🚀 Starting preload for \(cacheKey)")
            let task = Task {
                await preloadReport(deviceId: deviceId, date: date, cacheKey: cacheKey)
            }
            preloadTasks[cacheKey] = task
        }
    }
    
    // MARK: - Private Methods
    private func fetchAllReports() async {
        // 新しいfetchIDを生成
        let fetchID = UUID()
        currentFetchID = fetchID
        
        // 既存のタスクをキャンセル
        fetchTask?.cancel()
        
        fetchTask = Task {
            guard !Task.isCancelled else { return }
            
            // ローディング状態を開始
            await MainActor.run {
                self.isLoading = true
            }
            
            // デバイスIDの確認
            guard let deviceId = selectedDeviceID ?? deviceManager.localDeviceIdentifier else {
                await MainActor.run {
                    self.isLoading = false
                }
                return
            }
            
            // このタスクがまだ最新かチェック
            guard currentFetchID == fetchID else {
                await MainActor.run {
                    self.isLoading = false
                }
                return
            }
            
            // まずキャッシュを確認
            if let cached = getCachedData(for: selectedDate) {
                // キャッシュからデータを適用
                await MainActor.run {
                    // このタスクがまだ最新かチェック
                    guard self.currentFetchID == fetchID else { return }
                    
                    // ViewModelの表示用プロパティを更新（dataManagerには触らない）
                    self.vibeReport = cached.vibeReport
                    self.behaviorReport = cached.behaviorReport
                    self.emotionReport = cached.emotionReport
                    self.subject = cached.subject
                    self.isLoading = false
                }
                print("📱 Using cached data for \(selectedDate)")
                return
            }
            
            // キャッシュにない場合は通常通りデータ取得
            // デバイスのタイムゾーンを渡す
            let timezone = deviceManager.getTimezone(for: deviceId)
            let fetchResult = await dataManager.fetchAllReports(deviceId: deviceId, date: selectedDate, timezone: timezone)
            
            // このタスクがまだ最新かチェック
            guard currentFetchID == fetchID else {
                await MainActor.run {
                    self.isLoading = false
                }
                return
            }
            
            // 取得したデータをキャッシュに保存
            let cacheKey = makeCacheKey(deviceId: deviceId, date: selectedDate)
            let cachedData = CachedData(
                vibeReport: fetchResult.vibeReport,
                behaviorReport: fetchResult.behaviorReport,
                emotionReport: fetchResult.emotionReport,
                subject: fetchResult.subject,
                fetchedAt: Date()
            )
            dataCache[cacheKey] = cachedData
            
            // ViewModelの表示用プロパティを更新（fetchIDチェック後のみ）
            await MainActor.run {
                // 最終確認：このタスクがまだ最新か
                guard self.currentFetchID == fetchID else { 
                    self.isLoading = false
                    return 
                }
                
                self.vibeReport = fetchResult.vibeReport
                self.behaviorReport = fetchResult.behaviorReport
                self.emotionReport = fetchResult.emotionReport
                self.subject = fetchResult.subject
                self.isLoading = false
            }
        }
    }
    
    // 強制的にキャッシュをクリアしてデータを再取得するメソッド
    func forceRefreshData() async {
        // キャッシュをクリア
        dataCache.removeAll()
        
        // データを再取得
        await fetchAllReports()
    }
    
    private func makeCacheKey(deviceId: String, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        // デバイスのタイムゾーンを使用して日付文字列を生成
        formatter.timeZone = deviceManager.getTimezone(for: deviceId)
        return "\(deviceId)_\(formatter.string(from: date))"
    }
    
    private func preloadReport(deviceId: String, date: Date, cacheKey: String) async {
        defer {
            preloadTasks.removeValue(forKey: cacheKey)
        }
        
        // SupabaseDataManagerのフェッチメソッドを直接呼び出す
        // 注：現在のSupabaseDataManagerは単一の日付のみサポートしているため、
        // 一時的に新しいインスタンスを作成してデータを取得
        let tempDataManager = SupabaseDataManager()
        // デバイスのタイムゾーンを渡す
        let timezone = deviceManager.getTimezone(for: deviceId)
        let fetchResult = await tempDataManager.fetchAllReports(deviceId: deviceId, date: date, timezone: timezone)
        
        // 取得したデータをキャッシュに保存
        let cachedData = CachedData(
            vibeReport: fetchResult.vibeReport,
            behaviorReport: fetchResult.behaviorReport,
            emotionReport: fetchResult.emotionReport,
            subject: fetchResult.subject,
            fetchedAt: Date()
        )
        
        dataCache[cacheKey] = cachedData
        
        print("📦 Preloaded data for \(cacheKey)")
    }
}