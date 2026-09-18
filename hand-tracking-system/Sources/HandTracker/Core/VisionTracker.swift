import Foundation
import Vision
import CoreMedia
import CoreGraphics
import QuartzCore

public protocol VisionTrackerDelegate: AnyObject {
    func visionTracker(_ tracker: VisionTracker, didProcessFrame frame: HandFrame)
}

public class VisionTracker: NSObject {
    public static let shared = VisionTracker()
    
    public weak var delegate: VisionTrackerDelegate?
    
    /// Maximum number of hands to track simultaneously (1 or 2)
    public var maxHands: Int = 2 {
        didSet {
            handPoseRequest.maximumHandCount = maxHands
        }
    }
    
    /// Whether 1€ jitter smoothing is enabled
    public var smoothingEnabled: Bool = true
    
    // Vision Request
    private let handPoseRequest: VNDetectHumanHandPoseRequest = {
        let req = VNDetectHumanHandPoseRequest()
        req.maximumHandCount = 2
        return req
    }()
    
    // Filters per hand and joint
    private var pointFilters: [Int: [String: PointFilter]] = [:]
    
    // Velocity tracking
    private var lastNodePositions: [Int: [String: (point: CGPoint, time: TimeInterval)]] = [:]
    
    // Frame metrics
    private var frameCounter: Int = 0
    private var lastFrameTime: TimeInterval = 0
    private var fpsHistory: [Double] = []
    public private(set) var currentFPS: Double = 0.0
    
    private let processingQueue = DispatchQueue(label: "com.handtracker.visionQueue", qos: .userInteractive)
    
    public override init() {
        super.init()
    }
    
    public func processSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let currentTime = CACurrentMediaTime()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            do {
                try handler.perform([self.handPoseRequest])
                guard let observations = self.handPoseRequest.results else {
                    self.emitEmptyFrame(timestamp: currentTime)
                    return
                }
                
                self.processObservations(observations, timestamp: currentTime)
            } catch {
                print("Vision Hand Pose Error: \(error)")
                self.emitEmptyFrame(timestamp: currentTime)
            }
        }
    }
    
    private func processObservations(_ observations: [VNHumanHandPoseObservation], timestamp: TimeInterval) {
        updateFPS(timestamp: timestamp)
        frameCounter += 1
        
        var trackedHands: [TrackedHand] = []
        
        for (index, observation) in observations.enumerated() {
            guard let hand = extractHand(from: observation, handIndex: index, timestamp: timestamp) else {
                continue
            }
            trackedHands.append(hand)
        }
        
        let frame = HandFrame(
            timestamp: Date().timeIntervalSince1970,
            frameIndex: frameCounter,
            fps: currentFPS,
            hands: trackedHands
        )
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.visionTracker(self, didProcessFrame: frame)
        }
    }
    
    private func extractHand(from observation: VNHumanHandPoseObservation, handIndex: Int, timestamp: TimeInterval) -> TrackedHand? {
        guard let recognizedPoints = try? observation.recognizedPoints(.all) else {
            return nil
        }
        
        // Prepare filter dictionaries for this hand
        if pointFilters[handIndex] == nil {
            pointFilters[handIndex] = [:]
        }
        if lastNodePositions[handIndex] == nil {
            lastNodePositions[handIndex] = [:]
        }
        
        var nodesDict: [String: HandNode] = [:]
        var rawCGPoints: [VNHumanHandPoseObservation.JointName: CGPoint] = [:]
        var allPointsForBox: [CGPoint] = []
        
        // 1. Extract and smooth all 21 anatomical joints
        for (jointKey, point) in recognizedPoints {
            guard point.confidence > 0.15 else { continue }
            
            // Vision coordinates: (0,0) is bottom-left — same as NSView's default.
            // We only mirror X so the hand appears naturally (left=left) like a mirror.
            let rawX = 1.0 - point.location.x // Mirrored horizontally
            let rawY = point.location.y        // No Y flip: Vision y=0=bottom matches NSView y=0=bottom
            let rawPt = CGPoint(x: rawX, y: rawY)
            rawCGPoints[jointKey] = rawPt
            
            let id = HandSkeleton.jointNames[jointKey] ?? jointKey.rawValue.rawValue
            let displayName = HandSkeleton.jointDisplayLabels[jointKey] ?? id
            
            // Smooth point
            var finalPt = rawPt
            if smoothingEnabled {
                if pointFilters[handIndex]![id] == nil {
                    pointFilters[handIndex]![id] = PointFilter(minCutoff: 1.2, beta: 0.008)
                }
                finalPt = pointFilters[handIndex]![id]!.filter(point: rawPt, timestamp: timestamp)
            }
            
            allPointsForBox.append(finalPt)
            
            // Calculate velocity
            var vx: CGFloat = 0.0
            var vy: CGFloat = 0.0
            if let last = lastNodePositions[handIndex]![id] {
                let dt = CGFloat(max(timestamp - last.time, 0.001))
                vx = (finalPt.x - last.point.x) / dt
                vy = (finalPt.y - last.point.y) / dt
            }
            lastNodePositions[handIndex]![id] = (point: finalPt, time: timestamp)
            
            let node = HandNode(
                id: id,
                name: displayName,
                x: finalPt.x,
                y: finalPt.y,
                z: 0.0,
                confidence: point.confidence,
                vx: vx,
                vy: vy,
                isVirtual: false
            )
            nodesDict[id] = node
        }
        
        // Require at least wrist and knuckles to form a valid hand
        guard let wristPt = rawCGPoints[.wrist],
              let indexMCPPts = rawCGPoints[.indexMCP],
              let littleMCPPts = rawCGPoints[.littleMCP] else {
            return nil
        }
        
        let midMCPPts = rawCGPoints[.middleMCP] ?? indexMCPPts
        let ringMCPPts = rawCGPoints[.ringMCP] ?? littleMCPPts
        
        // 2. Compute Handedness estimation
        // In mirrored view: if thumb is to the left of index when palm faces camera, it's typically a right hand
        let thumbMCPPts = rawCGPoints[.thumbCMC] ?? wristPt
        let isLeft = (thumbMCPPts.x > indexMCPPts.x)
        let handednessStr = isLeft ? "Left" : "Right"
        
        // 3. Compute Palm Center Node
        let palmCenterPt = Kinematics.computePalmCenter(
            wrist: wristPt,
            indexMCP: indexMCPPts,
            middleMCP: midMCPPts,
            ringMCP: ringMCPPts,
            littleMCP: littleMCPPts
        )
        
        var smoothedPalmPt = palmCenterPt
        if smoothingEnabled {
            if pointFilters[handIndex]!["palm_center"] == nil {
                pointFilters[handIndex]!["palm_center"] = PointFilter(minCutoff: 1.0, beta: 0.005)
            }
            smoothedPalmPt = pointFilters[handIndex]!["palm_center"]!.filter(point: palmCenterPt, timestamp: timestamp)
        }
        
        var palmVx: CGFloat = 0.0
        var palmVy: CGFloat = 0.0
        if let last = lastNodePositions[handIndex]!["palm_center"] {
            let dt = CGFloat(max(timestamp - last.time, 0.001))
            palmVx = (smoothedPalmPt.x - last.point.x) / dt
            palmVy = (smoothedPalmPt.y - last.point.y) / dt
        }
        lastNodePositions[handIndex]!["palm_center"] = (point: smoothedPalmPt, time: timestamp)
        
        let palmNode = HandNode(
            id: "palm_center",
            name: "Palm Center",
            x: smoothedPalmPt.x,
            y: smoothedPalmPt.y,
            z: 0.0,
            confidence: 0.95,
            vx: palmVx,
            vy: palmVy,
            isVirtual: true
        )
        nodesDict["palm_center"] = palmNode
        allPointsForBox.append(smoothedPalmPt)
        
        // 4. Compute Palm Normal & Orientation
        let palmOrientation = Kinematics.computePalmNormal(
            wrist: wristPt,
            indexMCP: indexMCPPts,
            littleMCP: littleMCPPts,
            isLeftHand: isLeft
        )
        
        let palmRadius = Kinematics.distance(wristPt, palmCenterPt)
        let palmData = PalmData(
            center: palmNode,
            normal: palmOrientation.normal,
            rollDegrees: palmOrientation.roll,
            pitchDegrees: palmOrientation.pitch,
            yawDegrees: palmOrientation.yaw,
            facing: palmOrientation.facing,
            radius: palmRadius
        )
        
        // 5. Kinematics: Finger Extension Ratios (continuous 0.0 to 1.0)
        var extensions: [String: CGFloat] = [:]
        if let cmc = rawCGPoints[.thumbCMC], let mp = rawCGPoints[.thumbMP],
           let ip = rawCGPoints[.thumbIP], let tip = rawCGPoints[.thumbTip] {
            extensions["thumb"] = Kinematics.thumbExtensionRatio(wrist: wristPt, cmc: cmc, mp: mp, ip: ip, tip: tip)
        }
        if let mcp = rawCGPoints[.indexMCP], let pip = rawCGPoints[.indexPIP],
           let dip = rawCGPoints[.indexDIP], let tip = rawCGPoints[.indexTip] {
            extensions["index"] = Kinematics.fingerExtensionRatio(wrist: wristPt, mcp: mcp, pip: pip, dip: dip, tip: tip)
        }
        if let mcp = rawCGPoints[.middleMCP], let pip = rawCGPoints[.middlePIP],
           let dip = rawCGPoints[.middleDIP], let tip = rawCGPoints[.middleTip] {
            extensions["middle"] = Kinematics.fingerExtensionRatio(wrist: wristPt, mcp: mcp, pip: pip, dip: dip, tip: tip)
        }
        if let mcp = rawCGPoints[.ringMCP], let pip = rawCGPoints[.ringPIP],
           let dip = rawCGPoints[.ringDIP], let tip = rawCGPoints[.ringTip] {
            extensions["ring"] = Kinematics.fingerExtensionRatio(wrist: wristPt, mcp: mcp, pip: pip, dip: dip, tip: tip)
        }
        if let mcp = rawCGPoints[.littleMCP], let pip = rawCGPoints[.littlePIP],
           let dip = rawCGPoints[.littleDIP], let tip = rawCGPoints[.littleTip] {
            extensions["little"] = Kinematics.fingerExtensionRatio(wrist: wristPt, mcp: mcp, pip: pip, dip: dip, tip: tip)
        }
        
        // 6. Kinematics: Finger Spreads (degrees)
        var spreads: [String: CGFloat] = [:]
        let thumbTip = rawCGPoints[.thumbTip]
        let indexTip = rawCGPoints[.indexTip]
        let middleTip = rawCGPoints[.middleTip]
        let ringTip = rawCGPoints[.ringTip]
        let littleTip = rawCGPoints[.littleTip]
        
        if let t = thumbTip, let i = indexTip {
            spreads["thumb_index"] = Kinematics.fingerSpreadAngle(tipA: t, tipB: i, palmCenter: smoothedPalmPt)
        }
        if let i = indexTip, let m = middleTip {
            spreads["index_middle"] = Kinematics.fingerSpreadAngle(tipA: i, tipB: m, palmCenter: smoothedPalmPt)
        }
        if let m = middleTip, let r = ringTip {
            spreads["middle_ring"] = Kinematics.fingerSpreadAngle(tipA: m, tipB: r, palmCenter: smoothedPalmPt)
        }
        if let r = ringTip, let l = littleTip {
            spreads["ring_little"] = Kinematics.fingerSpreadAngle(tipA: r, tipB: l, palmCenter: smoothedPalmPt)
        }
        
        // 7. Bounding Box
        let box = Kinematics.computeBoundingBox(points: allPointsForBox)
        
        return TrackedHand(
            id: handIndex,
            handedness: handednessStr,
            confidence: observation.confidence,
            nodes: nodesDict,
            palm: palmData,
            boundingBox: box,
            fingerExtensions: extensions,
            fingerSpreads: spreads
        )
    }
    
    private func emitEmptyFrame(timestamp: TimeInterval) {
        updateFPS(timestamp: timestamp)
        frameCounter += 1
        let frame = HandFrame(
            timestamp: Date().timeIntervalSince1970,
            frameIndex: frameCounter,
            fps: currentFPS,
            hands: []
        )
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.visionTracker(self, didProcessFrame: frame)
        }
    }
    
    private func updateFPS(timestamp: TimeInterval) {
        if lastFrameTime > 0 {
            let dt = timestamp - lastFrameTime
            if dt > 0.0001 {
                let instantFPS = 1.0 / dt
                fpsHistory.append(instantFPS)
                if fpsHistory.count > 15 {
                    fpsHistory.removeFirst()
                }
                currentFPS = fpsHistory.reduce(0, +) / Double(fpsHistory.count)
            }
        }
        lastFrameTime = timestamp
    }
}
