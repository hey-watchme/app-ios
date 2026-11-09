//
//  AudioImporter.swift
//  ios_watchme_v9
//
//  Turns any audio or video file (Files app, camera roll) into the same 5-minute
//  16 kHz WAV chunks the recorder makes, and hands them to the same journal and
//  uploader. No length limit. See platform/docs/long-recording.md.
//
//  Time matters for the analysis (a talk at 7 am is not a talk at 11 pm), so each
//  chunk is stamped with when it was RECORDED, not when it was imported:
//    1. the date embedded in the file (videos from the camera, many m4a files)
//    2. the file's creation date
//    3. the file's modification date minus its duration (a recorder that stamps the end)
//    4. only when none exists: the import time (said so in the message)
//
//  Chunks are journaled as they are written, exactly like a live recording, so an
//  import cut off by the app being killed is recovered and sent up to where it got.
//

import AVFoundation
import Foundation
import UIKit

enum AudioImportError: LocalizedError {
    case noAudioTrack
    case notEnoughSpace(needed: Int64, free: Int64)
    case readFailed(String)
    case empty

    var errorDescription: String? {
        switch self {
        case .noAudioTrack:
            return "このファイルには音声が含まれていません"
        case .notEnoughSpace(let needed, let free):
            return "空き容量が足りません（必要 \(needed / 1_048_576) MB、残り \(free / 1_048_576) MB）"
        case .readFailed(let message):
            return "音声を読み込めませんでした: \(message)"
        case .empty:
            return "音声がほとんど入っていませんでした"
        }
    }
}

struct ImportResult {
    enum StartSource {
        case embedded, fileCreation, fileModification, importTime

        var label: String {
            switch self {
            case .embedded: return "ファイルに記録された撮影・録音日時"
            case .fileCreation: return "ファイルの作成日時"
            case .fileModification: return "ファイルの更新日時から逆算"
            case .importTime: return "日時が分からなかったため取り込んだ時刻"
            }
        }
    }

    let sessionId: String
    let chunkCount: Int
    let durationSeconds: Double
    let startedAt: Date
    let startSource: StartSource
}

enum AudioImporter {
    /// Dates of the original file, read before it is copied (a copy gets new dates).
    struct FileDates {
        let created: Date?
        let modified: Date?

        static func of(_ url: URL) -> FileDates {
            let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
            return FileDates(created: values?.creationDate, modified: values?.contentModificationDate)
        }
    }

    private static let bytesPerChunk = Int(AudioRecorderService.chunkSeconds * WAVFile.bytesPerSecond)
    private static let pcmSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatLinearPCM),
        AVSampleRateKey: 16000.0,
        AVNumberOfChannelsKey: 1,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsNonInterleaved: false,
    ]

    /// Convert `url` into journaled chunks for `deviceId`. `progress` gets 0...1 on the main actor.
    @MainActor
    static func importFile(
        at url: URL,
        originalDates: FileDates?,
        deviceId: String,
        timezone: TimeZone,
        progress: @escaping @MainActor (Double) -> Void
    ) async throws -> ImportResult {
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard !tracks.isEmpty else { throw AudioImportError.noAudioTrack }
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite, duration >= 1 else { throw AudioImportError.empty }

        try ensureFreeSpace(forSeconds: duration)
        let (startedAt, source) = await recordingStart(of: asset, dates: originalDates ?? FileDates.of(url), duration: duration)

        // Keep converting for a while if the person leaves the app
        var backgroundTask = UIBackgroundTaskIdentifier.invalid
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "audio-import") {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
        defer {
            if backgroundTask != .invalid { UIApplication.shared.endBackgroundTask(backgroundTask) }
        }

        let sessionId = UUID().uuidString
        let writer = ChunkWriter(sessionId: sessionId, deviceId: deviceId, timezone: timezone, startedAt: startedAt)
        let totalBytes = max(duration * WAVFile.bytesPerSecond, 1)

        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderAudioMixOutput(audioTracks: tracks, audioSettings: pcmSettings)
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw AudioImportError.readFailed("出力を設定できません") }
        reader.add(output)
        guard reader.startReading() else {
            throw AudioImportError.readFailed(reader.error?.localizedDescription ?? "読み込みを開始できません")
        }

        do {
            // Read on a background thread; hand each block of samples to the writer (main actor, journals chunks).
            let stream = AsyncThrowingStream<Data, Error> { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    while reader.status == .reading, let buffer = output.copyNextSampleBuffer() {
                        if let block = CMSampleBufferGetDataBuffer(buffer) {
                            let length = CMBlockBufferGetDataLength(block)
                            var data = Data(count: length)
                            let status = data.withUnsafeMutableBytes { raw in
                                CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: raw.baseAddress!)
                            }
                            if status == kCMBlockBufferNoErr {
                                continuation.yield(data)
                            }
                        }
                    }
                    if reader.status == .failed {
                        continuation.finish(throwing: AudioImportError.readFailed(reader.error?.localizedDescription ?? "不明なエラー"))
                    } else {
                        continuation.finish()
                    }
                }
            }
            for try await data in stream {
                try await writer.append(data)
                progress(min(Double(writer.totalBytes) / totalBytes, 1))
            }
            try await writer.finish()
        } catch {
            reader.cancelReading()
            // Whatever was written is already journaled and will be sent; close the open chunk.
            try? await writer.finish()
            throw error
        }

        guard writer.chunkCount > 0 else { throw AudioImportError.empty }
        return ImportResult(
            sessionId: sessionId,
            chunkCount: writer.chunkCount,
            durationSeconds: Double(writer.totalBytes) / WAVFile.bytesPerSecond,
            startedAt: startedAt,
            startSource: source
        )
    }

    // MARK: - When was it recorded

    private static func recordingStart(of asset: AVURLAsset, dates: FileDates, duration: Double) async -> (Date, ImportResult.StartSource) {
        if let item = try? await asset.load(.creationDate), let date = try? await item.load(.dateValue) {
            return (date, .embedded)
        }
        if let created = dates.created {
            return (created, .fileCreation)
        }
        if let modified = dates.modified {
            return (modified.addingTimeInterval(-duration), .fileModification)
        }
        return (Date(), .importTime)
    }

    private static func ensureFreeSpace(forSeconds seconds: Double) throws {
        let needed = Int64(seconds * WAVFile.bytesPerSecond) + 50 * 1_048_576
        let values = try? UploadJournal.documentsDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        if let free = values?.volumeAvailableCapacityForImportantUsage, free < needed {
            throw AudioImportError.notEnoughSpace(needed: needed, free: free)
        }
    }

    // MARK: - Writing chunks

    /// Writes PCM into consecutive 5-minute WAV files, journaling each like the recorder does.
    @MainActor
    private final class ChunkWriter {
        let sessionId: String
        let deviceId: String
        let timezone: TimeZone
        let startedAt: Date

        private(set) var chunkCount = 0
        private(set) var totalBytes = 0
        private var handle: FileHandle?
        private var currentId: String?
        private var currentBytes = 0

        init(sessionId: String, deviceId: String, timezone: TimeZone, startedAt: Date) {
            self.sessionId = sessionId
            self.deviceId = deviceId
            self.timezone = timezone
            self.startedAt = startedAt
        }

        func append(_ data: Data) async throws {
            var offset = 0
            while offset < data.count {
                if handle == nil { try await openChunk() }
                let take = min(data.count - offset, AudioImporter.bytesPerChunk - currentBytes)
                try handle?.write(contentsOf: data.subdata(in: offset..<(offset + take)))
                offset += take
                currentBytes += take
                totalBytes += take
                if currentBytes >= AudioImporter.bytesPerChunk {
                    try await closeChunk()
                }
            }
        }

        func finish() async throws {
            try await closeChunk()
        }

        private func openChunk() async throws {
            let recordedAt = startedAt.addingTimeInterval(Double(chunkCount) * AudioRecorderService.chunkSeconds)
            let fileName = ChunkUploader.fileName(for: recordedAt, timezone: timezone)
            let url = UploadJournal.documentsDirectory.appendingPathComponent(fileName)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            // The same file imported twice maps to the same names; the server treats it as the same recording.
            try? FileManager.default.removeItem(at: url)
            FileManager.default.createFile(atPath: url.path, contents: WAVFile.header(dataSize: 0))
            handle = try FileHandle(forWritingTo: url)
            try handle?.seekToEnd()

            let id = UUID().uuidString
            currentId = id
            currentBytes = 0
            ChunkUploader.shared.activeRecordingIds.insert(id)
            await ChunkUploader.shared.chunkStarted(ChunkRecord(
                id: id, fileName: fileName, deviceId: deviceId, recordedAt: recordedAt,
                sessionId: sessionId, sequence: chunkCount, durationSeconds: nil, state: .recording
            ))
            chunkCount += 1
        }

        private func closeChunk() async throws {
            guard let open = handle, let id = currentId else { return }
            try open.synchronize()
            try open.close()
            handle = nil
            currentId = nil
            ChunkUploader.shared.activeRecordingIds.remove(id)

            if let record = await UploadJournal.shared.record(id: id) {
                if currentBytes < Int(WAVFile.bytesPerSecond) {
                    // Less than a second at the very end: not worth a recording of its own.
                    await ChunkUploader.shared.delete(id: id)
                    chunkCount -= 1
                    return
                }
                try WAVFile.repairHeader(at: record.fileURL)
            }
            await ChunkUploader.shared.chunkFinished(id: id)
        }
    }
}
