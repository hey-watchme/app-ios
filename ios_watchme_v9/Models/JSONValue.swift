//
//  JSONValue.swift
//  ios_watchme_v9
//
//  Generic JSON value for decoding arbitrary JSONB from Supabase
//

import Foundation

enum JSONValue: Codable, Equatable {
    case null
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null; return }
        if let v = try? container.decode(Bool.self) { self = .bool(v); return }
        if let v = try? container.decode(Int.self) { self = .int(v); return }
        if let v = try? container.decode(Double.self) { self = .double(v); return }
        if let v = try? container.decode(String.self) { self = .string(v); return }
        if let v = try? container.decode([String: JSONValue].self) { self = .object(v); return }
        if let v = try? container.decode([JSONValue].self) { self = .array(v); return }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid JSON value")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .string(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .object(let v): try container.encode(v)
        case .array(let v): try container.encode(v)
        }
    }

    /// Pretty-printed JSON string for display
    var prettyPrinted: String {
        toJSONString(indent: 2)
    }

    private func toJSONString(indent: Int) -> String {
        let prefix = String(repeating: " ", count: indent)
        let outerPrefix = String(repeating: " ", count: max(indent - 2, 0))
        switch self {
        case .null: return "null"
        case .string(let v): return "\"\(v.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
        case .int(let v): return "\(v)"
        case .double(let v): return "\(v)"
        case .bool(let v): return v ? "true" : "false"
        case .object(let dict):
            if dict.isEmpty { return "{}" }
            let entries = dict.sorted { $0.key < $1.key }.map { "\(prefix)\"\($0.key)\": \($0.value.toJSONString(indent: indent + 2))" }
            return "{\n" + entries.joined(separator: ",\n") + "\n\(outerPrefix)}"
        case .array(let arr):
            if arr.isEmpty { return "[]" }
            let entries = arr.map { "\(prefix)\($0.toJSONString(indent: indent + 2))" }
            return "[\n" + entries.joined(separator: ",\n") + "\n\(outerPrefix)]"
        }
    }
}
