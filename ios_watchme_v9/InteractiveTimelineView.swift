//
//  InteractiveTimelineView.swift
//  ios_watchme_v9
//
//  インタラクティブなタイムラインコンポーネント
//

import SwiftUI

struct InteractiveTimelineView: View {
    let vibeScores: [Double?]
    let vibeChanges: [VibeChange]?
    var onEventBurst: ((Double) -> Void)? = nil  // バーストトリガー用コールバック
    
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
                ZStack {
                    // グラフ背景とライン
                    graphView(in: geometry)
                    
                    // パーティクルエフェクト層（Phase 3）
                    if showParticles,
                       currentTimeIndex < vibeScores.count,
                       let score = vibeScores[currentTimeIndex] {
                        ParticleEffectView(
                            emotionScore: score,
                            isActive: true  // 常にアクティブ（自動再生中）
                        )
                        .allowsHitTesting(false)
                    }
                    
                    // タイムインジケーター（垂直線）
                    timeIndicator(in: geometry)
                    
                    // イベントポップアップ
                    if showEventDetail, let event = selectedEvent {
                        eventPopup(event: event, in: geometry)
                    }
                }
                .onTapGesture { location in
                    // タップでインジケーターを即座に移動
                    handleTap(location: location, width: geometry.size.width)
                }
            }
            .frame(height: 200) // グラフの高さを固定
            
            // 現在の時刻と感情スコア表示（グラフの下に移動）
            currentStatusView
                .padding(.top, 12)
        }
        .onAppear {
            // 自動ループ再生を開始
            resetAndStartPlayback()
        }
        .onDisappear {
            stopPlayback()
        }
        // データが変更されたらリセット
        .onChange(of: vibeScores) { _, newScores in
            print("🔄 InteractiveTimelineView: vibeScoresが変更されました")
            resetAndStartPlayback()
        }
    }
    
    // MARK: - Current Status View
    private var currentStatusView: some View {
        // シンプルに時刻とスコアのみの1行表示（中央寄せ、幅いっぱい使用）
        HStack {
            Spacer()
            
            // 時刻表示（見出しなし）
            Text(currentTimeString)
                .font(.system(size: 24, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.safeColor("BehaviorTextPrimary")) // #1a1a1a
            
            Spacer()
            
            // 現在のスコア（pt付き、見出しなし）
            HStack(spacing: 6) {
                Text("\(currentScoreString)pt")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(currentScoreColor)
                
                // トレンドインジケーター
                Image(systemName: trendIcon)
                    .font(.callout)
                    .foregroundStyle(currentScoreColor)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity) // 左右いっぱいまで使用
        .padding(.horizontal, 16) // 最小限のパディング
        .animation(.spring(response: 0.3), value: currentTimeIndex)
    }
    
    // MARK: - Graph View
    private func graphView(in geometry: GeometryProxy) -> some View {
        ZStack {
            // 背景グラデーション
            LinearGradient(
                colors: [
                    Color.cyan.opacity(0.05),
                    Color.purple.opacity(0.05)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .cornerRadius(16)
            
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
            
            // グラフライン（現在位置まで）
            Path { path in
                var firstPoint = true
                
                for index in 0...min(currentTimeIndex, vibeScores.count - 1) {
                    guard let score = vibeScores[index] else { continue }
                    
                    let x = geometry.size.width * CGFloat(index) / CGFloat(vibeScores.count - 1)
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
                LinearGradient(
                    colors: [.cyan, .blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                lineWidth: 3
            )
            .animation(.linear(duration: 0.1), value: currentTimeIndex)
            
            // 未来のグラフライン（白い実線で表示）
            Path { path in
                var firstPoint = true
                
                for index in max(0, currentTimeIndex)...(vibeScores.count - 1) {
                    guard let score = vibeScores[index] else { continue }
                    
                    let x = geometry.size.width * CGFloat(index) / CGFloat(vibeScores.count - 1)
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
            
            // イベントマーカー
            if let changes = vibeChanges {
                ForEach(Array(changes.enumerated()), id: \.offset) { _, change in
                    if let slot = timeSlotToIndex(change.time) {
                        let x = geometry.size.width * CGFloat(slot) / CGFloat(vibeScores.count - 1)
                        let normalizedScore = (change.score + 100) / 200
                        let y = geometry.size.height * (1 - normalizedScore)
                        
                        Circle()
                            .fill(slot <= currentTimeIndex ? Color.safeColor("VibeChangeIndicatorColor") : Color.safeColor("VibeChangeIndicatorColor").opacity(0.3))
                            .frame(width: slot == currentTimeIndex ? 30 : 10, 
                                   height: slot == currentTimeIndex ? 30 : 10)
                            .position(x: x, y: y)
                            .animation(.spring(response: 0.3), value: currentTimeIndex)
                            .onTapGesture {
                                withAnimation(.spring()) {
                                    selectedEvent = change
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
        let x = geometry.size.width * CGFloat(currentTimeIndex) / CGFloat(max(1, vibeScores.count - 1))
        
        return ZStack {
            // 垂直線（見える部分）
            Path { path in
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: geometry.size.height))
            }
            .stroke(
                LinearGradient(
                    colors: [Color.safeColor("TimelineIndicator").opacity(0.6), Color.safeColor("TimelineIndicator")],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 2
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
        }
    }
    
    // MARK: - Event Popup
    private func eventPopup(event: VibeChange, in geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(event.time)
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
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.safeColor("VibeChangeIndicatorColor").opacity(0.5), lineWidth: 1)
                )
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
    
    
    // MARK: - Helper Methods
    private func getCurrentYPosition(in geometry: GeometryProxy) -> CGFloat {
        guard currentTimeIndex < vibeScores.count,
              let score = vibeScores[currentTimeIndex] else {
            return geometry.size.height / 2
        }
        
        let normalizedScore = (score + 100) / 200
        return geometry.size.height * (1 - normalizedScore)
    }
    
    // タップハンドラー（インジケーターを移動）
    private func handleTap(location: CGPoint, width: CGFloat) {
        // タップ位置にインジケーターを移動
        stopPlayback()
        
        let progress = min(max(0, location.x / width), 1)
        let newIndex = Int(progress * CGFloat(vibeScores.count - 1))
        
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
        
        // ドラッグ開始位置からの相対移動で計算
        let startX = width * CGFloat(dragStartIndex) / CGFloat(max(1, vibeScores.count - 1))
        let newX = startX + value.translation.width
        let progress = min(max(0, newX / width), 1)
        let newIndex = Int(progress * CGFloat(vibeScores.count - 1))
        
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
        
        // 有効なデータの最後のインデックスを見つける
        let lastValidIndex = findLastValidDataIndex()
        
        // 有効なデータがない場合は再生しない
        guard lastValidIndex >= 0 else {
            print("⚠️ InteractiveTimelineView: 有効なデータがないため再生をスキップ")
            return
        }
        
        playbackTimer = Timer.scheduledTimer(withTimeInterval: playbackSpeed, repeats: true) { _ in
            withAnimation(.linear(duration: self.playbackSpeed)) {
                // 有効なデータの範囲内でのみ移動
                if self.currentTimeIndex < lastValidIndex {
                    self.currentTimeIndex += 1
                    self.checkForEvent()
                } else {
                    // 有効なデータの最後まで到達したら停止
                    self.stopPlayback()
                    print("✅ InteractiveTimelineView: 有効データの最後（インデックス: \(lastValidIndex)）に到達、再生停止")
                }
            }
        }
    }
    
    private func resetAndStartPlayback() {
        // すべての状態をリセット
        stopPlayback()
        currentTimeIndex = 0
        isDragging = false
        showEventDetail = false
        selectedEvent = nil
        triggerBurst = false
        showParticles = false
        dragEndTime = nil
        
        print("🎆 InteractiveTimelineView: 状態をリセットして再生開始")
        
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
        guard let changes = vibeChanges else { return }
        
        for change in changes {
            if let slot = timeSlotToIndex(change.time), slot == currentTimeIndex {
                // イベントに到達したら一時的に表示
                withAnimation(.spring()) {
                    selectedEvent = change
                    showEventDetail = true
                    // バーストエフェクトをトリガー
                    triggerBurst = true
                    // 親ビューにバーストイベントを通知
                    onEventBurst?(change.score)
                }
                
                // イベント時の軽い振動フィードバック
                hapticManager.playEventBurst()
                
                // バーストエフェクトを少し後にリセット
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    triggerBurst = false
                }
                
                // 3秒後に自動的に非表示
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        showEventDetail = false
                    }
                }
                break
            }
        }
    }
    
    private func checkForEventDuringDrag() {
        guard let changes = vibeChanges else { return }
        
        for change in changes {
            if let slot = timeSlotToIndex(change.time), slot == currentTimeIndex {
                // ドラッグ中にイベントに触れた場合
                withAnimation(.spring()) {
                    selectedEvent = change
                    showEventDetail = true
                    // 親ビューにバーストイベントを通知
                    onEventBurst?(change.score)
                }
                
                // イベント時の軽い振動フィードバック
                hapticManager.playEventBurst()
                
                // 2秒後に自動的に非表示（ドラッグ中は短めに）
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        showEventDetail = false
                    }
                }
                break
            }
        }
    }
    
    
    private func getCurrentEvent() -> VibeChange? {
        guard let changes = vibeChanges else { return nil }
        
        for change in changes {
            if let slot = timeSlotToIndex(change.time), slot == currentTimeIndex {
                return change
            }
        }
        return nil
    }
    
    private func timeSlotToIndex(_ time: String) -> Int? {
        let timeComponents = time.split(separator: "-").map(String.init)
        let timeString = timeComponents[0]
        
        let hourMin = timeString.split(separator: ":").map(String.init)
        guard hourMin.count == 2,
              let hour = Int(hourMin[0]),
              let minute = Int(hourMin[1]) else { return nil }
        
        return hour * 2 + (minute >= 30 ? 1 : 0)
    }
    
    // 有効なデータの最後のインデックスを見つける
    private func findLastValidDataIndex() -> Int {
        // 後ろから検索して、nilでないデータを見つける
        for index in stride(from: vibeScores.count - 1, through: 0, by: -1) {
            if vibeScores[index] != nil {
                return index
            }
        }
        // すべてnilの場合は-1を返す
        return -1
    }
    
    // MARK: - Computed Properties
    private var currentTimeString: String {
        let hour = currentTimeIndex / 2
        let minute = (currentTimeIndex % 2) * 30
        return String(format: "%02d:%02d", hour, minute)
    }
    
    private var currentScoreString: String {
        guard currentTimeIndex < vibeScores.count,
              let score = vibeScores[currentTimeIndex] else {
            return "---"
        }
        return String(format: "%.1f", score)
    }
    
    private var currentScoreColor: Color {
        guard currentTimeIndex < vibeScores.count,
              let score = vibeScores[currentTimeIndex] else {
            return .gray
        }
        
        if score > 30 {
            return Color.safeColor("SuccessColor")
        } else if score < -30 {
            return Color.safeColor("ErrorColor")
        } else {
            return .gray
        }
    }
    
    private var trendIcon: String {
        guard currentTimeIndex > 0 && currentTimeIndex < vibeScores.count,
              let currentScore = vibeScores[currentTimeIndex],
              let previousScore = vibeScores[currentTimeIndex - 1] else {
            return "minus.circle"
        }
        
        if currentScore > previousScore + 5 {
            return "arrow.up.circle.fill"
        } else if currentScore < previousScore - 5 {
            return "arrow.down.circle.fill"
        } else {
            return "equal.circle"
        }
    }
}