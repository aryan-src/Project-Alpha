import Foundation
import CoreGraphics

/// Vector in 3D space
public struct Vector3D: Codable, Equatable {
    public var x: CGFloat
    public var y: CGFloat
    public var z: CGFloat
    
    public init(x: CGFloat, y: CGFloat, z: CGFloat) {
        self.x = x
        self.y = y
        self.z = z
    }
    
    public var length: CGFloat {
        return sqrt(x * x + y * y + z * z)
    }
    
    public var normalized: Vector3D {
        let len = length
        guard len > 0.00001 else { return Vector3D(x: 0, y: 0, z: 1) }
        return Vector3D(x: x / len, y: y / len, z: z / len)
    }
    
    public static func crossProduct(_ a: Vector3D, _ b: Vector3D) -> Vector3D {
        return Vector3D(
            x: a.y * b.z - a.z * b.y,
            y: a.z * b.x - a.x * b.z,
            z: a.x * b.y - a.y * b.x
        )
    }
    
    public static func dotProduct(_ a: Vector3D, _ b: Vector3D) -> CGFloat {
        return a.x * b.x + a.y * b.y + a.z * b.z
    }
}

/// Facing direction of the palm relative to the camera
public enum PalmFacing: String, Codable {
    case towardsCamera = "Towards Camera"
    case awayFromCamera = "Away from Camera"
    case left = "Facing Left"
    case right = "Facing Right"
    case upward = "Facing Up"
    case downward = "Facing Down"
    case unknown = "Unknown"
}

/// Represents the palm-specific kinematic data and computed nodes
public struct PalmData: Codable, Equatable {
    /// Geometric center node of the palm
    public var center: HandNode
    
    /// 3D normal vector pointing perpendicularly outward from the palm
    public var normal: Vector3D
    
    /// Estimated palm roll in degrees (-180 to 180)
    public var rollDegrees: CGFloat
    
    /// Estimated palm pitch in degrees (-90 to 90)
    public var pitchDegrees: CGFloat
    
    /// Estimated palm yaw in degrees (-90 to 90)
    public var yawDegrees: CGFloat
    
    /// Facing direction classification
    public var facing: PalmFacing
    
    /// Normalized radius / span of the palm region
    public var radius: CGFloat
    
    public init(
        center: HandNode,
        normal: Vector3D,
        rollDegrees: CGFloat = 0.0,
        pitchDegrees: CGFloat = 0.0,
        yawDegrees: CGFloat = 0.0,
        facing: PalmFacing = .towardsCamera,
        radius: CGFloat = 0.1
    ) {
        self.center = center
        self.normal = normal
        self.rollDegrees = rollDegrees
        self.pitchDegrees = pitchDegrees
        self.yawDegrees = yawDegrees
        self.facing = facing
        self.radius = radius
    }
}
