//
//  WAVFile.swift
//  ios_watchme_v9
//
//  Reads and repairs the RIFF/WAVE header of our recordings (16 kHz, 16-bit, mono LPCM).
//  AVAudioRecorder writes the final chunk sizes when it stops; if the app dies while
//  recording, the sizes on disk are zero or stale while the samples are all there.
//  repairHeader() puts the sizes back from the file length so the chunk can be sent.
//

import Foundation

enum WAVFile {
    static let bytesPerSecond: Double = 16_000 * 2 * 1  // sample rate * bytes per sample * channels

    struct Layout {
        let dataOffset: UInt64   // first byte of samples
        let dataSize: UInt64     // as written in the header
    }

    enum RepairError: LocalizedError {
        case notRIFF
        case noDataChunk
        case tooShort

        var errorDescription: String? {
            switch self {
            case .notRIFF: return "WAV のヘッダが見つかりません"
            case .noDataChunk: return "WAV の data チャンクが見つかりません"
            case .tooShort: return "音声がほとんど記録されていません"
            }
        }
    }

    /// Walk the RIFF chunks to find where the samples start. Tolerates the FLLR padding
    /// chunk CoreAudio inserts and header sizes that are wrong (crash) or zero.
    static func layout(of url: URL) throws -> Layout {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let fileSize = try handle.seekToEnd()
        guard fileSize >= 12 else { throw RepairError.tooShort }
        try handle.seek(toOffset: 0)
        guard let head = try handle.read(upToCount: 12), head.count == 12,
              head[0..<4] == Data("RIFF".utf8), head[8..<12] == Data("WAVE".utf8) else {
            throw RepairError.notRIFF
        }

        var offset: UInt64 = 12
        while offset + 8 <= fileSize {
            try handle.seek(toOffset: offset)
            guard let header = try handle.read(upToCount: 8), header.count == 8 else { break }
            let id = String(decoding: header[0..<4], as: UTF8.self)
            let size = UInt64(littleEndian32(header[4..<8]))
            if id == "data" {
                return Layout(dataOffset: offset + 8, dataSize: size)
            }
            // Chunks are word-aligned; a zero/garbage size on the data chunk is handled above, others we skip.
            let advance = 8 + size + (size % 2)
            if advance == 0 { break }
            offset += advance
        }
        throw RepairError.noDataChunk
    }

    /// Seconds of audio actually present on disk (from the file length, not the header).
    static func duration(of url: URL) -> Double? {
        guard let layout = try? layout(of: url),
              let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64,
              size > layout.dataOffset else { return nil }
        return Double(size - layout.dataOffset) / bytesPerSecond
    }

    /// Rewrite the RIFF and data sizes from the file length. Returns the duration in seconds.
    @discardableResult
    static func repairHeader(at url: URL) throws -> Double {
        let layout = try layout(of: url)
        let handle = try FileHandle(forUpdating: url)
        defer { try? handle.close() }
        let fileSize = try handle.seekToEnd()
        guard fileSize > layout.dataOffset + UInt64(bytesPerSecond) else { throw RepairError.tooShort }

        let dataSize = UInt32(truncatingIfNeeded: fileSize - layout.dataOffset)
        let riffSize = UInt32(truncatingIfNeeded: fileSize - 8)
        try handle.seek(toOffset: 4)
        try handle.write(contentsOf: littleEndianBytes(riffSize))
        try handle.seek(toOffset: layout.dataOffset - 4)
        try handle.write(contentsOf: littleEndianBytes(dataSize))
        try handle.synchronize()
        return Double(dataSize) / bytesPerSecond
    }

    private static func littleEndian32(_ bytes: Data) -> UInt32 {
        bytes.enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << (8 * UInt32($1.offset)) }
    }

    private static func littleEndianBytes(_ value: UInt32) -> Data {
        Data([UInt8(value & 0xff), UInt8((value >> 8) & 0xff), UInt8((value >> 16) & 0xff), UInt8((value >> 24) & 0xff)])
    }
}
