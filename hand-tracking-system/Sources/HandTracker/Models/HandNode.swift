import Foundation
import CoreGraphics

/// Represents a single flexible node (keypoint/landmark) on the hand or palm.
public struct HandNode: Codable, Equatable {
    /// Unique identifier of the node (e.g. "wrist", "index_tip", "palm_center")
    public let id: String
    
    /// Display name of the node
    public let name: String
    
    /// Normalized horizontal coordinate (0.0 = left, 1.0 = right, mirrored for natural camera view)
    public var x: CGFloat
    
    /// Normalized vertical coordinate (0.0 = top, 1.0 = bottom)
    public var y: CGFloat
    
    /// Relative estimated depth coordinate (-1.0 to 1.0, negative is closer to camera)
    public var z: CGFloat
    
    /// Detection confidence score (0.0 to 1.0)
    public var confidence: Float
    
    /// Horizontal velocity in normalized units per second
    public var vx: CGFloat
    
    /// Vertical velocity in normalized units per second
    public var vy: CGFloat
    
    /// Whether this is a virtual/computed node (like palm center) or raw vision joint
    public var isVirtual: Bool

    public init(
        id: String,
        name: String,
        x: CGFloat,
        y: CGFloat,
        z: CGFloat = 0.0,
        confidence: Float = 1.0,
        vx: CGFloat = 0.0,
        vy: CGFloat = 0.0,
        isVirtual: Bool = false
    ) {
        self.id = id
        self.name = name
        self.x = x
        self.y = y
        self.z = z
        self.confidence = confidence
        self.vx = vx
        self.vy = vy
        self.isVirtual = isVirtual
    }
    
    /// Converts normalized coordinates to pixel coordinates for a given frame size
    public func pixelPoint(in size: CGSize) -> CGPoint {
        return CGPoint(x: x * size.width, y: y * size.height)
    }
    
    /// Normalized point as CGPoint
    public var point: CGPoint {
        return CGPoint(x: x, y: y)
    }
}
