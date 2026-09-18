import Foundation
import Vision

/// Enumeration of finger types
public enum FingerType: String, CaseIterable, Codable {
    case thumb
    case index
    case middle
    case ring
    case little
    
    public var displayName: String {
        switch self {
        case .thumb: return "Thumb"
        case .index: return "Index"
        case .middle: return "Middle"
        case .ring: return "Ring"
        case .little: return "Pinky"
        }
    }
}

/// Standard 21 anatomical joints definition and bone connectivity
public struct HandSkeleton {
    public static let jointNames: [VNHumanHandPoseObservation.JointName: String] = [
        .wrist: "wrist",
        
        .thumbCMC: "thumb_cmc",
        .thumbMP: "thumb_mcp",
        .thumbIP: "thumb_ip",
        .thumbTip: "thumb_tip",
        
        .indexMCP: "index_mcp",
        .indexPIP: "index_pip",
        .indexDIP: "index_dip",
        .indexTip: "index_tip",
        
        .middleMCP: "middle_mcp",
        .middlePIP: "middle_pip",
        .middleDIP: "middle_dip",
        .middleTip: "middle_tip",
        
        .ringMCP: "ring_mcp",
        .ringPIP: "ring_pip",
        .ringDIP: "ring_dip",
        .ringTip: "ring_tip",
        
        .littleMCP: "little_mcp",
        .littlePIP: "little_pip",
        .littleDIP: "little_dip",
        .littleTip: "little_tip"
    ]
    
    /// Joint display labels
    public static let jointDisplayLabels: [VNHumanHandPoseObservation.JointName: String] = [
        .wrist: "Wrist",
        .thumbCMC: "Th CMC", .thumbMP: "Th MCP", .thumbIP: "Th IP", .thumbTip: "Thumb",
        .indexMCP: "Ix MCP", .indexPIP: "Ix PIP", .indexDIP: "Ix DIP", .indexTip: "Index",
        .middleMCP: "Mid MCP", .middlePIP: "Mid PIP", .middleDIP: "Mid DIP", .middleTip: "Middle",
        .ringMCP: "Ring MCP", .ringPIP: "Ring PIP", .ringDIP: "Ring DIP", .ringTip: "Ring",
        .littleMCP: "Pinky MCP", .littlePIP: "Pinky PIP", .littleDIP: "Pinky DIP", .littleTip: "Pinky"
    ]
    
    /// Skeletal bone segments connecting joint pairs
    public static let boneConnections: [(VNHumanHandPoseObservation.JointName, VNHumanHandPoseObservation.JointName)] = [
        // Thumb chain
        (.wrist, .thumbCMC),
        (.thumbCMC, .thumbMP),
        (.thumbMP, .thumbIP),
        (.thumbIP, .thumbTip),
        
        // Index chain
        (.wrist, .indexMCP),
        (.indexMCP, .indexPIP),
        (.indexPIP, .indexDIP),
        (.indexDIP, .indexTip),
        
        // Middle chain
        (.wrist, .middleMCP),
        (.middleMCP, .middlePIP),
        (.middlePIP, .middleDIP),
        (.middleDIP, .middleTip),
        
        // Ring chain
        (.wrist, .ringMCP),
        (.ringMCP, .ringPIP),
        (.ringPIP, .ringDIP),
        (.ringDIP, .ringTip),
        
        // Little chain
        (.wrist, .littleMCP),
        (.littleMCP, .littlePIP),
        (.littlePIP, .littleDIP),
        (.littleDIP, .littleTip),
        
        // Knuckle arch (MCP bar)
        (.indexMCP, .middleMCP),
        (.middleMCP, .ringMCP),
        (.ringMCP, .littleMCP)
    ]
    
    /// Finger joint chains from base to tip
    public static let fingerJoints: [FingerType: [VNHumanHandPoseObservation.JointName]] = [
        .thumb: [.thumbCMC, .thumbMP, .thumbIP, .thumbTip],
        .index: [.indexMCP, .indexPIP, .indexDIP, .indexTip],
        .middle: [.middleMCP, .middlePIP, .middleDIP, .middleTip],
        .ring: [.ringMCP, .ringPIP, .ringDIP, .ringTip],
        .little: [.littleMCP, .littlePIP, .littleDIP, .littleTip]
    ]
    
    /// Fingertip joints
    public static let fingertipJoints: [VNHumanHandPoseObservation.JointName] = [
        .thumbTip, .indexTip, .middleTip, .ringTip, .littleTip
    ]
    
    /// Knuckle MCP joints
    public static let knuckleJoints: [VNHumanHandPoseObservation.JointName] = [
        .indexMCP, .middleMCP, .ringMCP, .littleMCP
    ]
}
