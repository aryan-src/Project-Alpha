import Foundation
import CoreGraphics

/// Represents a single tracked hand with all its flexible nodes and kinematic metadata
public struct TrackedHand: Codable, Equatable {
    /// Unique tracking index (0 = primary hand, 1 = secondary hand)
    public let id: Int
    
    /// Estimated hand chirality ("Left", "Right", or "Unknown")
    public var handedness: String
    
    /// Overall tracking confidence (0.0 to 1.0)
    public var confidence: Float
    
    /// Dictionary of all tracked nodes keyed by id (e.g. "wrist", "index_tip", "palm_center")
    public var nodes: [String: HandNode]
    
    /// Dedicated palm tracking data and normal orientation
    public var palm: PalmData
    
    /// Normalized bounding box of the hand [0,0,1,1]
    public var boundingBox: CGRect
    
    /// Continuous finger extension ratio (0.0 = curled into palm, 1.0 = fully straight)
    public var fingerExtensions: [String: CGFloat]
    
    /// Continuous angular spread between adjacent fingers (in degrees)
    public var fingerSpreads: [String: CGFloat]

    public init(
        id: Int,
        handedness: String,
        confidence: Float,
        nodes: [String: HandNode],
        palm: PalmData,
        boundingBox: CGRect,
        fingerExtensions: [String: CGFloat] = [:],
        fingerSpreads: [String: CGFloat] = [:]
    ) {
        self.id = id
        self.handedness = handedness
        self.confidence = confidence
        self.nodes = nodes
        self.palm = palm
        self.boundingBox = boundingBox
        self.fingerExtensions = fingerExtensions
        self.fingerSpreads = fingerSpreads
    }
    
    /// Quick node lookup helper
    public func node(_ id: String) -> HandNode? {
        return nodes[id]
    }
    
    /// Returns the Euclidean distance between two nodes if both exist
    public func distance(between id1: String, and id2: String) -> CGFloat? {
        guard let n1 = nodes[id1], let n2 = nodes[id2] else { return nil }
        let dx = n1.x - n2.x
        let dy = n1.y - n2.y
        let dz = n1.z - n2.z
        return sqrt(dx * dx + dy * dy + dz * dz)
    }
}

/// Complete capture frame containing all tracked hands and frame metadata
public struct HandFrame: Codable, Equatable {
    /// Unix timestamp in seconds
    public let timestamp: Double
    
    /// Monotonically increasing frame counter
    public let frameIndex: Int
    
    /// Current capture and processing frames-per-second
    public var fps: Double
    
    /// Collection of detected and tracked hands in this frame
    public var hands: [TrackedHand]
    
    public init(
        timestamp: Double = Date().timeIntervalSince1970,
        frameIndex: Int = 0,
        fps: Double = 0.0,
        hands: [TrackedHand] = []
    ) {
        self.timestamp = timestamp
        self.frameIndex = frameIndex
        self.fps = fps
        self.hands = hands
    }
    
    /// Serializes the frame into JSON string for streaming
    public func toJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
