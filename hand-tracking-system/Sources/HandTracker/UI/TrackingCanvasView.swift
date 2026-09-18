import AppKit
import Vision
import CoreGraphics

/// Visual node display themes
public enum NodeTheme: String, CaseIterable {
    case cyberNeon = "Cyber Neon"
    case laserEmerald = "Laser Emerald"
    case electricCyan = "Electric Cyan"
    case rainbowSpectrum = "Rainbow Spectrum"
    case minimalistWhite = "Minimalist White"
}

/// Flexible node visibility modes
public enum NodeDisplayMode: String, CaseIterable {
    case allNodes = "All 22 Nodes"
    case palmAndTips = "Palm & Fingertips"
    case palmOnly = "Palm Center Only"
    case wireframe = "Skeletal Wireframe"
}

/// Node radius sizing options
public enum NodeSize: String, CaseIterable {
    case small = "Compact"
    case normal = "Default"
    case large = "Prominent"
    
    public var multiplier: CGFloat {
        switch self {
        case .small: return 0.75
        case .normal: return 1.0
        case .large: return 1.4
        }
    }
}

/// Custom visualizer canvas that renders the live flexible nodes and skeletal structures
public class TrackingCanvasView: NSView {
    
    // Tracking Data
    public var currentFrame: HandFrame? {
        didSet {
            needsDisplay = true
        }
    }
    
    // Visual Customization Settings
    public var theme: NodeTheme = .cyberNeon { didSet { needsDisplay = true } }
    public var displayMode: NodeDisplayMode = .allNodes { didSet { needsDisplay = true } }
    public var nodeSize: NodeSize = .normal { didSet { needsDisplay = true } }
    public var showLabels: Bool = false { didSet { needsDisplay = true } }
    public var showCoordinates: Bool = false { didSet { needsDisplay = true } }
    public var showBoundingBox: Bool = false { didSet { needsDisplay = true } }
    public var showPalmNormal: Bool = true { didSet { needsDisplay = true } }
    public var dimBackground: Bool = false { didSet { updateBackgroundColor() } }
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
    
    private func updateBackgroundColor() {
        if dimBackground {
            layer?.backgroundColor = NSColor(calibratedWhite: 0.08, alpha: 0.75).cgColor
        } else {
            layer?.backgroundColor = NSColor.clear.cgColor
        }
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        guard let frame = currentFrame, !frame.hands.isEmpty else { return }
        
        let canvasSize = bounds.size
        guard canvasSize.width > 10 && canvasSize.height > 10 else { return }
        
        for hand in frame.hands {
            drawHand(hand, in: context, canvasSize: canvasSize)
        }
    }
    
    private func drawHand(_ hand: TrackedHand, in ctx: CGContext, canvasSize: CGSize) {
        ctx.saveGState()
        
        // 1. Draw Bounding Box (if enabled)
        if showBoundingBox {
            drawBoundingBox(hand.boundingBox, handedness: hand.handedness, in: ctx, canvasSize: canvasSize)
        }
        
        // 2. Draw Skeletal Bone Connections
        if displayMode != .palmOnly {
            drawBoneConnections(hand, in: ctx, canvasSize: canvasSize)
        }
        
        // 3. Draw Palm to Knuckles fan web
        if displayMode == .allNodes || displayMode == .palmOnly {
            drawPalmStructure(hand, in: ctx, canvasSize: canvasSize)
        }
        
        // 4. Draw Palm Normal Vector indicator
        if showPalmNormal {
            drawPalmNormal(hand.palm, in: ctx, canvasSize: canvasSize)
        }
        
        // 5. Draw Flexible Nodes
        drawNodes(hand, in: ctx, canvasSize: canvasSize)
        
        ctx.restoreGState()
    }
    
    // MARK: - Bone Connections
    private func drawBoneConnections(_ hand: TrackedHand, in ctx: CGContext, canvasSize: CGSize) {
        let boneColor = getBoneColor()
        ctx.setStrokeColor(boneColor.cgColor)
        ctx.setLineWidth(3.0 * nodeSize.multiplier)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        
        for (jointA, jointB) in HandSkeleton.boneConnections {
            let idA = HandSkeleton.jointNames[jointA] ?? ""
            let idB = HandSkeleton.jointNames[jointB] ?? ""
            
            // Filter bones in palmAndTips mode
            if displayMode == .palmAndTips {
                let isTipConnection = (HandSkeleton.fingertipJoints.contains(jointA) || HandSkeleton.fingertipJoints.contains(jointB))
                if !isTipConnection { continue }
            }
            
            guard let nodeA = hand.node(idA), let nodeB = hand.node(idB) else { continue }
            guard nodeA.confidence > 0.25 && nodeB.confidence > 0.25 else { continue }
            
            let pA = nodeA.pixelPoint(in: canvasSize)
            let pB = nodeB.pixelPoint(in: canvasSize)
            
            ctx.beginPath()
            ctx.move(to: pA)
            ctx.addLine(to: pB)
            ctx.strokePath()
        }
    }
    
    // MARK: - Palm Structure
    private func drawPalmStructure(_ hand: TrackedHand, in ctx: CGContext, canvasSize: CGSize) {
        let palmPt = hand.palm.center.pixelPoint(in: canvasSize)
        
        // Webbing lines from Palm Center to Knuckles
        ctx.setLineWidth(1.5 * nodeSize.multiplier)
        ctx.setStrokeColor(getPalmWebColor().cgColor)
        
        let knuckleIds = ["index_mcp", "middle_mcp", "ring_mcp", "little_mcp", "wrist"]
        for id in knuckleIds {
            if let node = hand.node(id) {
                let p = node.pixelPoint(in: canvasSize)
                ctx.beginPath()
                ctx.move(to: palmPt)
                ctx.addLine(to: p)
                ctx.strokePath()
            }
        }
    }
    
    // MARK: - Palm Normal Vector
    private func drawPalmNormal(_ palm: PalmData, in ctx: CGContext, canvasSize: CGSize) {
        let origin = palm.center.pixelPoint(in: canvasSize)
        let normalLen: CGFloat = 45.0 * nodeSize.multiplier
        
        // 2D projection of normal vector
        let endX = origin.x + palm.normal.x * normalLen
        let endY = origin.y + palm.normal.y * normalLen
        let endPt = CGPoint(x: endX, y: endY)
        
        // Draw directional arrow
        ctx.setLineWidth(2.5 * nodeSize.multiplier)
        let arrowColor = (palm.normal.z < 0) ? NSColor.systemGreen : NSColor.systemOrange
        ctx.setStrokeColor(arrowColor.cgColor)
        
        ctx.beginPath()
        ctx.move(to: origin)
        ctx.addLine(to: endPt)
        ctx.strokePath()
        
        // Draw normal tip dot
        ctx.setFillColor(arrowColor.cgColor)
        ctx.fillEllipse(in: CGRect(x: endPt.x - 3, y: endPt.y - 3, width: 6, height: 6))
    }
    
    // MARK: - Nodes Rendering
    private func drawNodes(_ hand: TrackedHand, in ctx: CGContext, canvasSize: CGSize) {
        let nodesToDraw = filterNodes(from: hand)
        
        for node in nodesToDraw {
            let pt = node.pixelPoint(in: canvasSize)
            let isPalmCenter = (node.id == "palm_center")
            let isFingertip = node.id.hasSuffix("_tip")
            
            let baseRadius: CGFloat = isPalmCenter ? 10.0 : (isFingertip ? 7.5 : 5.5)
            let radius = baseRadius * nodeSize.multiplier
            
            let nodeColors = getNodeColors(for: node)
            
            // 1. Outer Glow Ring
            ctx.setFillColor(nodeColors.glow.cgColor)
            let glowRadius = radius * 2.0
            ctx.fillEllipse(in: CGRect(x: pt.x - glowRadius, y: pt.y - glowRadius, width: glowRadius * 2, height: glowRadius * 2))
            
            // 2. Node Core Circle
            ctx.setFillColor(nodeColors.core.cgColor)
            ctx.fillEllipse(in: CGRect(x: pt.x - radius, y: pt.y - radius, width: radius * 2, height: radius * 2))
            
            // 3. Node Border Ring
            ctx.setStrokeColor(nodeColors.stroke.cgColor)
            ctx.setLineWidth(2.0)
            ctx.strokeEllipse(in: CGRect(x: pt.x - radius, y: pt.y - radius, width: radius * 2, height: radius * 2))
            
            // 4. Center Dot for Palm Center
            if isPalmCenter {
                ctx.setFillColor(NSColor.white.cgColor)
                ctx.fillEllipse(in: CGRect(x: pt.x - 3, y: pt.y - 3, width: 6, height: 6))
            }
            
            // 5. Labels & Coordinates
            if showLabels || showCoordinates {
                drawNodeAnnotation(node, at: pt, in: ctx)
            }
        }
    }
    
    private func filterNodes(from hand: TrackedHand) -> [HandNode] {
        switch displayMode {
        case .allNodes:
            return Array(hand.nodes.values)
            
        case .palmAndTips:
            return hand.nodes.values.filter {
                $0.id == "palm_center" || $0.id == "wrist" || $0.id.hasSuffix("_tip")
            }
            
        case .palmOnly:
            return hand.nodes.values.filter {
                $0.id == "palm_center" || $0.id == "wrist" || $0.id.hasSuffix("_mcp")
            }
            
        case .wireframe:
            return hand.nodes.values.filter {
                $0.id == "palm_center" || $0.id.hasSuffix("_tip")
            }
        }
    }
    
    private func drawNodeAnnotation(_ node: HandNode, at pt: CGPoint, in ctx: CGContext) {
        var text = ""
        if showLabels && showCoordinates {
            text = "\(node.name) (\(String(format: "%.2f", node.x)), \(String(format: "%.2f", node.y)))"
        } else if showLabels {
            text = node.name
        } else if showCoordinates {
            text = "(\(String(format: "%.2f", node.x)), \(String(format: "%.2f", node.y)))"
        }
        
        guard !text.isEmpty else { return }
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor(calibratedWhite: 0.1, alpha: 0.75)
        ]
        
        let attrString = NSAttributedString(string: " \(text) ", attributes: attributes)
        let strSize = attrString.size()
        let textRect = CGRect(x: pt.x + 10, y: pt.y - strSize.height / 2, width: strSize.width, height: strSize.height)
        
        attrString.draw(in: textRect)
    }
    
    private func drawBoundingBox(_ box: CGRect, handedness: String, in ctx: CGContext, canvasSize: CGSize) {
        let rect = CGRect(
            x: box.origin.x * canvasSize.width,
            y: box.origin.y * canvasSize.height,
            width: box.size.width * canvasSize.width,
            height: box.size.height * canvasSize.height
        )
        
        ctx.setStrokeColor(NSColor(calibratedWhite: 0.7, alpha: 0.45).cgColor)
        ctx.setLineWidth(1.5)
        ctx.setLineDash(phase: 0, lengths: [4, 4])
        ctx.stroke(rect)
        ctx.setLineDash(phase: 0, lengths: [])
        
        // Hand label
        let label = " \(handedness) Hand "
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .bold),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor(calibratedWhite: 0.2, alpha: 0.8)
        ]
        let attrStr = NSAttributedString(string: label, attributes: attrs)
        attrStr.draw(at: CGPoint(x: rect.minX + 4, y: rect.minY + 4))
    }
    
    // MARK: - Color Palettes
    private struct NodeColors {
        let core: NSColor
        let stroke: NSColor
        let glow: NSColor
    }
    
    private func getNodeColors(for node: HandNode) -> NodeColors {
        let isPalmCenter = (node.id == "palm_center")
        let isTip = node.id.hasSuffix("_tip")
        let isKnuckle = node.id.hasSuffix("_mcp")
        
        switch theme {
        case .cyberNeon:
            if isPalmCenter {
                return NodeColors(
                    core: NSColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0), // Gold
                    stroke: NSColor.white,
                    glow: NSColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 0.35)
                )
            } else if isTip {
                return NodeColors(
                    core: NSColor(red: 1.0, green: 0.18, blue: 0.58, alpha: 1.0), // Neon Pink
                    stroke: NSColor.white,
                    glow: NSColor(red: 1.0, green: 0.18, blue: 0.58, alpha: 0.35)
                )
            } else if isKnuckle {
                return NodeColors(
                    core: NSColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 1.0), // Electric Cyan
                    stroke: NSColor.white,
                    glow: NSColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 0.3)
                )
            } else {
                return NodeColors(
                    core: NSColor(red: 0.2, green: 0.75, blue: 1.0, alpha: 0.9),
                    stroke: NSColor(calibratedWhite: 0.9, alpha: 0.8),
                    glow: NSColor(red: 0.2, green: 0.75, blue: 1.0, alpha: 0.2)
                )
            }
            
        case .laserEmerald:
            if isPalmCenter {
                return NodeColors(
                    core: NSColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0),
                    stroke: NSColor.white,
                    glow: NSColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 0.35)
                )
            } else if isTip {
                return NodeColors(
                    core: NSColor(red: 0.0, green: 1.0, blue: 0.45, alpha: 1.0),
                    stroke: NSColor.white,
                    glow: NSColor(red: 0.0, green: 1.0, blue: 0.45, alpha: 0.4)
                )
            } else {
                return NodeColors(
                    core: NSColor(red: 0.1, green: 0.85, blue: 0.35, alpha: 0.9),
                    stroke: NSColor.white,
                    glow: NSColor(red: 0.1, green: 0.85, blue: 0.35, alpha: 0.2)
                )
            }
            
        case .electricCyan:
            if isPalmCenter {
                return NodeColors(
                    core: NSColor.white,
                    stroke: NSColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 1.0),
                    glow: NSColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 0.4)
                )
            } else {
                return NodeColors(
                    core: NSColor(red: 0.0, green: 0.88, blue: 1.0, alpha: 1.0),
                    stroke: NSColor.white,
                    glow: NSColor(red: 0.0, green: 0.88, blue: 1.0, alpha: 0.3)
                )
            }
            
        case .rainbowSpectrum:
            if isPalmCenter {
                return NodeColors(core: NSColor.systemYellow, stroke: NSColor.white, glow: NSColor.systemYellow.withAlphaComponent(0.4))
            } else if node.id.contains("thumb") {
                return NodeColors(core: NSColor.systemRed, stroke: NSColor.white, glow: NSColor.systemRed.withAlphaComponent(0.3))
            } else if node.id.contains("index") {
                return NodeColors(core: NSColor.systemOrange, stroke: NSColor.white, glow: NSColor.systemOrange.withAlphaComponent(0.3))
            } else if node.id.contains("middle") {
                return NodeColors(core: NSColor.systemGreen, stroke: NSColor.white, glow: NSColor.systemGreen.withAlphaComponent(0.3))
            } else if node.id.contains("ring") {
                return NodeColors(core: NSColor.systemTeal, stroke: NSColor.white, glow: NSColor.systemTeal.withAlphaComponent(0.3))
            } else if node.id.contains("little") {
                return NodeColors(core: NSColor.systemPurple, stroke: NSColor.white, glow: NSColor.systemPurple.withAlphaComponent(0.3))
            } else {
                return NodeColors(core: NSColor.white, stroke: NSColor.gray, glow: NSColor.white.withAlphaComponent(0.2))
            }
            
        case .minimalistWhite:
            return NodeColors(
                core: isPalmCenter ? NSColor(calibratedWhite: 1.0, alpha: 1.0) : NSColor(calibratedWhite: 0.9, alpha: 0.9),
                stroke: NSColor.black,
                glow: NSColor(calibratedWhite: 1.0, alpha: 0.25)
            )
        }
    }
    
    private func getBoneColor() -> NSColor {
        switch theme {
        case .cyberNeon:
            return NSColor(red: 0.0, green: 0.9, blue: 1.0, alpha: 0.75)
        case .laserEmerald:
            return NSColor(red: 0.0, green: 0.9, blue: 0.4, alpha: 0.75)
        case .electricCyan:
            return NSColor(red: 0.1, green: 0.7, blue: 1.0, alpha: 0.75)
        case .rainbowSpectrum:
            return NSColor(calibratedWhite: 0.85, alpha: 0.6)
        case .minimalistWhite:
            return NSColor(calibratedWhite: 0.9, alpha: 0.6)
        }
    }
    
    private func getPalmWebColor() -> NSColor {
        switch theme {
        case .cyberNeon:
            return NSColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 0.45)
        default:
            return NSColor(calibratedWhite: 0.7, alpha: 0.35)
        }
    }
}
