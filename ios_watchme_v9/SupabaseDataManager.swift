//
//  SupabaseDataManager.swift
//  ios_watchme_v9
//
//  Created by Claude on 2025/07/25.
//

import Foundation
import SwiftUI

// MARK: - Dashboard Data Structure
// 統合ダッシュボードデータ構造体
struct DashboardData {
    let vibeReport: DailyVibeReport?
    let behaviorReport: BehaviorReport?
    let emotionReport: EmotionReport?
    let subject: Subject?
}

// MARK: - RPC Response Structure
/// Supabase RPC関数 'get_dashboard_data' からの応答構造
/// ⚠️ 重要: この構造はSupabase側のRPC関数の出力と完全に一致する必要があります
/// RPC関数の変更時は、必ずこの構造体も更新してください
struct RPCDashboardResponse: Codable {
    let vibe_report: DailyVibeReport?
    let behavior_report: BehaviorReport?
    let emotion_report: EmotionReport?
    let subject_info: Subject?
    
    private enum CodingKeys: String, CodingKey {
        case vibe_report
        case behavior_report
        case emotion_report
        case subject_info
    }
}

// MARK: - Supabaseデータ管理クラス
// vibe_whisper_summaryテーブルからデータを取得・管理する責務を持つ
@MainActor
class SupabaseDataManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var dailyReport: DailyVibeReport?
    @Published var dailyBehaviorReport: BehaviorReport?
    @Published var dailyEmotionReport: EmotionReport?
    @Published var weeklyReports: [DailyVibeReport] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var subject: Subject?
    
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
    
    /// ユーザーIDから関連するデバイスIDを取得
    func fetchDeviceId(for userId: String) async -> String? {
        guard let url = URL(string: "\(supabaseURL)/rest/v1/devices") else {
            print("❌ 無効なURL")
            return nil
        }
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "owner_user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "select", value: "device_id"),
            URLQueryItem(name: "limit", value: "1")
        ]
        
        guard let requestURL = components?.url else {
            print("❌ URLの構築に失敗しました")
            return nil
        }
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ 無効なレスポンス")
                return nil
            }
            
            if httpResponse.statusCode == 200 {
                if let rawResponse = String(data: data, encoding: .utf8) {
                    print("📄 Device query response: \(rawResponse)")
                }
                
                struct DeviceResponse: Codable {
                    let device_id: String
                }
                
                let decoder = JSONDecoder()
                let devices = try decoder.decode([DeviceResponse].self, from: data)
                
                if let device = devices.first {
                    print("✅ Found device ID: \(device.device_id) for user: \(userId)")
                    return device.device_id
                } else {
                    print("⚠️ No device found for user: \(userId)")
                }
            }
        } catch {
            print("❌ Device fetch error: \(error)")
        }
        
        return nil
    }
    
    /// 特定の日付のレポートを取得
    func fetchDailyReport(for deviceId: String, date: Date) async {
        let dateString = dateFormatter.string(from: date)
        print("📅 Fetching daily report for device: \(deviceId), date: \(dateString)")
        
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
            URLQueryItem(name: "date", value: "eq.\(dateString)"),
            URLQueryItem(name: "select", value: "*")
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
                // レスポンスの生データを確認
                if let rawResponse = String(data: data, encoding: .utf8) {
                    print("📄 Raw response: \(rawResponse)")
                }
                
                // レスポンスをデコード
                let decoder = JSONDecoder()
                // processed_atはStringで受け取るため、特別な日付デコード戦略は不要
                
                do {
                    let reports = try decoder.decode([DailyVibeReport].self, from: data)
                    print("📊 Decoded reports count: \(reports.count)")
                    
                    if let report = reports.first {
                        self.dailyReport = report
                        print("✅ Daily report fetched successfully")
                        print("   Average score: \(report.averageScore)")
                        print("   Insights count: \(report.insights.count)")
                    } else {
                        print("⚠️ No report found for the specified date")
                        self.dailyReport = nil
                        self.errorMessage = "指定された日付のレポートが見つかりません"
                    }
                } catch {
                    print("❌ Decoding error: \(error)")
                    self.errorMessage = "データの解析に失敗しました: \(error.localizedDescription)"
                    
                    // デコードエラーの詳細を表示
                    if let decodingError = error as? DecodingError {
                        switch decodingError {
                        case .dataCorrupted(let context):
                            print("   Data corrupted: \(context)")
                        case .keyNotFound(let key, let context):
                            print("   Key not found: \(key), \(context)")
                        case .typeMismatch(let type, let context):
                            print("   Type mismatch: \(type), \(context)")
                        case .valueNotFound(let type, let context):
                            print("   Value not found: \(type), \(context)")
                        @unknown default:
                            print("   Unknown decoding error")
                        }
                    }
                }
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
    }
    
    /// 日付範囲でレポートを取得（週次表示用）
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
                // processed_atはStringで受け取るため、特別な日付デコード戦略は不要
                
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
        errorMessage = nil
    }
    
    /// 統合データフェッチメソッド - すべてのグラフデータを一括で取得
    /// DashboardDataを返し、互換性のため@Publishedプロパティも更新
    /// すべてのレポートを取得するメインメソッド
    /// 
    /// 🚀 このメソッドは内部でRPC関数 'get_dashboard_data' を使用します
    /// 1回のAPIコールで全データ（vibe, behavior, emotion, subject）を取得
    ///
    /// - Parameters:
    ///   - deviceId: デバイスID
    ///   - date: 取得したい日付
    ///   - timezone: タイムゾーン（現在は未使用、将来の拡張用）
    /// - Returns: DashboardData（すべてのレポートを含む）
    func fetchAllReports(deviceId: String, date: Date, timezone: TimeZone? = nil) async -> DashboardData {
        isLoading = true
        errorMessage = nil
        
        // 🎯 RPC関数を使用して全データを一括取得
        let dashboardData = await fetchAllReportsData(deviceId: deviceId, date: date)
        
        // @Publishedプロパティも更新（互換性のため）
        await MainActor.run {
            self.dailyReport = dashboardData.vibeReport
            self.dailyBehaviorReport = dashboardData.behaviorReport
            self.dailyEmotionReport = dashboardData.emotionReport
            self.subject = dashboardData.subject  // ✅ Subject情報も正しく設定
            self.isLoading = false
        }
        
        print("✅ [RPC] All reports fetching completed with subject info")
        return dashboardData
    }
    
    // MARK: - Data Fetching Methods
    
    /// 統合データフェッチメソッド - すべてのグラフデータを一括で取得
    /// 
    /// ⚠️ 重要: このメソッドはSupabase RPC関数 'get_dashboard_data' を使用します
    /// RPC関数は1回のAPIコールで以下のデータをすべて取得します：
    /// - vibe_report (心理データ)
    /// - behavior_report (行動データ)
    /// - emotion_report (感情データ)
    /// - subject_info (観測対象データ)
    ///
    /// 📝 RPC関数の更新が必要な場合：
    /// 1. Supabase側でRPC関数を更新
    /// 2. RPCDashboardResponse構造体を更新
    /// 3. 必要に応じてDashboardData構造体も更新
    ///
    /// - Parameters:
    ///   - deviceId: デバイスID（UUID形式）
    ///   - date: 取得したい日付
    /// - Returns: DashboardData（すべてのレポートを含む）
    func fetchAllReportsData(deviceId: String, date: Date) async -> DashboardData {
        let dateString = dateFormatter.string(from: date)
        print("🚀 [RPC] Fetching all dashboard data via RPC function")
        print("   Device: \(deviceId)")
        print("   Date: \(dateString)")
        
        do {
            // RPC関数のパラメータを準備
            let params = [
                "p_device_id": deviceId,
                "p_date": dateString
            ]
            
            // 📡 Supabase RPC関数を呼び出し（1回のAPIコールですべてのデータを取得）
            let response: [RPCDashboardResponse] = try await supabase
                .rpc("get_dashboard_data", params: params)
                .execute()
                .value
            
            // 最初の結果を取得（RPCは配列で返すが、通常1件のみ）
            guard let rpcData = response.first else {
                print("⚠️ [RPC] No data returned from RPC function")
                return DashboardData(
                    vibeReport: nil,
                    behaviorReport: nil,
                    emotionReport: nil,
                    subject: nil
                )
            }
            
            print("✅ [RPC] Successfully fetched all dashboard data")
            print("   - Vibe Report: \(rpcData.vibe_report != nil ? "✓" : "✗")")
            print("   - Behavior Report: \(rpcData.behavior_report != nil ? "✓" : "✗")")
            print("   - Emotion Report: \(rpcData.emotion_report != nil ? "✓" : "✗")")
            print("   - Subject Info: \(rpcData.subject_info != nil ? "✓" : "✗")")
            
            // RPCレスポンスをDashboardDataに変換
            return DashboardData(
                vibeReport: rpcData.vibe_report,
                behaviorReport: rpcData.behavior_report,
                emotionReport: rpcData.emotion_report,
                subject: rpcData.subject_info  // ✅ Subject情報も正しく取得
            )
            
        } catch {
            print("❌ [RPC] Failed to fetch dashboard data: \(error)")
            print("   Error details: \(error.localizedDescription)")
            
            // エラー時は空のデータを返す
            return DashboardData(
                vibeReport: nil,
                behaviorReport: nil,
                emotionReport: nil,
                subject: nil
            )
        }
    }
    
    /// ⚠️ 非推奨: 個別にデータを取得する旧メソッド
    /// このメソッドは互換性のために残していますが、新規実装では使用しないでください
    /// 代わりに fetchAllReportsData を使用してください（RPC関数による高速取得）
    @available(*, deprecated, message: "Use fetchAllReportsData instead (RPC-based)")
    private func fetchAllReportsDataLegacy(deviceId: String, date: Date) async -> DashboardData {
        // 旧実装（個別取得）のコード
        // この実装は保守されません
        return DashboardData(
            vibeReport: nil,
            behaviorReport: nil,
            emotionReport: nil,
            subject: nil
        )
    }
    
    /// 日次Vibeレポートを取得
    /// ⚠️ 非推奨: このメソッドは個別取得用です。fetchAllReportsData（RPC版）の使用を推奨します
    @available(*, deprecated, message: "Use fetchAllReportsData instead (RPC-based)")
    private func fetchDailyReportData(for deviceId: String, date: Date) async -> DailyVibeReport? {
        let dateString = dateFormatter.string(from: date)
        print("📊 日次レポートを取得中: device=\(deviceId), date=\(dateString)")
        
        // URLの構築
        guard let url = URL(string: "\(supabaseURL)/rest/v1/vibe_whisper_summary") else {
            print("❌ 無効なURL")
            return nil
        }
        
        // クエリパラメータの設定
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "device_id", value: "eq.\(deviceId)"),
            URLQueryItem(name: "date", value: "eq.\(dateString)"),
            URLQueryItem(name: "select", value: "*")
        ]
        
        guard let requestURL = components?.url else {
            print("❌ URLの構築に失敗しました")
            return nil
        }
        
        // リクエストの作成
        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // レスポンスのチェック
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ 無効なレスポンス")
                return nil
            }
            
            print("📡 Response status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                // JSONのデコード
                let decoder = JSONDecoder()
                let reports = try decoder.decode([DailyVibeReport].self, from: data)
                
                if let report = reports.first {
                    print("✅ レポート取得成功: \(report.date)")
                    return report
                } else {
                    print("⚠️ データが見つかりません")
                    return nil
                }
            } else {
                print("❌ HTTPエラー: \(httpResponse.statusCode)")
                return nil
            }
        } catch {
            print("❌ エラーが発生しました: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Behavior Report Methods
    
    /// 特定の日付の行動レポートを取得
    func fetchBehaviorReport(deviceId: String, date: String) async throws -> BehaviorReport? {
        print("📊 Fetching behavior report for device: \(deviceId), date: \(date)")
        
        // URLの構築
        guard let url = URL(string: "\(supabaseURL)/rest/v1/behavior_summary") else {
            throw URLError(.badURL)
        }
        
        // クエリパラメータの構築
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "device_id", value: "eq.\(deviceId)"),
            URLQueryItem(name: "date", value: "eq.\(date)"),
            URLQueryItem(name: "select", value: "*")
        ]
        
        guard let requestURL = components?.url else {
            throw URLError(.badURL)
        }
        
        // リクエストの構築
        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        print("📡 Behavior response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            // レスポンスの生データを確認
            if let rawResponse = String(data: data, encoding: .utf8) {
                print("📄 Raw behavior response: \(rawResponse)")
            }
            
            // レスポンスをデコード
            let decoder = JSONDecoder()
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
        } else {
            if let errorData = String(data: data, encoding: .utf8) {
                print("❌ Error response: \(errorData)")
            }
            throw URLError(.badServerResponse)
        }
    }
    
    // MARK: - Emotion Report Methods
    
    /// 特定の日付の感情レポートを取得
    func fetchEmotionReport(deviceId: String, date: String) async throws -> EmotionReport? {
        print("🎭 Fetching emotion report for device: \(deviceId), date: \(date)")
        
        // URLの構築
        guard let url = URL(string: "\(supabaseURL)/rest/v1/emotion_opensmile_summary") else {
            throw URLError(.badURL)
        }
        
        // クエリパラメータの構築
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "device_id", value: "eq.\(deviceId)"),
            URLQueryItem(name: "date", value: "eq.\(date)"),
            URLQueryItem(name: "select", value: "*")
        ]
        
        guard let requestURL = components?.url else {
            throw URLError(.badURL)
        }
        
        // リクエストの構築
        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        print("📡 Emotion response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            // レスポンスの生データを確認
            if let rawResponse = String(data: data, encoding: .utf8) {
                print("📄 Raw emotion response: \(rawResponse)")
            }
            
            // レスポンスをデコード
            let decoder = JSONDecoder()
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
        } else {
            if let errorData = String(data: data, encoding: .utf8) {
                print("❌ Error response: \(errorData)")
            }
            throw URLError(.badServerResponse)
        }
    }
    
    // MARK: - Avatar Management
    
    func fetchAvatarUrl(for userId: String) async -> URL? {
        print("👤 Fetching avatar URL for user: \(userId)")
        
        // 1. ファイルパスを構築
        let path = "\(userId)/avatar.webp"
        
        do {
            // 2. ファイルの存在を確認 (任意だが推奨)
            //    Web側の実装に合わせて、listで存在確認を行う
            let files = try await supabase.storage
                .from("avatars")
                .list(path: userId)
            
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
            return nil
        }
    }
    
    // MARK: - Subject Management Methods
    
    /// デバイスに関連付けられた観測対象を取得
    /// 観測対象（Subject）情報を取得
    /// ⚠️ 非推奨: fetchAllReportsData（RPC版）がSubject情報も含むため、個別取得は不要です
    @available(*, deprecated, message: "Use fetchAllReportsData instead (includes subject info via RPC)")
    func fetchSubjectForDevice(deviceId: String) async {
        print("👤 [Legacy] Fetching subject for device: \(deviceId)")
        
        do {
            // まずdevicesテーブルからsubject_idを取得
            struct DeviceResponse: Codable {
                let device_id: String
                let subject_id: String?
            }
            
            let devices: [DeviceResponse] = try await supabase
                .from("devices")
                .select()
                .eq("device_id", value: deviceId)
                .execute()
                .value
            
            guard let device = devices.first, let subjectId = device.subject_id else {
                print("ℹ️ No subject assigned to this device")
                await MainActor.run { [weak self] in
                    self?.subject = nil
                }
                return
            }
            
            // subject_idを使ってsubjectsテーブルから情報を取得
            let subjects: [Subject] = try await supabase
                .from("subjects")
                .select()
                .eq("subject_id", value: subjectId)
                .execute()
                .value
            
            if let subject = subjects.first {
                print("✅ Subject found: \(subject.name)")
                await MainActor.run { [weak self] in
                    self?.subject = subject
                }
            } else {
                print("⚠️ Subject not found in database")
                await MainActor.run { [weak self] in
                    self?.subject = nil
                }
            }
            
        } catch {
            print("❌ Failed to fetch subject: \(error)")
            await MainActor.run { [weak self] in
                self?.subject = nil
                self?.errorMessage = "観測対象の取得エラー: \(error.localizedDescription)"
            }
        }
    }
    
    /// 新しい観測対象を登録
    func registerSubject(
        name: String,
        age: Int?,
        gender: String?,
        avatarUrl: String?,
        notes: String?,
        createdByUserId: String
    ) async throws -> String {
        print("👤 Registering new subject: \(name)")
        
        struct SubjectInsert: Codable {
            let name: String
            let age: Int?
            let gender: String?
            let avatar_url: String?
            let notes: String?
            let created_by_user_id: String
        }
        
        let subjectInsert = SubjectInsert(
            name: name,
            age: age,
            gender: gender,
            avatar_url: avatarUrl,
            notes: notes,
            created_by_user_id: createdByUserId
        )
        
        let subjects: [Subject] = try await supabase
            .from("subjects")
            .insert(subjectInsert)
            .select()
            .execute()
            .value
        
        guard let subject = subjects.first else {
            throw SupabaseDataError.noDataReturned
        }
        
        print("✅ Subject registered successfully: \(subject.subjectId)")
        return subject.subjectId
    }
    
    /// デバイスのsubject_idを更新
    func updateDeviceSubjectId(deviceId: String, subjectId: String) async throws {
        print("🔗 Updating device subject_id: \(deviceId) -> \(subjectId)")
        
        struct DeviceUpdate: Codable {
            let subject_id: String
        }
        
        let deviceUpdate = DeviceUpdate(subject_id: subjectId)
        
        try await supabase
            .from("devices")
            .update(deviceUpdate)
            .eq("device_id", value: deviceId)
            .execute()
        
        print("✅ Device subject_id updated successfully")
    }
    
    /// 観測対象を更新
    func updateSubject(
        subjectId: String,
        name: String,
        age: Int?,
        gender: String?,
        avatarUrl: String?,
        notes: String?
    ) async throws {
        print("👤 Updating subject: \(subjectId)")
        
        struct SubjectUpdate: Codable {
            let name: String
            let age: Int?
            let gender: String?
            let avatar_url: String?
            let notes: String?
            let updated_at: String
        }
        
        let now = ISO8601DateFormatter().string(from: Date())
        let subjectUpdate = SubjectUpdate(
            name: name,
            age: age,
            gender: gender,
            avatar_url: avatarUrl,
            notes: notes,
            updated_at: now
        )
        
        try await supabase
            .from("subjects")
            .update(subjectUpdate)
            .eq("subject_id", value: subjectId)
            .execute()
        
        print("✅ Subject updated successfully: \(subjectId)")
    }
}

// MARK: - Custom Error Types

enum SupabaseDataError: Error, LocalizedError {
    case noDataReturned
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .noDataReturned:
            return "データが返されませんでした"
        case .invalidData:
            return "無効なデータ形式です"
        }
    }
}