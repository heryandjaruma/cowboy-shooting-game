//
//  GameProtocol.swift
//  Cowboy Shooting Game
//
//  A small custom framing protocol layered on top of TCP via NWProtocolFramer.
//  It preserves message boundaries and tags every message with a GameMessageType,
//  so `NWConnection.receiveMessage` hands back one whole, typed game message at a time.
//
//  These types are `nonisolated` on purpose: the Network framework invokes the
//  framer callbacks on its own dispatch queue, not the main actor. (The target
//  builds with SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor, so without this they
//  would default to @MainActor and fail to satisfy the framer requirements.)
//

import Foundation
import Network

/// The kinds of messages exchanged during a duel.
///
/// Keep discrete, must-arrive events (`gameEvent`) separate from high-frequency,
/// latest-value-wins updates (`playerState`) so the game layer can treat them
/// differently later (e.g. move `playerState` onto an unreliable transport).
nonisolated enum GameMessageType: UInt32, Sendable {
    case invalid = 0
    /// Sent once right after connecting: identifies the peer (currently its name).
    case handshake = 1
    /// High-frequency snapshot — position, aim, ready-flag, etc.
    case playerState = 2
    /// Discrete gameplay event — shot fired, hit registered, round start/end.
    case gameEvent = 3
}

/// Fixed 8-byte header prepended to every framed message: type + payload length.
nonisolated struct GameProtocolHeader {
    let type: UInt32
    let length: UInt32

    static let encodedSize = MemoryLayout<UInt32>.size * 2 // 8 bytes

    init(type: UInt32, length: UInt32) {
        self.type = type
        self.length = length
    }

    /// Decode a header from the first `encodedSize` bytes of `buffer`.
    init(_ buffer: UnsafeMutableRawBufferPointer) {
        // iOS is always little-endian; a straight load is fine.
        var type: UInt32 = 0
        var length: UInt32 = 0
        withUnsafeMutableBytes(of: &type) { dst in
            dst.copyBytes(from: UnsafeRawBufferPointer(rebasing: buffer[0..<4]))
        }
        withUnsafeMutableBytes(of: &length) { dst in
            dst.copyBytes(from: UnsafeRawBufferPointer(rebasing: buffer[4..<8]))
        }
        self.type = type
        self.length = length
    }

    var encodedData: Data {
        var type = self.type
        var length = self.length
        var data = Data(capacity: Self.encodedSize)
        withUnsafeBytes(of: &type) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: &length) { data.append(contentsOf: $0) }
        return data
    }
}

/// The framer implementation registered into the Network protocol stack.
nonisolated final class GameProtocol: NWProtocolFramerImplementation {

    static let definition = NWProtocolFramer.Definition(implementation: GameProtocol.self)
    static let label = "CowboyDuel"

    required init(framer: NWProtocolFramer.Instance) {}

    func start(framer: NWProtocolFramer.Instance) -> NWProtocolFramer.StartResult { .ready }
    func wakeup(framer: NWProtocolFramer.Instance) {}
    func stop(framer: NWProtocolFramer.Instance) -> Bool { true }
    func cleanup(framer: NWProtocolFramer.Instance) {}

    /// Parse inbound bytes: read a header, then deliver exactly that many payload bytes.
    func handleInput(framer: NWProtocolFramer.Instance) -> Int {
        while true {
            var header: GameProtocolHeader?
            let headerSize = GameProtocolHeader.encodedSize
            let parsed = framer.parseInput(minimumIncompleteLength: headerSize,
                                           maximumLength: headerSize) { buffer, _ in
                guard let buffer, buffer.count >= headerSize else { return 0 }
                header = GameProtocolHeader(buffer)
                return headerSize
            }

            // Not enough bytes yet for a full header — ask to be called again.
            guard parsed, let header else { return headerSize }

            let message = NWProtocolFramer.Message(gameMessageType:
                GameMessageType(rawValue: header.type) ?? .invalid)

            if !framer.deliverInputNoCopy(length: Int(header.length),
                                          message: message,
                                          isComplete: true) {
                return 0
            }
        }
    }

    /// Write outbound bytes: header first, then the caller's payload.
    func handleOutput(framer: NWProtocolFramer.Instance,
                      message: NWProtocolFramer.Message,
                      messageLength: Int,
                      isComplete: Bool) {
        let header = GameProtocolHeader(type: message.gameMessageType.rawValue,
                                        length: UInt32(messageLength))
        framer.writeOutput(data: header.encodedData)
        do {
            try framer.writeOutputNoCopy(length: messageLength)
        } catch {
            print("GameProtocol: writeOutputNoCopy failed: \(error)")
        }
    }
}

// MARK: - Game-event channels

/// `.gameEvent` payloads are multiplexed by a leading channel byte so several
/// controllers can share the single connection without stepping on each other.
nonisolated enum GameChannel: UInt8 {
    case match = 1   // ready / countdown coordination (CountdownController)
    case shot = 2    // draw / verdict (ShotController)
    case clock = 3   // clock-offset estimation (GameConnectionManager)
    case scene = 4   // "both players reached the GameScene" handshake (GameScene)
}

/// Little-endian encoding for the scalar values we ship inside game events.
nonisolated enum BinaryCoding {
    static func encode(_ value: Double) -> Data {
        var bits = value.bitPattern.littleEndian
        return withUnsafeBytes(of: &bits) { Data($0) }
    }

    static func decode(_ data: Data) -> Double? {
        guard data.count >= 8 else { return nil }
        var bits: UInt64 = 0
        withUnsafeMutableBytes(of: &bits) { $0.copyBytes(from: data.prefix(8)) }
        return Double(bitPattern: UInt64(littleEndian: bits))
    }

    static func encode(_ value: UInt64) -> Data {
        var v = value.littleEndian
        return withUnsafeBytes(of: &v) { Data($0) }
    }

    static func decodeU64(_ data: Data) -> UInt64? {
        guard data.count >= 8 else { return nil }
        var v: UInt64 = 0
        withUnsafeMutableBytes(of: &v) { $0.copyBytes(from: data.prefix(8)) }
        return UInt64(littleEndian: v)
    }
}

// MARK: - Attaching a message type to NWProtocolFramer.Message

nonisolated extension NWProtocolFramer.Message {
    convenience init(gameMessageType: GameMessageType) {
        self.init(definition: GameProtocol.definition)
        self["GameMessageType"] = gameMessageType
    }

    var gameMessageType: GameMessageType {
        (self["GameMessageType"] as? GameMessageType) ?? .invalid
    }
}
