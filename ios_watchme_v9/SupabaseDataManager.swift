//
//  SupabaseDataManager.swift
//  ios_watchme_v9
//
//  Created by Claude on 2025/07/25.
//

import Foundation
import SwiftUI
import Supabase

// MARK: - Supabaseデータ管理クラス
// vibe_whisper_summaryテーブルからデータを取得・管理する責務を持つ
@MainActor
class SupabaseDataManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var dailyReport: DailyVibeReport?
    @Published var dailyBehaviorReport: BehaviorReport? // 新しく追加
    @Published var dailyEmotionReport: EmotionReport?   // 新しく追加
    @Published var weeklyReports: [DailyVibeReport] = []
    @Published var deviceMetadata: DeviceMetadata?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let supabaseURL = "https://qvtlwotzuzbavrzqhyvt.supabase.co"
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2dGx3b3R6dXpiYXZyenFoeXZ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTEzODAzMzAsImV4cCI6MjA2Njk1NjMzMH0.g5rqrbxHPw1dKlaGqJ8miIl9gCXyamPajinGCauEI3k"
    
    // 日付フォーマッター
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    // MARK: - Initialization
    init() {
        print("📊 SupabaseDataManager initialized")
    }
    
    // MARK: - Public Methods
    
    /// 特定の日付のレポートを取得
    func fetchDailyReport(for deviceId: String, date: Date) async {
        // このメソッドはfetchAllReportsから呼ばれることを想定
        // エラー時はerrorMessageを設定し、UIに即座に反映させる
        
        let dateString = dateFormatter.string(from: date)
        print("📅 Fetching daily report for device: \(deviceId), date: \(dateString)")
        
        do {
            // Supabase SDKの標準メソッドを使用
            let reports: [DailyVibeReport] = try await supabase
                .from("vibe_whisper_summary")
                .select()
                .eq("device_id", value: deviceId)
                .eq("date", value: dateString)
                .execute()
                .value
            
            print("📊 Decoded reports count: \(reports.count)")
            
            await MainActor.run { [weak self] in
                if let report = reports.first {
                    self?.dailyReport = report
                    print("✅ Daily report fetched successfully")
                    print("   Average score: \(report.averageScore)")
                    print("   Insights count: \(report.insights.count)")
                } else {
                    print("⚠️ No report found for the specified date")
                    self?.dailyReport = nil
                }
            }
            
        } catch {
            print("❌ Fetch error: \(error)")
            await MainActor.run { [weak self] in
                self?.errorMessage = "データの取得に失敗しました: \(error.localizedDescription)"
                
                // PostgrestErrorの詳細を表示
                if let dbError = error as? PostgrestError {
                    print("   - コード: \(dbError.code ?? "不明")")
                    print("   - メッセージ: \(dbError.message)")
                }
            }
        }
    }
    
    /// 日付範囲でレポートを取得（週次表示用）
    /// - Note: 現在は未使用。将来の週次グラフ機能実装時に使用予定
    /// - TODO: 週次グラフ機能を実装する際にこのメソッドを活用
    func fetchWeeklyReports(for deviceId: String, startDate: Date, endDate: Date) async {
        isLoading = true
        errorMessage = nil
        weeklyReports = []
        
        let startDateString = dateFormatter.string(from: startDate)
        let endDateString = dateFormatter.string(from: endDate)
        
        print("📅 Fetching weekly reports for device: \(deviceId)")
        print("   From: \(startDateString) To: \(endDateString)")
        
        do {
            // Supabase SDKの標準メソッドを使用
            let reports: [DailyVibeReport] = try await supabase
                .from("vibe_whisper_summary")
                .select()
                .eq("device_id", value: deviceId)
                .gte("date", value: startDateString)
                .lte("date", value: endDateString)
                .order("date", ascending: true)
                .execute()
                .value
            
            self.weeklyReports = reports
            
            print("✅ Weekly reports fetched successfully")
            print("   Reports count: \(reports.count)")
            
        } catch {
            print("❌ Fetch error: \(error)")
            errorMessage = "エラー: \(error.localizedDescription)"
            
            // PostgrestErrorの詳細を表示
            if let dbError = error as? PostgrestError {
                print("   - コード: \(dbError.code ?? "不明")")
                print("   - メッセージ: \(dbError.message)")
            }
        }
        
        isLoading = false
    }
    
    /// データをクリア
    func clearData() {
        dailyReport = nil
        dailyBehaviorReport = nil
        dailyEmotionReport = nil
        weeklyReports = []
        deviceMetadata = nil
        errorMessage = nil
    }
    
    /// 統合データフェッチメソッド - すべてのグラフデータを一括で取得
    func fetchAllReports(deviceId: String, date: Date) async {
        await MainActor.run { [weak self] in
            self?.isLoading = true
            self?.errorMessage = nil
        }
        
        let dateString = dateFormatter.string(from: date)
        print("🔄 Fetching all reports for device: \(deviceId), date: \(dateString)")
        
        // 並行してすべてのレポートを取得
        await withTaskGroup(of: Void.self) { group in
            // Vibeレポートの取得
            group.addTask { [weak self] in
                await self?.fetchDailyReport(for: deviceId, date: date)
            }
            
            // 行動レポートの取得
            group.addTask { [weak self] in
                let report = await self?.fetchBehaviorReport(deviceId: deviceId, date: dateString)
                await MainActor.run { [weak self] in
                    self?.dailyBehaviorReport = report
                }
            }
            
            // 感情レポートの取得
            group.addTask { [weak self] in
                let report = await self?.fetchEmotionReport(deviceId: deviceId, date: dateString)
                await MainActor.run { [weak self] in
                    self?.dailyEmotionReport = report
                }
            }
            
            // デバイスメタデータの取得
            group.addTask { [weak self] in
                await self?.fetchDeviceMetadata(for: deviceId)
            }
        }
        
        await MainActor.run { [weak self] in
            self?.isLoading = false
            print("✅ All reports fetching completed")
        }
    }
    
    // MARK: - Behavior Report Methods
    
    /// 特定の日付の行動レポートを取得
    func fetchBehaviorReport(deviceId: String, date: String) async -> BehaviorReport? {
        print("📊 Fetching behavior report for device: \(deviceId), date: \(date)")
        
        do {
            // Supabase SDKの標準メソッドを使用
            let reports: [BehaviorReport] = try await supabase
                .from("behavior_summary")
                .select()
                .eq("device_id", value: deviceId)
                .eq("date", value: date)
                .execute()
                .value
            
            if let report = reports.first {
                print("✅ Behavior report fetched successfully")
                print("   Total events: \(report.totalEventCount)")
                print("   Active time blocks: \(report.activeTimeBlocks.count)")
                return report
            } else {
                print("⚠️ No behavior report found for the specified date")
                return nil
            }
            
        } catch {
            print("❌ Behavior fetch error: \(error)")
            await MainActor.run { [weak self] in
                self?.errorMessage = "行動データの取得エラー: \(error.localizedDescription)"
                
                // PostgrestErrorの詳細を表示
                if let dbError = error as? PostgrestError {
                    print("   - コード: \(dbError.code ?? "不明")")
                    print("   - メッセージ: \(dbError.message)")
                }
            }
            return nil
        }
    }
    
    // MARK: - Emotion Report Methods
    
    /// 特定の日付の感情レポートを取得
    func fetchEmotionReport(deviceId: String, date: String) async -> EmotionReport? {
        print("🎭 Fetching emotion report for device: \(deviceId), date: \(date)")
        
        do {
            // Supabase SDKの標準メソッドを使用
            let reports: [EmotionReport] = try await supabase
                .from("emotion_opensmile_summary")
                .select()
                .eq("device_id", value: deviceId)
                .eq("date", value: date)
                .execute()
                .value
            
            if let report = reports.first {
                print("✅ Emotion report fetched successfully")
                print("   Emotion graph points: \(report.emotionGraph.count)")
                print("   Active time points: \(report.activeTimePoints.count)")
                return report
            } else {
                print("⚠️ No emotion report found for the specified date")
                return nil
            }
            
        } catch {
            print("❌ Emotion fetch error: \(error)")
            await MainActor.run { [weak self] in
                self?.errorMessage = "感情データの取得エラー: \(error.localizedDescription)"
                
                // PostgrestErrorの詳細を表示
                if let dbError = error as? PostgrestError {
                    print("   - コード: \(dbError.code ?? "不明")")
                    print("   - メッセージ: \(dbError.message)")
                }
            }
            return nil
        }
    }
    
    /// デバイスメタデータを取得
    func fetchDeviceMetadata(for deviceId: String) async {
        print("👤 Fetching device metadata for device: \(deviceId)")
        
        do {
            // Supabase SDKの標準メソッドを使用
            let metadataArray: [DeviceMetadata] = try await supabase
                .from("device_metadata")
                .select()
                .eq("device_id", value: deviceId)
                .execute()
                .value
            
            // MainActorで@Publishedプロパティを更新
            await MainActor.run { [weak self] in
                self?.deviceMetadata = metadataArray.first
                if let metadata = metadataArray.first {
                    print("✅ Device metadata fetched successfully")
                    print("   Name: \(metadata.name ?? "N/A")")
                    print("   Age: \(metadata.age ?? 0)")
                    print("   Gender: \(metadata.gender ?? "N/A")")
                } else {
                    print("ℹ️ No device metadata found")
                }
            }
            
        } catch {
            print("❌ Device metadata fetch error: \(error)")
            // PostgrestErrorの詳細を表示
            if let dbError = error as? PostgrestError {
                print("   - コード: \(dbError.code ?? "不明")")
                print("   - メッセージ: \(dbError.message)")
            }
        }
    }
    
    // MARK: - Avatar Methods
    
    /// ユーザーのアバター画像の署名付きURLを取得する
    /// - Parameter userId: 取得対象のユーザーID
    /// - Returns: 1時間有効なアバター画像のURL。存在しない、またはエラーの場合はnil。
    func fetchAvatarUrl(for userId: String) async -> URL? {
        print("👤 Fetching avatar URL for user: \(userId)")
        
        // 1. ファイルパスを構築
        let path = "\(userId)/avatar.webp"
        
        do {
            // 2. ファイルの存在を確認 (任意だが推奨)
            //    Web側の実装に合わせて、listで存在確認を行う
            let files = try await supabase.storage
                .from("avatars")
                .list(path: userId, options: SearchOptions(limit: 1, search: "avatar.webp"))
            
            // ファイルが見つからなければ、URLは存在しないのでnilを返す
            guard !files.isEmpty else {
                print("🤷‍♂️ Avatar file not found at path: \(path)")
                return nil
            }
            print("✅ Avatar file found. Proceeding to get signed URL.")
            
            // 3. 署名付きURLを生成 (Web側と同じく1時間有効)
            let signedURL = try await supabase.storage
                .from("avatars")
                .createSignedURL(path: path, expiresIn: 3600)
            
            print("🔗 Successfully created signed URL: \(signedURL)")
            return signedURL
            
        } catch {
            // エラーログを出力
            print("❌ Failed to fetch avatar URL: \(error.localizedDescription)")
            
            // エラー内容をUIに表示したい場合は、ここでerrorMessageを更新しても良い
            // await MainActor.run {
            //     self.errorMessage = "アバターの取得に失敗しました。"
            // }
            
            return nil
        }
    }
}