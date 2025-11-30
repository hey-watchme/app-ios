//
//  ReportView.swift
//  ios_watchme_v9
//
//  Report tab container - Currently showing Daily tab only
//  TODO: Enable Weekly/Monthly tabs when ready
//

import SwiftUI

struct ReportView: View {
    @EnvironmentObject var userAccountManager: UserAccountManager
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var dataManager: SupabaseDataManager

    // MARK: - Tab selection (hidden for now)
    // @State private var selectedTab = 0 // 0: Daily, 1: Weekly, 2: Monthly

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 16) {
                Text("レポート")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // TODO: Tab Picker (hidden until Weekly/Monthly are ready)
            // Picker("", selection: $selectedTab) {
            //     Text("日次").tag(0)
            //     Text("週次").tag(1)
            //     Text("月次").tag(2)
            // }
            // .pickerStyle(SegmentedPickerStyle())
            // .padding(.horizontal, 20)
            // .padding(.bottom, 16)

            // Daily Tab Only (for now)
            DailyReportView()
                .environmentObject(deviceManager)
                .environmentObject(dataManager)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Future Implementation
// When Weekly/Monthly tabs are ready, uncomment the following:
//
// TabView(selection: $selectedTab) {
//     DailyReportView()
//         .environmentObject(deviceManager)
//         .environmentObject(dataManager)
//         .tag(0)
//
//     WeeklyReportView()
//         .environmentObject(deviceManager)
//         .environmentObject(dataManager)
//         .tag(1)
//
//     MonthlyReportView()
//         .environmentObject(deviceManager)
//         .environmentObject(dataManager)
//         .tag(2)
// }
// .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
