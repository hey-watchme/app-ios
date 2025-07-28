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
        
        // URLの構築
        guard let url = URL(string: "\(supabaseURL)/rest/v1/vibe_whisper_summary") else {
            // エラーはfetchAllReportsでまとめて処理するため、ここではthrowしない
            return
        }
        
        // クエリパラメータの構築
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "device_id", value: "eq.\(deviceId)"),
            URLQueryItem(name: "date", value: "eq.\(dateString)"),
            URLQueryItem(name: "select", value: "*")
        ]
        
        guard let requestURL = components?.url else {
            return
        }
        
        // リクエストの構築
        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return
            }
            
            print("📡 Response status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                if let rawResponse = String(data: data, encoding: .utf8) {
                    print("📄 Raw response: \(rawResponse)")
                }
                
                let decoder = JSONDecoder()
                do {
                    let reports = try decoder.decode([DailyVibeReport].self, from: data)
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
                    print("❌ Decoding error: \(error)")
                    await MainActor.run { [weak self] in
                        self?.errorMessage = "データの解析に失敗しました: \(error.localizedDescription)"
                    }
                }
            } else {
                if let errorData = String(data: data, encoding: .utf8) {
                    print("❌ Error response: \(errorData)")
                }
                await MainActor.run { [weak self] in
                    self?.errorMessage = "データの取得に失敗しました (Status: \(httpResponse.statusCode))"
                }
            }
            
        } catch {
            print("❌ Fetch error: \(error)")
            await MainActor.run { [weak self] in
                self?.errorMessage = "エラー: \(error.localizedDescription)"
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
        
        // URLの構築
        guard let url = URL(string: "\(supabaseURL)/rest/v1/vibe_whisper_summary") else {
            errorMessage = "無効なURL"
            isLoading = false
            return
        }
        
        // クエリパラメータの構築
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "device_id", value: "eq.\(deviceId)"),
            URLQueryItem(name: "date", value: "gte.\(startDateString)"),
            URLQueryItem(name: "date", value: "lte.\(endDateString)"),
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "order", value: "date.asc")
        ]
        
        guard let requestURL = components?.url else {
            errorMessage = "URLの構築に失敗しました"
            isLoading = false
            return
        }
        
        // リクエストの構築
        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = "無効なレスポンス"
                isLoading = false
                return
            }
            
            print("📡 Response status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                // レスポンスをデコード
                let decoder = JSONDecoder()
                
                let reports = try decoder.decode([DailyVibeReport].self, from: data)
                self.weeklyReports = reports
                
                print("✅ Weekly reports fetched successfully")
                print("   Reports count: \(reports.count)")
            } else {
                if let errorData = String(data: data, encoding: .utf8) {
                    print("❌ Error response: \(errorData)")
                }
                errorMessage = "データの取得に失敗しました (Status: \(httpResponse.statusCode))"
            }
            
        } catch {
            print("❌ Fetch error: \(error)")
            errorMessage = "エラー: \(error.localizedDescription)"
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
        
        // URLの構築
        guard let url = URL(string: "\(supabaseURL)/rest/v1/behavior_summary") else {
            await MainActor.run { [weak self] in
                self?.errorMessage = "行動データ: 無効なURL"
            }
            return nil
        }
        
        // クエリパラメータの構築
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "device_id", value: "eq.\(deviceId)"),
            URLQueryItem(name: "date", value: "eq.\(date)"),
            URLQueryItem(name: "select", value: "*")
        ]
        
        guard let requestURL = components?.url else {
            await MainActor.run { [weak self] in
                self?.errorMessage = "行動データ: URLの構築に失敗しました"
            }
            return nil
        }
        
        // リクエストの構築
        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                await MainActor.run { [weak self] in
                    self?.errorMessage = "行動データ: 無効なレスポンス"
                }
                return nil
            }
            
            print("📡 Behavior response status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                if let rawResponse = String(data: data, encoding: .utf8) {
                    print("📄 Raw behavior response: \(rawResponse)")
                }
                
                let decoder = JSONDecoder()
                do {
                    let reports = try decoder.decode([BehaviorReport].self, from: data)
                    
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
                    print("❌ Behavior decoding error: \(error)")
                    await MainActor.run { [weak self] in
                        self?.errorMessage = "行動データの解析に失敗しました: \(error.localizedDescription)"
                    }
                    return nil
                }
            } else {
                if let errorData = String(data: data, encoding: .utf8) {
                    print("❌ Error response: \(errorData)")
                }
                await MainActor.run { [weak self] in
                    self?.errorMessage = "行動データの取得に失敗しました (Status: \(httpResponse.statusCode))"
                }
                return nil
            }
        } catch {
            print("❌ Behavior fetch error: \(error)")
            await MainActor.run { [weak self] in
                self?.errorMessage = "行動データの取得エラー: \(error.localizedDescription)"
            }
            return nil
        }
    }
    
    // MARK: - Emotion Report Methods
    
    /// 特定の日付の感情レポートを取得
    func fetchEmotionReport(deviceId: String, date: String) async -> EmotionReport? {
        print("🎭 Fetching emotion report for device: \(deviceId), date: \(date)")
        
        // URLの構築
        guard let url = URL(string: "\(supabaseURL)/rest/v1/emotion_opensmile_summary") else {
            await MainActor.run { [weak self] in
                self?.errorMessage = "感情データ: 無効なURL"
            }
            return nil
        }
        
        // クエリパラメータの構築
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "device_id", value: "eq.\(deviceId)"),
            URLQueryItem(name: "date", value: "eq.\(date)"),
            URLQueryItem(name: "select", value: "*")
        ]
        
        guard let requestURL = components?.url else {
            await MainActor.run { [weak self] in
                self?.errorMessage = "感情データ: URLの構築に失敗しました"
            }
            return nil
        }
        
        // リクエストの構築
        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                await MainActor.run { [weak self] in
                    self?.errorMessage = "感情データ: 無効なレスポンス"
                }
                return nil
            }
            
            print("📡 Emotion response status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                if let rawResponse = String(data: data, encoding: .utf8) {
                    print("📄 Raw emotion response: \(rawResponse)")
                }
                
                let decoder = JSONDecoder()
                do {
                    let reports = try decoder.decode([EmotionReport].self, from: data)
                    
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
                    print("❌ Emotion decoding error: \(error)")
                    await MainActor.run { [weak self] in
                        self?.errorMessage = "感情データの解析に失敗しました: \(error.localizedDescription)"
                    }
                    return nil
                }
            } else {
                if let errorData = String(data: data, encoding: .utf8) {
                    print("❌ Error response: \(errorData)")
                }
                await MainActor.run { [weak self] in
                    self?.errorMessage = "感情データの取得に失敗しました (Status: \(httpResponse.statusCode))"
                }
                return nil
            }
        } catch {
            print("❌ Emotion fetch error: \(error)")
            await MainActor.run { [weak self] in
                self?.errorMessage = "感情データの取得エラー: \(error.localizedDescription)"
            }
            return nil
        }
    }
    
    /// デバイスメタデータを取得
    func fetchDeviceMetadata(for deviceId: String) async {
        print("👤 Fetching device metadata for device: \(deviceId)")
        
        // URLの構築
        guard let url = URL(string: "\(supabaseURL)/rest/v1/device_metadata") else {
            return
        }
        
        // クエリパラメータの構築
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "device_id", value: "eq.\(deviceId)"),
            URLQueryItem(name: "select", value: "*")
        ]
        
        guard let requestURL = components?.url else {
            return
        }
        
        // リクエストの構築
        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return
            }
            
            print("📡 Device metadata response status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                
                // レスポンスをまずArrayとしてデコード
                let metadataArray = try decoder.decode([DeviceMetadata].self, from: data)
                
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
            }
        } catch {
            print("❌ Device metadata fetch error: \(error)")
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