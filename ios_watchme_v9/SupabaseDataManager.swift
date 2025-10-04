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
    let behaviorReport: BehaviorReport?
    let emotionReport: EmotionReport?
    let subject: Subject?
    let dashboardSummary: DashboardSummary?  // メインデータソース（気分データ含む）
    let subjectComments: [SubjectComment]?  // コメント機能追加
}

// MARK: - RPC Response Structure
/// Supabase RPC関数 'get_dashboard_data' からの応答構造
/// ⚠️ 重要: この構造はSupabase側のRPC関数の出力と完全に一致する必要があります
/// RPC関数の変更時は、必ずこの構造体も更新してください
struct RPCDashboardResponse: Codable {
    let behavior_report: BehaviorReport?
    let emotion_report: EmotionReport?
    let subject_info: Subject?
    let dashboard_summary: DashboardSummary?  // メインの気分データソース
    let subject_comments: [SubjectComment]?  // コメント機能追加
    
    private enum CodingKeys: String, CodingKey {
        case behavior_report
        case emotion_report
        case subject_info
        case dashboard_summary
        case subject_comments
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
    
    // 認証マネージャーへの参照（オプショナル）
    private weak var userAccountManager: UserAccountManager?
    
    // 日付フォーマッター
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    // MARK: - Initialization
    init(userAccountManager: UserAccountManager? = nil) {
        self.userAccountManager = userAccountManager
        print("📊 SupabaseDataManager initialized")
    }
    
    // 認証マネージャーを設定（後から注入する場合）
    func setAuthManager(_ userAccountManager: UserAccountManager) {
        self.userAccountManager = userAccountManager
    }
    
    // MARK: - Public Methods
    
    /// 月間の気分スコアを取得（カレンダー表示用）
    func fetchMonthlyVibeScores(deviceId: String, month: Date, timezone: TimeZone? = nil) async -> [MonthlyVibeData] {
        let tz = timezone ?? TimeZone.current
        
        // 月の開始日と終了日を計算
        var calendar = Calendar.current
        calendar.timeZone = tz
        
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else {
            print("❌ 月の期間を計算できませんでした")
            return []
        }
        
        let startDate = monthInterval.start
        let endDate = calendar.date(byAdding: .day, value: -1, to: monthInterval.end) ?? monthInterval.end
        
        // 日付フォーマッター
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = tz
        
        let startDateString = formatter.string(from: startDate)
        let endDateString = formatter.string(from: endDate)
        
        print("📅 月間データ取得: \(startDateString) 〜 \(endDateString)")
        
        // Supabaseから月間データを取得（dashboard_summaryテーブルを使用）
        do {
            let dashboardReports: [DashboardSummary] = try await supabase
                .from("dashboard_summary")
                .select()
                .eq("device_id", value: deviceId)
                .gte("date", value: startDateString)
                .lte("date", value: endDateString)
                .execute()
                .value

            print("✅ \(dashboardReports.count)件の気分データを取得")

            // MonthlyVibeData形式に変換
            return dashboardReports.compactMap { report -> MonthlyVibeData? in
                guard let date = formatter.date(from: report.date) else { return nil }
                return MonthlyVibeData(date: date, averageScore: report.averageVibe.map { Double($0) })
            }
        } catch {
            print("❌ 月間データ取得エラー: \(error)")
            return []
        }
    }
    
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
    ///   - timezone: デバイス固有のタイムゾーン
    /// - Returns: DashboardData（すべてのレポートを含む）
    func fetchAllReports(deviceId: String, date: Date, timezone: TimeZone? = nil) async -> DashboardData {
        isLoading = true
        errorMessage = nil
        
        // 🎯 RPC関数を使用して全データを一括取得（タイムゾーンを渡す）
        let dashboardData = await fetchAllReportsData(deviceId: deviceId, date: date, timezone: timezone)
        
        // @Publishedプロパティも更新（互換性のため）
        // 注意: subjectは各Viewがローカルで管理するため、ここでは更新しない
        await MainActor.run {
            self.dailyReport = nil  // vibeReportは廃止
            self.dailyBehaviorReport = dashboardData.behaviorReport
            self.dailyEmotionReport = dashboardData.emotionReport
            // self.subject = dashboardData.subject  // ❌ 削除: 各Viewがローカルで管理
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
    ///   - timezone: デバイス固有のタイムゾーン（指定しない場合は現在のタイムゾーン）
    /// - Returns: DashboardData（すべてのレポートを含む）
    func fetchAllReportsData(deviceId: String, date: Date, timezone: TimeZone? = nil) async -> DashboardData {
        // デバイス固有のタイムゾーンを適用
        let targetTimezone = timezone ?? TimeZone.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = targetTimezone  // ⭐️ デバイス固有のタイムゾーンを使用
        
        let dateString = formatter.string(from: date)
        print("🚀 [RPC] Fetching all dashboard data via RPC function")
        print("   Device: \(deviceId)")
        print("   Date: \(dateString)")
        print("   Timezone: \(targetTimezone.identifier)")
        print("   Current Time in Device TZ: \(formatter.string(from: Date()))")
        
        do {
            // RPC関数のパラメータを準備
            let params = [
                "p_device_id": deviceId,
                "p_date": dateString
            ]
            
            print("📤 [RPC] Calling RPC with params: \(params)")
            print("   🕐 Local iPhone Time: \(Date())")
            print("   🌍 Target Device Timezone: \(targetTimezone.identifier)")
            print("   📅 Requesting data for date: \(dateString)")
            
            // 📡 Supabase RPC関数を呼び出し（1回のAPIコールですべてのデータを取得）
            let response: [RPCDashboardResponse] = try await supabase
                .rpc("get_dashboard_data", params: params)
                .execute()
                .value
            
            print("📥 [RPC] Response received, count: \(response.count)")
            
            // 最初の結果を取得（RPCは配列で返すが、通常1件のみ）
            guard let rpcData = response.first else {
                print("⚠️ [RPC] No data returned from RPC function")
                print("   Response was empty array")
                return DashboardData(
                    behaviorReport: nil,
                    emotionReport: nil,
                    subject: nil,
                    dashboardSummary: nil,
                    subjectComments: nil
                )
            }
            
            print("✅ [RPC] Successfully fetched all dashboard data")
            print("   - Behavior Report: \(rpcData.behavior_report != nil ? "✓" : "✗")")
            print("   - Emotion Report: \(rpcData.emotion_report != nil ? "✓" : "✗")")
            print("   - Subject Info: \(rpcData.subject_info != nil ? "✓" : "✗")")
            print("   - Dashboard Summary: \(rpcData.dashboard_summary != nil ? "✓" : "✗")")  
            print("   - Subject Comments: \(rpcData.subject_comments?.count ?? 0) comments")  
            if let dashboardSummary = rpcData.dashboard_summary {
                print("   - Average Vibe from Dashboard Summary: \(dashboardSummary.averageVibe ?? 0)")
            }
            
            // 感情データの簡潔なログ（デバッグ完了後は削除可能）
            if let emotionReport = rpcData.emotion_report {
                let activePoints = emotionReport.emotionGraph.filter { $0.totalEmotions > 0 }
                print("   📊 Emotion: \(activePoints.count) active points")
            }
            
            // RPCレスポンスをDashboardDataに変換
            return DashboardData(
                behaviorReport: rpcData.behavior_report,
                emotionReport: rpcData.emotion_report,
                subject: rpcData.subject_info,  // ✅ Subject情報も正しく取得
                dashboardSummary: rpcData.dashboard_summary,  // ✅ Dashboard Summary情報も取得（メインデータソース）
                subjectComments: rpcData.subject_comments  // ✅ コメント情報も取得
            )
            
        } catch {
            print("❌ [RPC] Failed to fetch dashboard data: \(error)")
            print("   Error type: \(type(of: error))")
            print("   Error details: \(error.localizedDescription)")
            
            // デコードエラーの詳細情報を出力
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .dataCorrupted(let context):
                    print("   🔍 Data corrupted at: \(context.codingPath)")
                    print("   Debug description: \(context.debugDescription)")
                case .keyNotFound(let key, let context):
                    print("   🔍 Key '\(key.stringValue)' not found at: \(context.codingPath)")
                    print("   Debug description: \(context.debugDescription)")
                case .typeMismatch(let type, let context):
                    print("   🔍 Type mismatch. Expected: \(type)")
                    print("   At path: \(context.codingPath)")
                    print("   Debug description: \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("   🔍 Value not found. Expected: \(type)")
                    print("   At path: \(context.codingPath)")
                    print("   Debug description: \(context.debugDescription)")
                @unknown default:
                    print("   🔍 Unknown decoding error")
                }
            }
            
            // 認証エラーの可能性をチェック
            let errorString = "\(error)"
            if errorString.lowercased().contains("auth") || 
               errorString.lowercased().contains("token") ||
               errorString.lowercased().contains("unauthorized") ||
               errorString.lowercased().contains("forbidden") ||
               errorString.lowercased().contains("jwt") {
                print("   🔐 ⚠️ This appears to be an authentication error!")
                print("   💡 Attempting automatic token refresh...")
                
                // 認証マネージャーが設定されている場合、自動リカバリーを試行
                if let userAccountManager = userAccountManager {
                    let recovered = await userAccountManager.handleAuthenticationError()
                    
                    if recovered {
                        print("   🔄 Token refreshed successfully, retrying RPC call...")
                        // トークンリフレッシュ成功後、元のリクエストを再試行（タイムゾーンも渡す）
                        return await fetchAllReportsData(deviceId: deviceId, date: date, timezone: timezone)
                    } else {
                        print("   ❌ Token refresh failed - user needs to re-login")
                    }
                } else {
                    print("   ⚠️ No auth manager available for automatic recovery")
                }
            }
            
            // エラー時は空のデータを返す
            return DashboardData(
                behaviorReport: nil,
                emotionReport: nil,
                subject: nil,
                dashboardSummary: nil,
                subjectComments: nil
            )
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
    
    /// デバイスIDのみでSubject情報を取得する専用メソッド（軽量版）
    /// HeaderViewなど、Subject情報のみが必要な場合に使用
    /// - Parameter deviceId: デバイスID
    /// - Returns: Subject情報（存在しない場合はnil）
    func fetchSubjectInfo(deviceId: String) async -> Subject? {
        print("👤 [RPC] Fetching subject info only for device: \(deviceId)")
        
        do {
            // RPC関数のパラメータを準備
            let params = ["p_device_id": deviceId]
            
            print("📤 [RPC] Calling get_subject_info with device_id: \(deviceId)")
            
            // 軽量なRPC関数を呼び出し（Subject情報のみ）
            struct SubjectResponse: Codable {
                let subject_info: Subject?
            }
            
            let response: [SubjectResponse] = try await supabase
                .rpc("get_subject_info", params: params)
                .execute()
                .value
            
            print("📥 [RPC] Subject info response received")
            
            // 最初の結果を取得
            guard let rpcData = response.first else {
                print("⚠️ [RPC] No subject info returned")
                return nil
            }
            
            if let subject = rpcData.subject_info {
                print("✅ [RPC] Subject found: \(subject.name ?? "Unknown")")
                return subject
            } else {
                print("ℹ️ [RPC] No subject assigned to this device")
                return nil
            }
            
        } catch {
            print("❌ [RPC] Failed to fetch subject info: \(error)")
            return nil
        }
    }
    
    /// デバイスIDのみでSubject情報を取得する専用メソッド（日付非依存）
    /// HeaderViewなど、Subject情報のみが必要な場合に使用
    /// - Parameter deviceId: デバイスID
    /// - Returns: Subject情報（存在しない場合はnil）
    /// @deprecated: Use fetchSubjectInfo instead (lightweight RPC version)
    @available(*, deprecated, message: "Use fetchSubjectInfo instead - it's much more efficient")
    func fetchSubjectOnly(deviceId: String) async -> Subject? {
        // 新しい軽量メソッドを呼び出す
        return await fetchSubjectInfo(deviceId: deviceId)
    }
    
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
                print("✅ Subject found: \(subject.name ?? "名前なし")")
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
    
    // MARK: - Dashboard Time Blocks Methods
    
    /// dashboardテーブルから指定日の時間ブロックごとの詳細データを取得
    /// - Parameters:
    ///   - deviceId: デバイスID
    ///   - date: 対象日付
    /// - Returns: 時間ブロックごとのデータ配列（時間順でソート済み）
    func fetchDashboardTimeBlocks(deviceId: String, date: Date) async -> [DashboardTimeBlock] {
        print("📊 Fetching dashboard time blocks for device: \(deviceId)")
        
        // 日付フォーマッタの設定
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        let dateString = formatter.string(from: date)
        
        print("   Date: \(dateString)")
        
        do {
            // dashboardテーブルから指定デバイス・日付のデータを取得
            let timeBlocks: [DashboardTimeBlock] = try await supabase
                .from("dashboard")
                .select()
                .eq("device_id", value: deviceId)
                .eq("date", value: dateString)
                .order("time_block", ascending: true)
                .execute()
                .value
            
            print("✅ Successfully fetched \(timeBlocks.count) time blocks")
            return timeBlocks
            
        } catch {
            print("❌ Failed to fetch dashboard time blocks: \(error)")
            print("   Error details: \(error.localizedDescription)")
            return []
        }
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
    
    // MARK: - Notification Methods
    
    /// 通知を取得（イベント通知、パーソナル通知、グローバル通知を統合）
    func fetchNotifications(userId: String) async -> [Notification] {
        print("🔔 Fetching notifications for user: \(userId)")
        
        var allNotifications: [Notification] = []
        
        do {
            // 1. イベント通知とパーソナル通知を取得（user_idが一致するもの）
            let personalNotifications: [Notification] = try await supabase
                .from("notifications")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            allNotifications.append(contentsOf: personalNotifications)
            print("✅ Found \(personalNotifications.count) personal/event notifications")
            
            // 2. グローバル通知を取得（すべての通知を取得してからフィルタリング）
            let allDbNotifications: [Notification] = try await supabase
                .from("notifications")
                .select()
                .eq("type", value: "global")
                .order("created_at", ascending: false)
                .execute()
                .value
            
            // user_idがnilのものだけをフィルタリング
            let globalNotifications = allDbNotifications.filter { $0.userId == nil }
            
            // 3. グローバル通知の既読状態を確認
            if !globalNotifications.isEmpty {
                // notification_readsテーブルから既読情報を取得
                struct NotificationReadStatus: Codable {
                    let notification_id: UUID
                    let read_at: Date?
                }
                
                // ユーザーの全既読レコードを取得
                let readStatuses: [NotificationReadStatus] = try await supabase
                    .from("notification_reads")
                    .select("notification_id, read_at")
                    .eq("user_id", value: userId)
                    .execute()
                    .value
                
                // 既読状態をマージ
                var updatedGlobalNotifications = globalNotifications
                for (index, notification) in updatedGlobalNotifications.enumerated() {
                    if readStatuses.contains(where: { $0.notification_id == notification.id }) {
                        updatedGlobalNotifications[index].isRead = true
                    }
                }
                
                allNotifications.append(contentsOf: updatedGlobalNotifications)
                print("✅ Found \(globalNotifications.count) global notifications")
            }
            
            // 作成日時でソート（新しい順）
            allNotifications.sort { $0.createdAt > $1.createdAt }
            
            print("✅ Total notifications: \(allNotifications.count)")
            return allNotifications
            
        } catch {
            print("❌ Failed to fetch notifications: \(error)")
            await MainActor.run { [weak self] in
                self?.errorMessage = "通知の取得エラー: \(error.localizedDescription)"
            }
            return []
        }
    }
    
    /// 通知を既読にする
    func markNotificationAsRead(notificationId: UUID, userId: String, isGlobal: Bool) async throws {
        print("✅ Marking notification as read: \(notificationId)")
        
        if isGlobal {
            // グローバル通知の場合は notification_reads テーブルに記録
            struct NotificationReadInsert: Codable {
                let user_id: String
                let notification_id: UUID
            }
            
            let readRecord = NotificationReadInsert(
                user_id: userId,
                notification_id: notificationId
            )
            
            // 既存のレコードがある場合は無視（ON CONFLICT DO NOTHING相当）
            do {
                try await supabase
                    .from("notification_reads")
                    .upsert(readRecord, onConflict: "user_id,notification_id")
                    .execute()
                print("✅ Global notification marked as read")
            } catch {
                // 既に既読の場合はエラーを無視
                print("⚠️ Notification might already be marked as read: \(error)")
            }
        } else {
            // パーソナル/イベント通知の場合は notifications テーブルの is_read を更新
            struct NotificationUpdate: Codable {
                let is_read: Bool
            }
            
            let update = NotificationUpdate(is_read: true)
            
            try await supabase
                .from("notifications")
                .update(update)
                .eq("id", value: notificationId.uuidString)
                .execute()
            
            print("✅ Personal/Event notification marked as read")
        }
    }
    
    /// すべての通知を既読にする
    func markAllNotificationsAsRead(userId: String) async throws {
        print("✅ Marking all notifications as read for user: \(userId)")
        
        // 1. パーソナル/イベント通知を既読にする
        struct NotificationUpdate: Codable {
            let is_read: Bool
        }
        
        let update = NotificationUpdate(is_read: true)
        
        try await supabase
            .from("notifications")
            .update(update)
            .eq("user_id", value: userId)
            .eq("is_read", value: false)
            .execute()
        
        // 2. グローバル通知の未読分を既読にする
        // まず未読のグローバル通知を取得（すべて取得してからフィルタリング）
        let allGlobalNotifications: [Notification] = try await supabase
            .from("notifications")
            .select()
            .eq("type", value: "global")
            .execute()
            .value
        
        // user_idがnilのものだけをフィルタリング
        let unreadGlobalNotifications = allGlobalNotifications.filter { $0.userId == nil }
        
        // notification_readsに一括挿入
        if !unreadGlobalNotifications.isEmpty {
            struct NotificationReadInsert: Codable {
                let user_id: String
                let notification_id: UUID
            }
            
            let readRecords = unreadGlobalNotifications.map { notification in
                NotificationReadInsert(user_id: userId, notification_id: notification.id)
            }
            
            // 既存のレコードは無視して挿入
            for record in readRecords {
                do {
                    try await supabase
                        .from("notification_reads")
                        .upsert(record, onConflict: "user_id,notification_id")
                        .execute()
                } catch {
                    // 既に既読の場合は続行
                    continue
                }
            }
        }
        
        print("✅ All notifications marked as read")
    }
    
    /// 未読通知数を取得
    func fetchUnreadNotificationCount(userId: String) async -> Int {
        do {
            // パーソナル/イベント通知の未読数（user_id = userId AND is_read = false）
            // type='personal'とtype='event'の両方を含める
            let personalEventUnreadCount: Int = try await supabase
                .from("notifications")
                .select("id", head: false, count: .exact)
                .eq("user_id", value: userId)
                .eq("is_read", value: false)
                .execute()
                .count ?? 0
            
            print("🔔 Personal/Event unread count: \(personalEventUnreadCount)")
            
            // グローバル通知の総数を取得（user_id IS NULL AND type = 'global'）
            let totalGlobalCount: Int = try await supabase
                .from("notifications")
                .select("id", head: false, count: .exact)
                .is("user_id", value: nil)
                .eq("type", value: "global")
                .execute()
                .count ?? 0
            
            print("🔔 Total global notifications: \(totalGlobalCount)")
            
            // このユーザーが既読したグローバル通知の数
            let readGlobalCount: Int = try await supabase
                .from("notification_reads")
                .select("notification_id", head: false, count: .exact)
                .eq("user_id", value: userId)
                .execute()
                .count ?? 0
            
            print("🔔 Read global count: \(readGlobalCount)")
            
            // グローバル通知の未読数 = 総グローバル通知数 - 既読数
            let globalUnreadCount = max(0, totalGlobalCount - readGlobalCount)
            print("🔔 Global unread count: \(globalUnreadCount)")
            
            let totalUnreadCount = personalEventUnreadCount + globalUnreadCount
            print("🔔 Total unread count: \(totalUnreadCount)")
            
            return totalUnreadCount
            
        } catch {
            print("❌ Failed to fetch unread count: \(error)")
            return 0
        }
    }
    
    // MARK: - Comment Methods
    
    /// コメントを追加
    func addComment(subjectId: String, userId: String, commentText: String, date: Date) async throws {
        print("💬 Adding comment for subject: \(subjectId) on date: \(date)")
        
        // 日付をYYYY-MM-DD形式に変換
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        let comment = [
            "subject_id": subjectId,
            "user_id": userId,
            "comment_text": commentText,
            "date": dateString  // 日付を追加
        ]
        
        try await supabase
            .from("subject_comments")
            .insert(comment)
            .execute()
        
        print("✅ Comment added successfully for date: \(dateString)")
    }
    
    /// コメントを削除
    func deleteComment(commentId: String) async throws {
        print("🗑️ Deleting comment: \(commentId)")
        
        try await supabase
            .from("subject_comments")
            .delete()
            .eq("comment_id", value: commentId)
            .execute()
        
        print("✅ Comment deleted successfully")
    }
    
    /// コメントを再取得（リフレッシュ用）
    func fetchComments(subjectId: String, date: Date) async -> [SubjectComment] {
        print("💬 Fetching comments for subject: \(subjectId) on date: \(date)")
        
        // 日付をYYYY-MM-DD形式に変換
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        do {
            // まずコメントを取得
            let comments: [SubjectComment] = try await supabase
                .from("subject_comments")
                .select("*")
                .eq("subject_id", value: subjectId)
                .eq("date", value: dateString)  // 日付でフィルタリング
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
                .value
            
            // ユーザーIDのリストを作成
            let userIds = Array(Set(comments.map { $0.userId }))
            
            if !userIds.isEmpty {
                // ユーザー情報を一括取得
                struct UserInfo: Codable {
                    let user_id: String
                    let name: String?
                    let avatar_url: String?
                }
                
                let users: [UserInfo] = try await supabase
                    .from("users")
                    .select("user_id, name, avatar_url")
                    .in("user_id", values: userIds)
                    .execute()
                    .value
                
                // ユーザー情報を辞書化
                let userDict = Dictionary(uniqueKeysWithValues: users.map { ($0.user_id, $0) })
                
                // コメントにユーザー情報を結合
                let enrichedComments = comments.map { comment in
                    let userInfo = userDict[comment.userId]
                    return SubjectComment(
                        id: comment.id,
                        subjectId: comment.subjectId,
                        userId: comment.userId,
                        commentText: comment.commentText,
                        createdAt: comment.createdAt,
                        date: comment.date,
                        userName: userInfo?.name,
                        userAvatarUrl: userInfo?.avatar_url
                    )
                }
                
                print("✅ Fetched \(enrichedComments.count) comments with user info for date: \(dateString)")
                return enrichedComments
            }
            
            print("✅ Fetched \(comments.count) comments for date: \(dateString)")
            return comments
        } catch {
            print("❌ Failed to fetch comments: \(error)")
            return []
        }
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