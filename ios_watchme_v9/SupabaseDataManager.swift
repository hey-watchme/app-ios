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

// MARK: - Supabaseデータ管理クラス
// vibe_whisper_summaryテーブルからデータを取得・管理する責務を持つ
@MainActor
class SupabaseDataManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var dailyReport: DashboardSummary?
    // dailyBehaviorReport, dailyEmotionReportは削除（各Viewがローカルで管理）
    @Published var weeklyReports: [DashboardSummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var subject: Subject?

    // MARK: - Private Properties
    private let supabaseURL = "https://qvtlwotzuzbavrzqhyvt.supabase.co"
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2dGx3b3R6dXpiYXZyenFoeXZ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTEzODAzMzAsImV4cCI6MjA2Njk1NjMzMH0.g5rqrbxHPw1dKlaGqJ8miIl9gCXyamPajinGCauEI3k"

    // 認証マネージャーへの参照（オプショナル）
    private weak var userAccountManager: UserAccountManager?
    // デバイスマネージャーへの参照（パフォーマンス最適化用）
    private weak var deviceManager: DeviceManager?
    
    // 日付フォーマッター
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    // MARK: - Initialization
    init(userAccountManager: UserAccountManager? = nil) {
        let startTime = Date()
        print("⏱️ [SDM-INIT] SupabaseDataManager初期化開始")

        self.userAccountManager = userAccountManager
        print("⏱️ [SDM-INIT] userAccountManager設定完了: \(Date().timeIntervalSince(startTime))秒")

        print("⏱️ [SDM-INIT] SupabaseDataManager初期化完了: \(Date().timeIntervalSince(startTime))秒")
    }
    
    // 認証マネージャーを設定（後から注入する場合）
    func setAuthManager(_ userAccountManager: UserAccountManager) {
        self.userAccountManager = userAccountManager
    }

    // デバイスマネージャーを設定（パフォーマンス最適化用）
    func setDeviceManager(_ deviceManager: DeviceManager) {
        self.deviceManager = deviceManager
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
        
        // Supabaseから月間データを取得（daily_resultsテーブルを使用）
        do {
            let dashboardReports: [DashboardSummary] = try await supabase
                .from("daily_results")
                .select()
                .eq("device_id", value: deviceId)
                .gte("local_date", value: startDateString)
                .lte("local_date", value: endDateString)
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

        // URLの構築（daily_resultsテーブルを使用）
        guard let url = URL(string: "\(supabaseURL)/rest/v1/daily_results") else {
            errorMessage = "無効なURL"
            isLoading = false
            return
        }

        // クエリパラメータの構築（local_dateカラムを使用）
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "device_id", value: "eq.\(deviceId)"),
            URLQueryItem(name: "local_date", value: "eq.\(dateString)"),
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
                
                // レスポンスをデコード（DashboardSummaryモデルを使用）
                let decoder = JSONDecoder()

                do {
                    let reports = try decoder.decode([DashboardSummary].self, from: data)
                    print("📊 Decoded reports count: \(reports.count)")

                    if let report = reports.first {
                        self.dailyReport = report
                        print("✅ Daily report fetched successfully")
                        print("   Average score: \(report.averageVibe ?? 0)")
                        print("   Insights: \(report.insights ?? "No insights")")
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

        // URLの構築（daily_resultsテーブルを使用）
        guard let url = URL(string: "\(supabaseURL)/rest/v1/daily_results") else {
            errorMessage = "無効なURL"
            isLoading = false
            return
        }

        // クエリパラメータの構築（local_dateカラムを使用）
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "device_id", value: "eq.\(deviceId)"),
            URLQueryItem(name: "local_date", value: "gte.\(startDateString)"),
            URLQueryItem(name: "local_date", value: "lte.\(endDateString)"),
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "order", value: "local_date.asc")
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
                // レスポンスをデコード（DashboardSummaryモデルを使用）
                let decoder = JSONDecoder()

                let reports = try decoder.decode([DashboardSummary].self, from: data)
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
        // dailyBehaviorReport, dailyEmotionReportは削除（各Viewがローカルで管理）
        weeklyReports = []
        errorMessage = nil
    }
    
    /// 統合データフェッチメソッド - すべてのグラフデータを一括で取得
    /// DashboardDataを返し、互換性のため@Publishedプロパティも更新
    /// すべてのレポートを取得するメインメソッド
    ///
    /// 🔄 Phase 1: daily_resultsテーブルへの直接アクセス（RPC解除）
    /// 気分データのみ取得、行動・感情は将来実装
    ///
    /// - Parameters:
    ///   - deviceId: デバイスID
    ///   - date: 取得したい日付
    ///   - timezone: デバイス固有のタイムゾーン
    /// - Returns: DashboardData（気分データのみ含む）
    func fetchAllReports(deviceId: String, date: Date, timezone: TimeZone? = nil) async -> DashboardData {
        isLoading = true
        errorMessage = nil

        // 🎯 Phase 1: daily_resultsテーブルに直接アクセス
        let dashboardSummary = await fetchDailyResults(deviceId: deviceId, date: date, timezone: timezone)

        // 🚀 最適化: DeviceManagerからSubject情報を取得（RPC呼び出し削減）
        var subject: Subject? = nil
        if let deviceManager = deviceManager {
            // まず selectedSubject をチェック（selectedDeviceID と一致する場合）
            if deviceManager.selectedDeviceID == deviceId,
               let selectedSubject = deviceManager.selectedSubject {
                subject = selectedSubject
                #if DEBUG
                print("✅ [fetchAllReports] Subject loaded from selectedSubject: \(selectedSubject.name ?? "Unknown")")
                #endif
            } else if let device = deviceManager.devices.first(where: { $0.device_id == deviceId }),
                      let cachedSubject = device.subject {
                // フォールバック: devices配列から取得
                subject = cachedSubject
                #if DEBUG
                print("✅ [fetchAllReports] Subject loaded from device cache: \(cachedSubject.name ?? "Unknown")")
                #endif
            }
            // ✅ リファクタリング: fetchSubjectInfo()は削除されたため、
            // DeviceManager.devices[].subjectのみを使用
        }

        // コメントを取得
        let comments = await fetchComments(subjectId: subject?.subjectId ?? "", date: date)

        // @Publishedプロパティも更新（互換性のため）
        await MainActor.run {
            self.dailyReport = dashboardSummary
            self.isLoading = false
        }

        print("✅ [Direct Access] Dashboard data fetching completed (vibe only)")

        // Phase 1: 気分のみ対応、行動・感情はnil
        return DashboardData(
            behaviorReport: nil,  // Phase 2で実装予定
            emotionReport: nil,   // Phase 2で実装予定
            subject: subject,
            dashboardSummary: dashboardSummary,
            subjectComments: comments.isEmpty ? nil : comments
        )
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

    /// 新しい観測対象を登録
    func registerSubject(
        name: String,
        age: Int?,
        gender: String?,
        cognitiveType: String?,
        prefecture: String?,
        city: String?,
        avatarUrl: String?,
        notes: String?,
        createdByUserId: String
    ) async throws -> String {
        print("👤 Registering new subject: \(name)")

        struct SubjectInsert: Codable {
            let name: String
            let age: Int?
            let gender: String?
            let cognitive_type: String?
            let prefecture: String?
            let city: String?
            let avatar_url: String?
            let notes: String?
            let created_by_user_id: String
        }

        let subjectInsert = SubjectInsert(
            name: name,
            age: age,
            gender: gender,
            cognitive_type: cognitiveType,
            prefecture: prefecture,
            city: city,
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
    
    // MARK: - Daily Results Methods

    /// daily_resultsテーブルから指定日のサマリーデータを取得（直接アクセス）
    /// - Parameters:
    ///   - deviceId: デバイスID
    ///   - date: 対象日付
    ///   - timezone: デバイス固有のタイムゾーン
    /// - Returns: 1日のサマリーデータ（DashboardSummary）
    func fetchDailyResults(deviceId: String, date: Date, timezone: TimeZone? = nil) async -> DashboardSummary? {
        // タイムゾーンを適用
        let targetTimezone = timezone ?? TimeZone.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = targetTimezone
        let dateString = formatter.string(from: date)

        #if DEBUG
        print("📊 [Direct Access] Fetching daily_results")
        print("   Device: \(deviceId)")
        print("   Date: \(dateString)")
        print("   Timezone: \(targetTimezone.identifier)")
        #endif

        do {
            // daily_resultsテーブルから直接取得
            let results: [DashboardSummary] = try await supabase
                .from("daily_results")
                .select()
                .eq("device_id", value: deviceId)
                .eq("local_date", value: dateString)
                .execute()
                .value

            if let summary = results.first {
                #if DEBUG
                print("✅ [Direct Access] Daily results found")
                print("   Average Vibe: \(summary.averageVibe ?? 0)")
                print("   Insights: \(summary.insights != nil ? "✓" : "✗")")
                print("   Vibe Scores: \(summary.vibeScores?.count ?? 0) points")
                #endif
                return summary
            } else {
                #if DEBUG
                print("ℹ️ [Direct Access] No daily results found for \(dateString)")
                #endif
                return nil
            }

        } catch {
            print("❌ [Direct Access] Failed to fetch daily_results: \(error)")
            print("   Error details: \(error.localizedDescription)")

            // デコードエラーの詳細
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("   Key not found: \(key.stringValue) at \(context.codingPath)")
                case .typeMismatch(let type, let context):
                    print("   Type mismatch: expected \(type) at \(context.codingPath)")
                case .valueNotFound(let type, let context):
                    print("   Value not found: \(type) at \(context.codingPath)")
                case .dataCorrupted(let context):
                    print("   Data corrupted at \(context.codingPath)")
                @unknown default:
                    print("   Unknown decoding error")
                }
            }

            return nil
        }
    }

    /// Fetch daily_results for a date range (multiple days)
    /// - Parameters:
    ///   - deviceId: Device ID
    ///   - startDate: Start date of the period
    ///   - endDate: End date of the period
    ///   - timezone: Device-specific timezone
    /// - Returns: Array of DashboardSummary sorted by date (oldest first)
    func fetchDailyResultsRange(deviceId: String, startDate: Date, endDate: Date, timezone: TimeZone? = nil) async -> [DashboardSummary] {
        let targetTimezone = timezone ?? TimeZone.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = targetTimezone

        let startDateString = formatter.string(from: startDate)
        let endDateString = formatter.string(from: endDate)

        #if DEBUG
        print("📊 [Range Query] Fetching daily_results")
        print("   Device: \(deviceId)")
        print("   Period: \(startDateString) 〜 \(endDateString)")
        #endif

        do {
            let results: [DashboardSummary] = try await supabase
                .from("daily_results")
                .select()
                .eq("device_id", value: deviceId)
                .gte("local_date", value: startDateString)
                .lte("local_date", value: endDateString)
                .order("local_date", ascending: true)
                .execute()
                .value

            #if DEBUG
            print("✅ [Range Query] Fetched \(results.count) daily results")
            #endif
            return results

        } catch {
            print("❌ [Range Query] Failed to fetch daily_results: \(error)")
            return []
        }
    }

    // MARK: - Spot Results Methods

    /// Fetch single spot result with details
    /// - Parameters:
    ///   - deviceId: Device ID
    ///   - recordedAt: recorded_at timestamp (ISO8601)
    /// - Returns: SpotResult with full details or nil if not found
    func fetchSpotDetail(deviceId: String, recordedAt: String) async -> SpotResult? {
        #if DEBUG
        print("📊 [Spot Detail] Fetching spot_results")
        print("   Device: \(deviceId)")
        print("   Recorded At: \(recordedAt)")
        #endif

        do {
            let results: [SpotResult] = try await supabase
                .from("spot_results")
                .select()
                .eq("device_id", value: deviceId)
                .eq("recorded_at", value: recordedAt)
                .limit(1)
                .execute()
                .value

            #if DEBUG
            if let result = results.first {
                print("✅ [Spot Detail] Found spot result")
            } else {
                print("⚠️ [Spot Detail] No spot result found")
            }
            #endif

            return results.first
        } catch {
            print("❌ [Spot Detail] Failed to fetch spot_results: \(error)")
            return nil
        }
    }

    /// Fetch all spot results for a specific day
    /// - Parameters:
    ///   - deviceId: Device ID
    ///   - localDate: Local date string (yyyy-MM-dd)
    /// - Returns: Array of SpotResult sorted by local_time
    func fetchSpotsForDay(deviceId: String, localDate: String) async -> [SpotResult] {
        #if DEBUG
        print("📊 [Spots for Day] Fetching spot_results")
        print("   Device: \(deviceId)")
        print("   Local Date: \(localDate)")
        #endif

        do {
            let results: [SpotResult] = try await supabase
                .from("spot_results")
                .select()
                .eq("device_id", value: deviceId)
                .eq("local_date", value: localDate)
                .order("local_time", ascending: true)
                .execute()
                .value

            #if DEBUG
            print("✅ [Spots for Day] Fetched \(results.count) spot results")
            #endif

            return results
        } catch {
            print("❌ [Spots for Day] Failed to fetch spot_results: \(error)")
            return []
        }
    }

    // MARK: - Dashboard Time Blocks Methods

    /// spot_resultsテーブルから指定日の詳細データを取得
    /// - Parameters:
    ///   - deviceId: デバイスID
    ///   - date: 対象日付
    /// - Returns: 録音ごとのデータ配列（時間順でソート済み）
    ///
    /// ⚠️ 重要: local_dateのみ使用。recorded_at（UTC）は一切参照しない
    func fetchDashboardTimeBlocks(deviceId: String, date: Date, timezone: TimeZone? = nil) async -> [DashboardTimeBlock] {
        #if DEBUG
        print("📊 Fetching spot results with features for device: \(deviceId)")
        #endif

        // タイムゾーンを適用してlocal_dateを生成
        let targetTimezone = timezone ?? TimeZone.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = targetTimezone
        let dateString = formatter.string(from: date)

        #if DEBUG
        print("   Date: \(dateString)")
        print("   Timezone: \(targetTimezone.identifier)")
        #endif

        do {
            // Step 1 & 2: Fetch spot_results and spot_features in parallel
            struct SpotResult: Codable {
                let device_id: String
                let local_date: String?
                let local_time: String?  // ✅ local_timeで結合（ユニークキー）
                let summary: String?
                let behavior: String?
                let vibe_score: Double?
                let created_at: String?
            }

            struct SpotFeature: Codable {
                let device_id: String
                let local_time: String?  // ✅ local_timeで結合
                let behavior_extractor_result: [SEDBehaviorTimePoint]?
                let emotion_extractor_result: [EmotionChunk]?
            }

            // 📊 Performance optimization: Parallel database queries
            let spotResultsQuery = supabase
                .from("spot_results")
                .select("device_id, local_date, local_time, summary, behavior, vibe_score, created_at")
                .eq("device_id", value: deviceId)
                .eq("local_date", value: dateString)
                .order("local_time", ascending: true)  // ✅ ローカルタイムでソート

            let spotFeaturesQuery = supabase
                .from("spot_features")
                .select("device_id, local_time, behavior_extractor_result, emotion_extractor_result")
                .eq("device_id", value: deviceId)
                .eq("local_date", value: dateString)

            async let spotResultsTask: [SpotResult] = spotResultsQuery.execute().value
            async let spotFeaturesTask: [SpotFeature] = spotFeaturesQuery.execute().value

            let (spotResults, spotFeatures) = try await (spotResultsTask, spotFeaturesTask)

            print("✅ Fetched \(spotResults.count) spot results and \(spotFeatures.count) spot features")

            // Step 3: Merge data by local_time (ユニークキー)
            let featureMap = Dictionary(uniqueKeysWithValues: spotFeatures.compactMap { feature -> (String, SpotFeature)? in
                guard let localTime = feature.local_time else { return nil }
                return (localTime, feature)
            })

            // Optimized: Direct object construction without JSON encoding/decoding
            let timeBlocks: [DashboardTimeBlock] = spotResults.compactMap { result in
                guard let localTime = result.local_time else { return nil }
                let feature = featureMap[localTime]

                // Direct initialization (避免 JSON overhead)
                return DashboardTimeBlock(
                    deviceId: result.device_id,
                    localDate: result.local_date,
                    localTime: result.local_time,
                    summary: result.summary,
                    behavior: result.behavior,
                    vibeScore: result.vibe_score,
                    createdAt: result.created_at,
                    updatedAt: nil,
                    behaviorTimePoints: feature?.behavior_extractor_result ?? [],
                    emotionChunks: feature?.emotion_extractor_result ?? []
                )
            }

            #if DEBUG
            print("✅ Successfully merged \(timeBlocks.count) time blocks")

            // Log each time block for debugging
            for block in timeBlocks {
                let behaviorCount = block.behaviorTimePoints.count
                let emotionCount = block.emotionChunks.count
                print("   - \(block.displayTime): score=\(block.vibeScore ?? 0), behaviors=\(behaviorCount), emotions=\(emotionCount)")
            }
            #endif

            return timeBlocks

        } catch {
            print("❌ Failed to fetch spot data: \(error)")
            print("   Error details: \(error.localizedDescription)")

            // Decoding error details
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("   Key not found: \(key.stringValue) at \(context.codingPath)")
                case .typeMismatch(let type, let context):
                    print("   Type mismatch: expected \(type) at \(context.codingPath)")
                case .valueNotFound(let type, let context):
                    print("   Value not found: \(type) at \(context.codingPath)")
                case .dataCorrupted(let context):
                    print("   Data corrupted at \(context.codingPath)")
                @unknown default:
                    print("   Unknown decoding error")
                }
            }

            return []
        }
    }
    
    /// 観測対象を削除
    func deleteSubject(subjectId: String, deviceId: String) async throws {
        print("🗑️ Deleting subject: \(subjectId) from device: \(deviceId)")

        // Step 1: devicesテーブルからsubject_idをクリア
        struct DeviceUpdate: Codable {
            let subject_id: String?
        }

        let deviceUpdate = DeviceUpdate(subject_id: nil)

        try await supabase
            .from("devices")
            .update(deviceUpdate)
            .eq("device_id", value: deviceId)
            .execute()

        print("✅ Device subject_id cleared")

        // Step 2: subjectsテーブルからレコードを削除
        try await supabase
            .from("subjects")
            .delete()
            .eq("subject_id", value: subjectId)
            .execute()

        print("✅ Subject deleted successfully: \(subjectId)")
    }

    /// 観測対象を更新
    func updateSubject(
        subjectId: String,
        deviceId: String,
        name: String,
        age: Int?,
        gender: String?,
        cognitiveType: String?,
        prefecture: String?,
        city: String?,
        avatarUrl: String?,
        notes: String?
    ) async throws {
        print("👤 Updating subject: \(subjectId) for device: \(deviceId)")
        print("📝 Update data: name=\(name), age=\(age?.description ?? "nil"), gender=\(gender ?? "nil"), cognitiveType=\(cognitiveType ?? "nil"), prefecture=\(prefecture ?? "nil"), city=\(city ?? "nil"), avatarUrl=\(avatarUrl ?? "nil"), notes=\(notes ?? "nil")")

        // Custom Encodable struct that includes nil values in JSON
        struct SubjectUpdate: Encodable {
            let name: String
            let age: Int?
            let gender: String?
            let cognitive_type: String?
            let prefecture: String?
            let city: String?
            let avatar_url: String?
            let notes: String?
            let updated_at: String

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(name, forKey: .name)
                try container.encode(age, forKey: .age)
                try container.encode(gender, forKey: .gender)
                try container.encode(cognitive_type, forKey: .cognitive_type)
                try container.encode(prefecture, forKey: .prefecture)
                try container.encode(city, forKey: .city)
                try container.encode(avatar_url, forKey: .avatar_url)
                try container.encode(notes, forKey: .notes)
                try container.encode(updated_at, forKey: .updated_at)
            }

            enum CodingKeys: String, CodingKey {
                case name
                case age
                case gender
                case cognitive_type
                case prefecture
                case city
                case avatar_url
                case notes
                case updated_at
            }
        }

        let now = ISO8601DateFormatter().string(from: Date())
        let subjectUpdate = SubjectUpdate(
            name: name,
            age: age,
            gender: gender,
            cognitive_type: cognitiveType,
            prefecture: prefecture,
            city: city,
            avatar_url: avatarUrl,
            notes: notes,
            updated_at: now
        )

        // Log the encoded JSON to see what's being sent
        if let jsonData = try? JSONEncoder().encode(subjectUpdate),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("📤 Sending JSON: \(jsonString)")
        }

        let response = try await supabase
            .from("subjects")
            .update(subjectUpdate)
            .eq("subject_id", value: subjectId)
            .execute()

        print("✅ Subject updated successfully: \(subjectId)")
        print("📊 Update response status: \(response.status)")
        print("📊 Update response data: \(String(describing: response.data))")
    }
    
    // MARK: - Notification Methods
    
    /// 通知を取得（イベント通知、パーソナル通知、グローバル通知を統合）
    func fetchNotifications(userId: String) async -> [Notification] {
        print("🔔 Fetching notifications for user: \(userId)")
        
        var allNotifications: [Notification] = []
        
        do {
            // 📊 パフォーマンス最適化: 通知取得に件数制限を追加
            // 1. イベント通知とパーソナル通知を取得（user_idが一致するもの）
            let personalNotifications: [Notification] = try await supabase
                .from("notifications")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .limit(50)  // 最大50件に制限
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
                .limit(50)  // 最大50件に制限
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
    }
    
    /// コメントを削除
    func deleteComment(commentId: String) async throws {
        try await supabase
            .from("subject_comments")
            .delete()
            .eq("comment_id", value: commentId)
            .execute()
    }
    
    /// コメントを再取得（リフレッシュ用）
    func fetchComments(subjectId: String, date: Date) async -> [SubjectComment] {
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

                return enrichedComments
            }

            return comments
        } catch {
            print("❌ Failed to fetch comments: \(error)")
            return []
        }
    }

    // MARK: - Feedback / Report

    /// フィードバック・通報を送信
    static func submitFeedback(request: FeedbackRequest) async throws {
        do {
            try await supabase
                .from("messages")
                .insert(request)
                .execute()
        } catch {
            print("❌ Failed to submit feedback: \(error)")
            throw error
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

// MARK: - SupabaseDataManager Extension for Weekly Results

extension SupabaseDataManager {
    // MARK: - Weekly Results

    /// Fetch weekly results for current week (Monday-Sunday)
    func fetchWeeklyResults(deviceId: String, weekStartDate: Date, timezone: TimeZone? = nil) async -> WeeklyResults? {
        let tz = timezone ?? TimeZone.current

        // Format week_start_date (YYYY-MM-DD, Monday)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = tz
        let weekStartString = formatter.string(from: weekStartDate)

        #if DEBUG
        print("📅 [fetchWeeklyResults] Fetching weekly results for \(weekStartString)")
        #endif

        // Fetch from weekly_results table
        let urlString = "\(self.supabaseURL)/rest/v1/weekly_results?device_id=eq.\(deviceId)&week_start_date=eq.\(weekStartString)&select=*"

        guard let url = URL(string: urlString) else {
            #if DEBUG
            print("❌ [fetchWeeklyResults] Invalid URL")
            #endif
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(self.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(self.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                #if DEBUG
                print("❌ [fetchWeeklyResults] Invalid HTTP response")
                #endif
                return nil
            }

            guard httpResponse.statusCode == 200 else {
                print("❌ [fetchWeeklyResults] HTTP error: \(httpResponse.statusCode)")
                if let errorString = String(data: data, encoding: .utf8) {
                    print("❌ Error response: \(errorString)")
                }
                return nil
            }

            let decoder = JSONDecoder()
            // No need for date decoding strategy since created_at is String
            let results = try decoder.decode([WeeklyResults].self, from: data)

            if let weeklyResult = results.first {
                print("✅ [fetchWeeklyResults] Fetched weekly result: \(weeklyResult.memorableEvents?.count ?? 0) events")
                return weeklyResult
            } else {
                print("⚠️ [fetchWeeklyResults] No weekly results found for \(weekStartString)")
                return nil
            }

        } catch {
            print("❌ [fetchWeeklyResults] Error: \(error.localizedDescription)")
            if let decodingError = error as? DecodingError {
                print("❌ Decoding error details: \(decodingError)")
            }
            return nil
        }
    }

    /// Calculate average vibe score from daily_results for current week
    func fetchWeeklyAverageVibeScore(deviceId: String, weekStartDate: Date, timezone: TimeZone? = nil) async -> Double? {
        let tz = timezone ?? TimeZone.current
        var calendar = Calendar.current
        calendar.timeZone = tz

        // Calculate week end date (Sunday)
        guard let weekEndDate = calendar.date(byAdding: .day, value: 6, to: weekStartDate) else {
            print("❌ [fetchWeeklyAverageVibeScore] Failed to calculate week end date")
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = tz

        let startString = formatter.string(from: weekStartDate)
        let endString = formatter.string(from: weekEndDate)

        print("📅 [fetchWeeklyAverageVibeScore] Fetching daily results from \(startString) to \(endString)")

        // Fetch daily_results for the week
        let urlString = "\(self.supabaseURL)/rest/v1/daily_results?device_id=eq.\(deviceId)&local_date=gte.\(startString)&local_date=lte.\(endString)&select=vibe_score"

        guard let url = URL(string: urlString) else {
            print("❌ [fetchWeeklyAverageVibeScore] Invalid URL")
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(self.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(self.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)

            struct DailyVibeScore: Codable {
                let vibeScore: Double?
                enum CodingKeys: String, CodingKey {
                    case vibeScore = "vibe_score"
                }
            }

            let decoder = JSONDecoder()
            let results = try decoder.decode([DailyVibeScore].self, from: data)

            let scores = results.compactMap { $0.vibeScore }
            guard !scores.isEmpty else {
                print("⚠️ [fetchWeeklyAverageVibeScore] No vibe scores found")
                return nil
            }

            let average = scores.reduce(0, +) / Double(scores.count)
            print("✅ [fetchWeeklyAverageVibeScore] Average: \(average) (\(scores.count) days)")
            return average

        } catch {
            print("❌ [fetchWeeklyAverageVibeScore] Error: \(error.localizedDescription)")
            return nil
        }
    }

    /// Fetch daily vibe scores for a week (7 days: Monday to Sunday)
    func fetchWeeklyDailyVibeScores(deviceId: String, weekStartDate: Date, timezone: TimeZone? = nil) async -> [DailyVibeScore] {
        let tz = timezone ?? TimeZone.current
        var calendar = Calendar.current
        calendar.timeZone = tz

        // Calculate week end date (Sunday)
        guard let weekEndDate = calendar.date(byAdding: .day, value: 6, to: weekStartDate) else {
            print("❌ [fetchWeeklyDailyVibeScores] Failed to calculate week end date")
            return []
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = tz

        let startString = formatter.string(from: weekStartDate)
        let endString = formatter.string(from: weekEndDate)

        print("📅 [fetchWeeklyDailyVibeScores] Fetching daily vibe scores from \(startString) to \(endString)")

        // Fetch daily_results for the week
        let urlString = "\(self.supabaseURL)/rest/v1/daily_results?device_id=eq.\(deviceId)&local_date=gte.\(startString)&local_date=lte.\(endString)&select=local_date,vibe_score&order=local_date.asc"

        guard let url = URL(string: urlString) else {
            print("❌ [fetchWeeklyDailyVibeScores] Invalid URL")
            return []
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(self.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(self.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [fetchWeeklyDailyVibeScores] Invalid HTTP response")
                return []
            }

            guard httpResponse.statusCode == 200 else {
                print("❌ [fetchWeeklyDailyVibeScores] HTTP error: \(httpResponse.statusCode)")
                if let errorString = String(data: data, encoding: .utf8) {
                    print("❌ Error response: \(errorString)")
                }
                return []
            }

            let decoder = JSONDecoder()
            let results = try decoder.decode([DailyVibeScore].self, from: data)

            print("✅ [fetchWeeklyDailyVibeScores] Fetched \(results.count) daily vibe scores")
            return results

        } catch {
            print("❌ [fetchWeeklyDailyVibeScores] Error: \(error.localizedDescription)")
            if let decodingError = error as? DecodingError {
                print("❌ Decoding error details: \(decodingError)")
            }
            return []
        }
    }
}