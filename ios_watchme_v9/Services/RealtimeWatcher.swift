//
//  RealtimeWatcher.swift
//  ios_watchme_v9
//
//  Subscribes to row changes (Supabase Realtime) for one device so the dashboard
//  can refresh as each analysis stage finishes: spot_stages (progress),
//  spot_results (summary / score) and daily_results (the day so far).
//  Events are debounced; the dashboard simply reloads the day.
//

import Foundation
import Supabase

@MainActor
final class RealtimeWatcher: ObservableObject {
    @Published private(set) var watchingDeviceId: String?

    var onChange: (() -> Void)?

    private var channel: RealtimeChannelV2?
    private var listeners: [Task<Void, Never>] = []
    private var pending: Task<Void, Never>?

    private let tables = ["spot_stages", "spot_results", "daily_results"]

    func watch(deviceId: String) async {
        guard watchingDeviceId != deviceId else { return }
        await stop()

        let client = SupabaseClientManager.shared.client
        let channel = client.channel("watchme-device-\(deviceId)")
        let streams = tables.map { table in
            channel.postgresChange(AnyAction.self, schema: "public", table: table, filter: "device_id=eq.\(deviceId)")
        }
        self.channel = channel
        watchingDeviceId = deviceId

        for stream in streams {
            listeners.append(Task { [weak self] in
                for await _ in stream {
                    await self?.schedule()
                }
            })
        }
        await channel.subscribe()
        #if DEBUG
        print("📡 [Realtime] watching \(tables) for device \(deviceId)")
        #endif
    }

    func stop() async {
        listeners.forEach { $0.cancel() }
        listeners = []
        pending?.cancel()
        pending = nil
        if let channel {
            await SupabaseClientManager.shared.client.removeChannel(channel)
        }
        channel = nil
        watchingDeviceId = nil
    }

    /// Several stages can finish within a second of each other; reload once.
    private func schedule() {
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            self?.onChange?()
        }
    }
}
