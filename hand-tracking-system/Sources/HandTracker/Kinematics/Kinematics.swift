import Foundation
import CoreGraphics
import Vision

/// Pure geometric and kinematic calculations for hand and palm tracking
public struct Kinematics {
    
    // MARK: - Distance & Angles
    
    /// Calculates 2D Euclidean distance between two points
    public static func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        let dx = p1.x - p2.x
        let dy = p1.y - p2.y
        return sqrt(dx * dx + dy * dy)
    }
    
    /// Calculates 3D distance between two Vector3D points
    public static func distance3D(_ p1: Vector3D, _ p2: Vector3D) -> CGFloat {
        let dx = p1.x - p2.x
        let dy = p1.y - p2.y
        let dz = p1.z - p2.z
        return sqrt(dx * dx + dy * dy + dz * dz)
    }
    
    /// Calculates angle in degrees at vertex p2 formed by (p1 - p2 - p3)
    public static func angle(p1: CGPoint, vertex p2: CGPoint, p3: CGPoint) -> CGFloat {
        let v1 = CGPoint(x: p1.x - p2.x, y: p1.y - p2.y)
        let v2 = CGPoint(x: p3.x - p2.x, y: p3.y - p2.y)
        
        let dot = v1.x * v2.x + v1.y * v2.y
        let mag1 = sqrt(v1.x * v1.x + v1.y * v1.y)
        let mag2 = sqrt(v2.x * v2.x + v2.y * v2.y)
        
        guard mag1 > 0.0001 && mag2 > 0.0001 else { return 0.0 }
        
        let cosAngle = max(-1.0, min(1.0, dot / (mag1 * mag2)))
        return acos(cosAngle) * 180.0 / .pi
    }
    
    // MARK: - Palm Calculations
    
    /// Computes the dynamic palm center from anatomical landmarks
    public static func computePalmCenter(
        wrist: CGPoint,
        indexMCP: CGPoint,
        middleMCP: CGPoint,
        ringMCP: CGPoint,
        littleMCP: CGPoint
    ) -> CGPoint {
        // Knuckle center
        let knuckleCenterX = (indexMCP.x + middleMCP.x + ringMCP.x + littleMCP.x) * 0.25
        let knuckleCenterY = (indexMCP.y + middleMCP.y + ringMCP.y + littleMCP.y) * 0.25
        
        // Palm center lies between wrist and knuckles (approx 58% towards knuckles)
        let palmX = wrist.x * 0.42 + knuckleCenterX * 0.58
        let palmY = wrist.y * 0.42 + knuckleCenterY * 0.58
        return CGPoint(x: palmX, y: palmY)
    }
    
    /// Computes 3D palm normal and orientation angles
    public static func computePalmNormal(
        wrist: CGPoint,
        indexMCP: CGPoint,
        littleMCP: CGPoint,
        isLeftHand: Bool
    ) -> (normal: Vector3D, roll: CGFloat, pitch: CGFloat, yaw: CGFloat, facing: PalmFacing) {
        // Vector along the palm width: from index MCP to little MCP
        let u = Vector3D(x: littleMCP.x - indexMCP.x, y: littleMCP.y - indexMCP.y, z: 0.0)
        
        // Vector along palm length: from wrist to midpoint of knuckles
        let knuckleMid = CGPoint(x: (indexMCP.x + littleMCP.x) * 0.5, y: (indexMCP.y + littleMCP.y) * 0.5)
        let v = Vector3D(x: knuckleMid.x - wrist.x, y: knuckleMid.y - wrist.y, z: 0.0)
        
        // Cross product produces palm normal
        var normal = isLeftHand ? Vector3D.crossProduct(u, v).normalized : Vector3D.crossProduct(v, u).normalized
        
        // In 2D camera image, Z depth is estimated by knuckle span foreshortening
        let knuckleSpan = distance(indexMCP, littleMCP)
        let wristLength = distance(wrist, knuckleMid)
        let aspect = knuckleSpan / max(wristLength, 0.01)
        
        // Estimate z component based on aspect ratio
        let estimatedZ: CGFloat = aspect < 0.6 ? 0.7 : -0.7
        normal.z = estimatedZ
        normal = normal.normalized
        
        // Roll: angle of knuckles line with horizontal
        let rollRad = atan2(littleMCP.y - indexMCP.y, littleMCP.x - indexMCP.x)
        var rollDeg = rollRad * 180.0 / .pi
        if rollDeg > 180 { rollDeg -= 360 }
        
        // Pitch: inclination of wrist-knuckle vector
        let pitchRad = atan2(knuckleMid.y - wrist.y, knuckleMid.x - wrist.x)
        let pitchDeg = (pitchRad + .pi / 2.0) * 180.0 / .pi
        
        // Yaw estimate based on normal x
        let yawDeg = asin(max(-1.0, min(1.0, normal.x))) * 180.0 / .pi
        
        // Facing classification
        var facing: PalmFacing = .towardsCamera
        if normal.z < -0.3 {
            facing = .towardsCamera
        } else if normal.z > 0.3 {
            facing = .awayFromCamera
        } else if normal.x > 0.4 {
            facing = .right
        } else if normal.x < -0.4 {
            facing = .left
        } else if normal.y > 0.4 {
            facing = .downward
        } else if normal.y < -0.4 {
            facing = .upward
        }
        
        return (normal, rollDeg, pitchDeg, yawDeg, facing)
    }
    
    // MARK: - Finger Extension & Kinematics
    
    /// Calculates normalized extension ratio of a finger (0.0 = fully curled, 1.0 = fully extended)
    public static func fingerExtensionRatio(
        wrist: CGPoint,
        mcp: CGPoint,
        pip: CGPoint,
        dip: CGPoint,
        tip: CGPoint
    ) -> CGFloat {
        // Direct distance from MCP to Tip
        let directDist = distance(mcp, tip)
        
        // Segment lengths along the finger
        let seg1 = distance(mcp, pip)
        let seg2 = distance(pip, dip)
        let seg3 = distance(dip, tip)
        let totalSegmentLength = max(seg1 + seg2 + seg3, 0.001)
        
        // Ratio of direct span to total articulated segment length
        let ratio = directDist / totalSegmentLength
        // Normalize between ~0.35 (tight fist) and ~0.95 (straight finger)
        let normalized = (ratio - 0.35) / (0.95 - 0.35)
        return max(0.0, min(1.0, normalized))
    }
    
    /// Calculates thumb extension ratio
    public static func thumbExtensionRatio(
        wrist: CGPoint,
        cmc: CGPoint,
        mp: CGPoint,
        ip: CGPoint,
        tip: CGPoint
    ) -> CGFloat {
        let directDist = distance(cmc, tip)
        let seg1 = distance(cmc, mp)
        let seg2 = distance(mp, ip)
        let seg3 = distance(ip, tip)
        let total = max(seg1 + seg2 + seg3, 0.001)
        let ratio = directDist / total
        let normalized = (ratio - 0.40) / (0.92 - 0.40)
        return max(0.0, min(1.0, normalized))
    }
    
    /// Calculates angular spread in degrees between two fingertips relative to the palm center
    public static func fingerSpreadAngle(tipA: CGPoint, tipB: CGPoint, palmCenter: CGPoint) -> CGFloat {
        return angle(p1: tipA, vertex: palmCenter, p3: tipB)
    }
    
    /// Computes bounding box enclosing a set of points
    public static func computeBoundingBox(points: [CGPoint], padding: CGFloat = 0.03) -> CGRect {
        guard !points.isEmpty else { return .zero }
        var minX = points[0].x
        var maxX = points[0].x
        var minY = points[0].y
        var maxY = points[0].y
        
        for p in points {
            minX = min(minX, p.x)
            maxX = max(maxX, p.x)
            minY = min(minY, p.y)
            maxY = max(maxY, p.y)
        }
        
        let width = maxX - minX
        let height = maxY - minY
        
        let paddedMinX = max(0.0, minX - padding)
        let paddedMinY = max(0.0, minY - padding)
        let paddedWidth = min(1.0 - paddedMinX, width + padding * 2.0)
        let paddedHeight = min(1.0 - paddedMinY, height + padding * 2.0)
        
        return CGRect(x: paddedMinX, y: paddedMinY, width: paddedWidth, height: paddedHeight)
    }
}
