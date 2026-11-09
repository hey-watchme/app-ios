//
//  UploadJournal.swift
//  ios_watchme_v9
//
//  The on-disk record of every recording chunk from the moment recording starts until
//  the server has it. This file, not memory or UserDefaults, is the source of truth:
//  the app's state is rebuilt from it on every launch, so a crash, a kill or a reboot
//  never loses track of a chunk. See platform/docs/long-recording.md.
//

import Foundation

// MARK: - ChunkRecord

/// One recording chunk (or a stand-alone recording / imported file).
struct ChunkRecord: Codable, Identifiable, Equatable {
    enum State: String, Codable {
        case recording   // file is being written (a crash leaves it here -> repaired on launch)
        case recorded    // closed, waiting to be sent (or waiting for the next retry)
        case uploading   // handed to the background URLSession
        case blocked     // needs a person: the server refused it (4xx) in a way a retry cannot fix
    }

    let id: String
    let fileName: String          // YYYY-MM-DD/HH-mm-ss.wav under Documents
    let deviceId: String          // the device the chunk was recorded for (not the one selected later)
    let recordedAt: Date          // start of this chunk, UTC instant
    let sessionId: String?        // nil for stand-alone recordings and imported files
    let sequence: Int?            // chunk index within the session
    var durationSeconds: Double?  // from the WAV header once the file is closed
    var state: State
    var attempts: Int = 0
    var lastError: String?
    var nextRetryAt: Date?
    var s3Key: String?
    var recovered: Bool = false   // true when the file was repaired after a crash

    var fileURL: URL {
        UploadJournal.documentsDirectory.appendingPathComponent(fileName)
    }

    var fileSize: Int64 {
        (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64) ?? 0
    }

    var fileExists: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }
}

// MARK: - UploadJournal

/// Owns Documents/upload-journal.json. All access goes through this actor so two
/// writers (the recorder and the uploader's delegate) never race, and every change
/// is written out atomically before the call returns.
actor UploadJournal {
    static let shared = UploadJournal()

    static let documentsDirectory: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }()

    private let fileURL = UploadJournal.documentsDirectory.appendingPathComponent("upload-journal.json")
    private var records: [ChunkRecord] = []
    private var loaded = false

    private struct Snapshot: Codable {
        var version = 1
        var records: [ChunkRecord]
    }

    // MARK: Reading

    func all() -> [ChunkRecord] {
        load()
        return records.sorted { $0.recordedAt > $1.recordedAt }
    }

    func record(id: String) -> ChunkRecord? {
        load()
        return records.first { $0.id == id }
    }

    func records(in state: ChunkRecord.State) -> [ChunkRecord] {
        load()
        return records.filter { $0.state == state }
    }

    func records(sessionId: String) -> [ChunkRecord] {
        load()
        return records.filter { $0.sessionId == sessionId }.sorted { ($0.sequence ?? 0) < ($1.sequence ?? 0) }
    }

    // MARK: Writing

    func add(_ record: ChunkRecord) {
        load()
        records.removeAll { $0.id == record.id }
        records.append(record)
        save()
    }

    @discardableResult
    func update(id: String, _ change: (inout ChunkRecord) -> Void) -> ChunkRecord? {
        load()
        guard let index = records.firstIndex(where: { $0.id == id }) else { return nil }
        change(&records[index])
        save()
        return records[index]
    }

    func remove(id: String) {
        load()
        records.removeAll { $0.id == id }
        save()
    }

    // MARK: Persistence

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            records = try decoder().decode(Snapshot.self, from: data).records
        } catch {
            // Never lose the file silently: keep it aside for a look, start from the recordings on disk.
            let aside = fileURL.deletingPathExtension().appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: fileURL, to: aside)
            print("❌ [Journal] could not read the journal, moved it aside: \(error)")
        }
    }

    private func save() {
        do {
            let data = try encoder().encode(Snapshot(records: records))
            // Write to a temporary file first, then swap: a crash mid-write leaves the old journal intact.
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("❌ [Journal] could not write the journal: \(error)")
        }
    }

    private func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
