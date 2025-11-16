//
//  InteractiveTimelineView.swift
//  ios_watchme_v9
//
//  インタラクティブなタイムラインコンポーネント
//

import SwiftUI

struct InteractiveTimelineView: View {
    let timeBlocks: [DashboardTimeBlock]  // spot_results data
    let burstEvents: [BurstEvent]?  // Burst events from daily_results
    var onEventBurst: ((Double) -> Void)? = nil  // Burst effect callback
    
    @State private var currentTimeIndex: Int = 0
    @State private var isDragging: Bool = false
    @State private var showEventDetail: Bool = false
    @State private var selectedEvent: VibeChange? = nil
    @State private var playbackTimer: Timer?
    @State private var showParticles: Bool = false  // パーティクルは常にOFF
    @State private var triggerBurst: Bool = false
    @State private var dragEndTime: Date? = nil
    @State private var indicatorScale: CGFloat = 1.0  // インジケーターのスケール
    @State private var dragStartIndex: Int = 0  // ドラッグ開始時のインデックス
    private let hapticManager = HapticManager.shared
    
    // アニメーション設定
    private let playbackSpeed: Double = 0.5 // 秒ごとに1スロット進む（早めの動き）
    private let restartDelay: Double = 3.0 // ドラッグ後の再開待機時間
    
    var body: some View {
        VStack(spacing: 16) {
            // メイングラフエリア（ジェスチャー対応）
            GeometryReader { geometry in
                ZStack(alignment: .topTrailing) {
                    // グラフ背景とライン
                    graphView(in: geometry)

                    // パーティクルエフェクト層（Phase 3）
                    if showParticles,
                       currentTimeIndex < timeBlocks.count {
                        ParticleEffectView(
                            emotionScore: timeBlocks[currentTimeIndex].vibeScore ?? 0,
                            isActive: true  // 常にアクティブ（自動再生中）
                        )
                        .allowsHitTesting(false)
                    }

                    // タイムインジケーター（垂直線）
                    timeIndicator(in: geometry)

                    // 現在の時刻と感情スコア表示（右上に配置）
                    currentStatusView
                        .padding(.trailing, 8)
                        .padding(.top, 8)
                        .zIndex(100)  // イベントポップアップより下

                    // イベントポップアップ（最前面）
                    if showEventDetail, let event = selectedEvent {
                        eventPopup(event: event, in: geometry)
                            .zIndex(200)  // 最前面に表示
                    }
                }
                .onTapGesture { location in
                    // タップでインジケーターを即座に移動
                    handleTap(location: location, width: geometry.size.width)
                }
            }
            .frame(height: 200) // グラフの高さを固定
        }
        .onAppear {
            // 自動ループ再生を開始
            resetAndStartPlayback()
        }
        .onDisappear {
            stopPlayback()
        }
        // データが変更されたらリセット
        .onChange(of: timeBlocks) { _, _ in
            resetAndStartPlayback()
        }
        // インジケーターが移動したときに、イベントから離れたら吹き出しを消す
        .onChange(of: currentTimeIndex) { _, _ in
            checkIfShouldHideEventDetail()
        }
    }
    
    // MARK: - Current Status View
    private var currentStatusView: some View {
        // コンパクトな表示（右上用）
        VStack(alignment: .trailing, spacing: 4) {
            // 時刻表示
            Text(currentTimeString)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.safeColor("BehaviorTextSecondary"))
            
            // 現在のスコア
            HStack(spacing: 4) {
                Text("\(currentScoreString)pt")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(currentScoreColor)
                
                // トレンドインジケーター
                Image(systemName: trendIcon)
                    .font(.system(size: 10))
                    .foregroundStyle(currentScoreColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.9))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .animation(.spring(response: 0.3), value: currentTimeIndex)
    }
    
    // MARK: - Graph View
    private func graphView(in geometry: GeometryProxy) -> some View {
        ZStack {
            // 背景（システムグレー6）
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
            
            // ゼロライン
            Path { path in
                let y = geometry.size.height / 2
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: geometry.size.width, y: y))
            }
            .stroke(
                LinearGradient(
                    colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.4), Color.gray.opacity(0.2)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 1, dash: [5, 5])
            )
            
            // グラフライン（現在位置まで）- 黒い太線
            Path { path in
                guard timeBlocks.count > 0 else { return }
                var firstPoint = true

                for index in 0...min(currentTimeIndex, timeBlocks.count - 1) {
                    // Time-based X position (0-1440 minutes in a day)
                    let minutes = getMinutesFromTime(timeBlocks[index].displayTime)
                    let x = geometry.size.width * CGFloat(minutes) / 1440.0

                    let score = timeBlocks[index].vibeScore ?? 0
                    let normalizedScore = (score + 100) / 200
                    let y = geometry.size.height * (1 - normalizedScore)

                    if firstPoint {
                        path.move(to: CGPoint(x: x, y: y))
                        firstPoint = false
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(
                Color.safeColor("BehaviorTextPrimary"),  // #1a1a1aの黒
                style: StrokeStyle(
                    lineWidth: 2,        // 3pt → 2ptに細く
                    lineCap: .round,    // 線の端を丸く
                    lineJoin: .round    // 線の接合部を丸く
                )
            )
            .animation(.linear(duration: 0.1), value: currentTimeIndex)
            
            // 未来のグラフライン（グレーの細線）
            Path { path in
                guard timeBlocks.count > 0 else { return }
                var firstPoint = true

                let startIndex = max(0, currentTimeIndex)
                let endIndex = timeBlocks.count - 1

                guard startIndex <= endIndex else { return }

                for index in startIndex...endIndex {
                    // Time-based X position (0-1440 minutes in a day)
                    let minutes = getMinutesFromTime(timeBlocks[index].displayTime)
                    let x = geometry.size.width * CGFloat(minutes) / 1440.0

                    let score = timeBlocks[index].vibeScore ?? 0
                    let normalizedScore = (score + 100) / 200
                    let y = geometry.size.height * (1 - normalizedScore)

                    if firstPoint {
                        path.move(to: CGPoint(x: x, y: y))
                        firstPoint = false
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(
                Color.gray.opacity(0.3),
                lineWidth: 1
            )
            
            // イベントマーカー（burst events）
            if let events = burstEvents {
                ForEach(Array(events.enumerated()), id: \.offset) { _, event in
                    if let slot = findTimeBlockIndex(for: event.time), slot < timeBlocks.count {
                        // Time-based X position
                        let minutes = getMinutesFromTime(timeBlocks[slot].displayTime)
                        let x = geometry.size.width * CGFloat(minutes) / 1440.0

                        // グラフ上の実際のスコアを使用（timeBlocks配列から取得）
                        let actualScore = timeBlocks[slot].vibeScore ?? 0
                        let normalizedScore = (actualScore + 100) / 200
                        let y = geometry.size.height * (1 - normalizedScore)

                        Circle()
                            .fill(slot <= currentTimeIndex ? Color.safeColor("VibeChangeIndicatorColor") : Color.safeColor("VibeChangeIndicatorColor").opacity(0.3))
                            .frame(width: 8, height: 8)
                            .position(x: x, y: y)
                            .animation(.spring(response: 0.3), value: currentTimeIndex)
                            .onTapGesture {
                                withAnimation(.spring()) {
                                    // BurstEventをVibeChangeに変換して表示（互換性のため）
                                    let eventDescription = event.scoreChange > 0 ? "Mood improved" : "Mood decreased"
                                    let vibeChange = VibeChange(time: timeBlocks[slot].displayTime, event: eventDescription, score: actualScore)
                                    selectedEvent = vibeChange
                                    showEventDetail = true
                                    currentTimeIndex = slot
                                }
                            }
                    }
                }
            }
            
            // 時間軸ラベル
            timeAxisLabels(in: geometry)
        }
    }
    
    // MARK: - Time Axis Labels
    private func timeAxisLabels(in geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            ForEach([0, 6, 12, 18, 23], id: \.self) { hour in
                Text("\(hour):00")
                    .font(.caption2)
                    .foregroundStyle(Color.safeColor("BehaviorTextSecondary")) // #666666
                    .frame(maxWidth: .infinity, alignment: hour == 0 ? .leading : (hour == 23 ? .trailing : .center))
            }
        }
        .frame(width: geometry.size.width)
        .position(x: geometry.size.width / 2, y: geometry.size.height + 15)
    }
    
    // MARK: - Time Indicator
    private func timeIndicator(in geometry: GeometryProxy) -> some View {
        // Time-based X position
        guard currentTimeIndex < timeBlocks.count else {
            return AnyView(EmptyView())
        }
        let minutes = getMinutesFromTime(timeBlocks[currentTimeIndex].displayTime)
        let x = geometry.size.width * CGFloat(minutes) / 1440.0

        return AnyView(ZStack {
            // 垂直線（見える部分）
            Path { path in
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: geometry.size.height))
            }
            .stroke(
                Color.gray.opacity(0.5),  // グレーに変更
                lineWidth: 1  // 1ptの細さ
            )
            .animation(.spring(response: 0.3), value: currentTimeIndex)
            
            // ドラッグ可能なインジケーターハンドル
            ZStack {
                // タッチ領域（透明で大きめ 120x120）
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 120, height: 120)
                    .contentShape(Rectangle())  // タッチ領域を明示的に指定
                
                // 見える部分（青い丸）
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.safeColor("TimelineIndicator").opacity(0.8), Color.safeColor("TimelineIndicator")],
                            center: .center,
                            startRadius: 0,
                            endRadius: 8
                        )
                    )
                    .frame(width: 16, height: 16)
            }
            .scaleEffect(indicatorScale)
            .position(x: x, y: getCurrentYPosition(in: geometry))
            .animation(.spring(response: 0.3), value: currentTimeIndex)
            .highPriorityGesture(  // 優先度を高く設定
                DragGesture(minimumDistance: 5)  // 最小距離を短く
                    .onChanged { value in
                        handleIndicatorDrag(value: value, width: geometry.size.width)
                    }
                    .onEnded { _ in
                        handleIndicatorDragEnd()
                    }
            )
        })
    }
    
    // MARK: - Event Popup
    private func eventPopup(event: VibeChange, in geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Extract time part only (HH:MM) from potential "YYYY-MM-DD HH:MM" format
            Text(extractTimeOnly(from: event.time))
                .font(.caption2)
                .foregroundStyle(Color.safeColor("BehaviorTextSecondary")) // #666666

            Text(event.event)
                .font(.caption)
                .foregroundStyle(Color.safeColor("BehaviorTextPrimary")) // #1a1a1a
                .lineLimit(2)

            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.caption2)
                Text(String(format: "%.1f", event.score))
                    .font(.caption)
                    .fontWeight(.bold)
            }
            .foregroundStyle(event.score > 0 ? Color.safeColor("SuccessColor") : Color.safeColor("ErrorColor"))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.95))
        )
        .shadow(color: .black.opacity(0.2), radius: 5)
        .position(
            x: geometry.size.width / 2,
            y: geometry.size.height / 2
        )
        .transition(.scale.combined(with: .opacity))
        .onTapGesture {
            withAnimation {
                showEventDetail = false
            }
        }
    }

    // Extract time part only (HH:MM) from various formats:
    // - "2025-11-16T06:01" (ISO 8601)
    // - "2025-11-16 06:01" (space-separated)
    // - "06:01" (already time-only)
    private func extractTimeOnly(from timeString: String) -> String {
        // Case 1: ISO 8601 format "2025-11-16T06:01" or "2025-11-16T06:01:00"
        if let tIndex = timeString.firstIndex(of: "T") {
            let timeStart = timeString.index(after: tIndex)
            let timePart = String(timeString[timeStart...])
            // Remove seconds if present (e.g., "06:01:00" -> "06:01")
            let components = timePart.split(separator: ":")
            if components.count >= 2 {
                return "\(components[0]):\(components[1])"
            }
            return timePart
        }

        // Case 2: Space-separated format "2025-11-16 06:01"
        if let lastSpace = timeString.lastIndex(of: " ") {
            return String(timeString[timeString.index(after: lastSpace)...])
        }

        // Case 3: Already in HH:MM format
        return timeString
    }

    // Convert time string to minutes since midnight (0-1440)
    private func getMinutesFromTime(_ timeString: String) -> Int {
        // Extract HH:MM part
        let time = extractTimeOnly(from: timeString)

        // Parse HH:MM
        let components = time.split(separator: ":").map(String.init)
        guard components.count == 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else {
            print("⚠️ [getMinutesFromTime] Failed to parse: '\(timeString)' -> '\(time)'")
            return 0
        }

        return hour * 60 + minute
    }


    // MARK: - Helper Methods
    private func getCurrentYPosition(in geometry: GeometryProxy) -> CGFloat {
        guard currentTimeIndex < timeBlocks.count else {
            return geometry.size.height / 2
        }

        let score = timeBlocks[currentTimeIndex].vibeScore ?? 0
        let normalizedScore = (score + 100) / 200
        return geometry.size.height * (1 - normalizedScore)
    }
    
    // タップハンドラー（インジケーターを移動）
    private func handleTap(location: CGPoint, width: CGFloat) {
        // タップ位置にインジケーターを移動
        stopPlayback()

        guard !timeBlocks.isEmpty else { return }

        // X座標から分単位の時刻を計算（0-1440分）
        let progress = min(max(0, location.x / width), 1)
        let targetMinutes = Int(progress * 1440.0)

        // 最も近いデータポイントを見つける
        let newIndex = timeBlocks.enumerated().min(by: { a, b in
            let aMinutes = getMinutesFromTime(a.element.displayTime)
            let bMinutes = getMinutesFromTime(b.element.displayTime)
            return abs(aMinutes - targetMinutes) < abs(bMinutes - targetMinutes)
        })?.offset ?? currentTimeIndex

        withAnimation(.spring(response: 0.3)) {
            currentTimeIndex = newIndex
            checkForEventDuringDrag()
        }

        // 軽い振動フィードバック
        hapticManager.playLightImpact()
    }
    
    // インジケーターのドラッグハンドラー
    private func handleIndicatorDrag(value: DragGesture.Value, width: CGFloat) {
        // ドラッグ中は自動再生を停止
        if !isDragging {
            isDragging = true
            stopPlayback()
            // ドラッグ開始時の位置を記録
            dragStartIndex = currentTimeIndex
            // ドラッグ開始時にインジケーターを少し大きくする
            withAnimation(.spring(response: 0.2)) {
                indicatorScale = 1.3
            }
            // 振動フィードバック
            hapticManager.playLightImpact()
        }

        guard !timeBlocks.isEmpty, dragStartIndex < timeBlocks.count else { return }

        // ドラッグ開始位置からの相対移動で計算（時刻ベース）
        let startMinutes = getMinutesFromTime(timeBlocks[dragStartIndex].displayTime)
        let startX = width * CGFloat(startMinutes) / 1440.0
        let newX = startX + value.translation.width
        let progress = min(max(0, newX / width), 1)
        let targetMinutes = Int(progress * 1440.0)

        // 最も近いデータポイントを見つける
        let newIndex = timeBlocks.enumerated().min(by: { a, b in
            let aMinutes = getMinutesFromTime(a.element.displayTime)
            let bMinutes = getMinutesFromTime(b.element.displayTime)
            return abs(aMinutes - targetMinutes) < abs(bMinutes - targetMinutes)
        })?.offset ?? currentTimeIndex

        // インデックスが変わった場合のみ更新
        if newIndex != currentTimeIndex {
            currentTimeIndex = newIndex
            checkForEventDuringDrag()
        }
    }
    
    // インジケーターのドラッグ終了ハンドラー
    private func handleIndicatorDragEnd() {
        isDragging = false
        // インジケーターを元のサイズに戻す
        withAnimation(.spring(response: 0.3)) {
            indicatorScale = 1.0
        }
        // ドラッグ終了後は手動操作モードのまま（自動再生しない）
    }
    
    private func startAutoPlayback() {
        // 既存のタイマーがあれば停止
        stopPlayback()
        
        // 有効なデータのインデックスリストを作成
        let validIndices = findValidDataIndices()
        
        // 有効なデータがない場合は再生しない
        guard !validIndices.isEmpty else {
            return
        }
        
        // 現在位置から次の有効インデックスを見つける
        var currentValidIndex = validIndices.firstIndex(of: currentTimeIndex) ?? 0
        
        playbackTimer = Timer.scheduledTimer(withTimeInterval: playbackSpeed, repeats: true) { _ in
            withAnimation(.spring(response: 0.3)) {
                // 次の有効なデータポイントに移動
                if currentValidIndex < validIndices.count - 1 {
                    currentValidIndex += 1
                    self.currentTimeIndex = validIndices[currentValidIndex]
                    self.checkForEvent()
                } else {
                    // 有効なデータの最後まで到達したら停止
                    self.stopPlayback()
                }
            }
        }
    }
    
    private func resetAndStartPlayback() {
        // すべての状態をリセット
        stopPlayback()
        isDragging = false
        showEventDetail = false
        selectedEvent = nil
        triggerBurst = false
        showParticles = false
        dragEndTime = nil
        
        // 最初の有効なデータポイントから開始
        let validIndices = findValidDataIndices()
        if !validIndices.isEmpty {
            currentTimeIndex = validIndices[0]
        } else {
            currentTimeIndex = 0
        }
        
        // 少し遅延してから再生開始（アニメーションのため）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.startAutoPlayback()
        }
    }
    
    private func stopPlayback() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    private func checkForEvent() {
        // burstEventsをチェック
        if let events = burstEvents {
            for event in events {
                if let slot = findTimeBlockIndex(for: event.time), slot == currentTimeIndex, slot < timeBlocks.count {
                    // グラフ上の実際のスコアを使用
                    let actualScore = timeBlocks[slot].vibeScore ?? 0

                    // イベントに到達したら一時的に表示
                    withAnimation(.spring()) {
                        // BurstEventをVibeChangeに変換（実際のスコアを使用）
                        let eventDescription = event.scoreChange > 0 ? "Mood improved" : "Mood decreased"
                        let vibeChange = VibeChange(time: timeBlocks[slot].displayTime, event: eventDescription, score: actualScore)
                        selectedEvent = vibeChange
                        showEventDetail = true
                        // バーストエフェクトをトリガー
                        triggerBurst = true
                        // 親ビューにバーストイベントを通知（実際のスコアを使用）
                        onEventBurst?(actualScore)
                    }

                    // イベント時の軽い振動フィードバック
                    hapticManager.playEventBurst()

                    // バーストエフェクトを少し後にリセット
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        triggerBurst = false
                    }

                    // 自動再生時のみ3秒後に非表示
                    if !isDragging {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation {
                                showEventDetail = false
                            }
                        }
                    }
                    break
                }
            }
        }
    }
    
    private func checkForEventDuringDrag() {
        // burstEventsをチェック
        if let events = burstEvents {
            for event in events {
                if let slot = findTimeBlockIndex(for: event.time), slot == currentTimeIndex, slot < timeBlocks.count {
                    // グラフ上の実際のスコアを使用
                    let actualScore = timeBlocks[slot].vibeScore ?? 0

                    // ドラッグ中にイベントに触れた場合
                    withAnimation(.spring()) {
                        // BurstEventをVibeChangeに変換（実際のスコアを使用）
                        let eventDescription = event.scoreChange > 0 ? "Mood improved" : "Mood decreased"
                        let vibeChange = VibeChange(time: timeBlocks[slot].displayTime, event: eventDescription, score: actualScore)
                        selectedEvent = vibeChange
                        showEventDetail = true
                        // 親ビューにバーストイベントを通知（実際のスコアを使用）
                        onEventBurst?(actualScore)
                    }

                    // イベント時の軽い振動フィードバック
                    hapticManager.playEventBurst()

                    // インジケーターがある間は表示を維持（自動で消さない）
                    break
                }
            }
        }
    }
    
    // インジケーターがイベントから離れたか確認
    private func checkIfShouldHideEventDetail() {
        guard showEventDetail, selectedEvent != nil else { return }

        // 現在のインジケーター位置がイベント位置と異なる場合、吹き出しを非表示
        var eventSlot: Int? = nil

        // BurstEventの場合
        if let events = burstEvents {
            for e in events {
                eventSlot = findTimeBlockIndex(for: e.time)
                if eventSlot != nil {
                    break
                }
            }
        }

        // インジケーターがイベントの位置から離れたら非表示
        if let slot = eventSlot, slot != currentTimeIndex {
            withAnimation {
                showEventDetail = false
                selectedEvent = nil
            }
        }
    }
    
    // Find timeBlock index matching the given time string
    private func findTimeBlockIndex(for timeString: String) -> Int? {
        // Extract HH:MM from timeString (might be "HH:MM" or "YYYY-MM-DDTHH:MM")
        let targetTime = extractTimeOnly(from: timeString)

        // Find matching timeBlock by displayTime
        return timeBlocks.firstIndex { $0.displayTime == targetTime }
    }

    // 有効なデータの最後のインデックスを見つける
    private func findLastValidDataIndex() -> Int {
        return timeBlocks.count - 1
    }

    // 有効なデータのインデックスリストを作成
    private func findValidDataIndices() -> [Int] {
        return Array(0..<timeBlocks.count)
    }
    
    // MARK: - Computed Properties
    private var currentTimeString: String {
        guard currentTimeIndex < timeBlocks.count else {
            return "--:--"
        }
        return timeBlocks[currentTimeIndex].displayTime
    }

    private var currentScoreString: String {
        guard currentTimeIndex < timeBlocks.count else {
            return "--"
        }
        let score = timeBlocks[currentTimeIndex].vibeScore ?? 0
        return String(format: "%.0f", score)
    }

    private var currentScoreColor: Color {
        guard currentTimeIndex < timeBlocks.count else {
            return .gray
        }

        let score = timeBlocks[currentTimeIndex].vibeScore ?? 0

        if score > 30 {
            return Color.safeColor("SuccessColor")
        } else if score < -30 {
            return Color.safeColor("ErrorColor")
        } else {
            return .gray
        }
    }

    private var trendIcon: String {
        guard currentTimeIndex > 0 && currentTimeIndex < timeBlocks.count else {
            return "minus.circle"
        }

        let currentScore = timeBlocks[currentTimeIndex].vibeScore ?? 0
        let previousScore = timeBlocks[currentTimeIndex - 1].vibeScore ?? 0

        if currentScore > previousScore + 5 {
            return "arrow.up.circle.fill"
        } else if currentScore < previousScore - 5 {
            return "arrow.down.circle.fill"
        } else {
            return "equal.circle"
        }
    }
}

// MARK: - Star Shape
struct Star: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.4
        let numberOfPoints = 5
        
        var path = Path()
        
        for i in 0..<numberOfPoints * 2 {
            let radius = i % 2 == 0 ? outerRadius : innerRadius
            let angle = Double(i) * .pi / Double(numberOfPoints) - .pi / 2
            let x = center.x + CGFloat(cos(angle)) * radius
            let y = center.y + CGFloat(sin(angle)) * radius
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        path.closeSubpath()
        return path
    }
}