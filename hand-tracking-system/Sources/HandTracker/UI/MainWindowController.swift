import AppKit
import AVFoundation

public class MainWindowController: NSWindowController, CameraManagerDelegate, VisionTrackerDelegate, ControlsOverlayDelegate {
    public static let shared = MainWindowController()
    
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let canvasView = TrackingCanvasView()
    private let controlsOverlay = ControlsOverlayView()
    
    private var isDimmed: Bool = false
    
    public init() {
        let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 100, y: 100, width: 1024, height: 640)
        let initialWidth: CGFloat = 1000
        let initialHeight: CGFloat = 650
        let initialX = screenRect.midX - initialWidth / 2
        let initialY = screenRect.midY - initialHeight / 2
        
        let window = NSWindow(
            contentRect: NSRect(x: initialX, y: initialY, width: initialWidth, height: initialHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "🖐️ Hand & Palm Tracker • Visual Multi-Node Engine"
        window.minSize = NSSize(width: 640, height: 440)
        window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor.black
        
        super.init(window: window)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    private func setupViews() {
        guard let window = self.window, let contentView = window.contentView else { return }
        contentView.wantsLayer = true
        
        // Setup Video Preview Layer
        setupPreviewLayer(in: contentView)
        
        // Setup Tracking Canvas
        canvasView.frame = contentView.bounds
        canvasView.autoresizingMask = [.width, .height]
        contentView.addSubview(canvasView)
        
        // Setup Controls Overlay
        controlsOverlay.frame = contentView.bounds
        controlsOverlay.autoresizingMask = [.width, .height]
        controlsOverlay.delegate = self
        contentView.addSubview(controlsOverlay)
        
        // Register delegates
        CameraManager.shared.delegate = self
        VisionTracker.shared.delegate = self
        
        // Key event monitor
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyDown(event) == true {
                return nil
            }
            return event
        }
    }
    
    private func setupPreviewLayer(in view: NSView) {
        let session = CameraManager.shared.captureSession
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds

        // Mirror preview for natural webcam view (left = left)
        if let connection = layer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }

        view.layer?.addSublayer(layer)
        self.previewLayer = layer
    }
    
    public override func windowDidLoad() {
        super.windowDidLoad()
    }
    
    // MARK: - CameraManagerDelegate
    public func cameraManager(_ manager: CameraManager, didOutput sampleBuffer: CMSampleBuffer) {
        // Feed vision tracker
        VisionTracker.shared.processSampleBuffer(sampleBuffer)
    }
    
    // MARK: - VisionTrackerDelegate
    public func visionTracker(_ tracker: VisionTracker, didProcessFrame frame: HandFrame) {
        // Update Canvas view
        canvasView.currentFrame = frame
        
        // Update HUD metrics
        controlsOverlay.updateMetrics(
            fps: frame.fps,
            handCount: frame.hands.count,
            clientCount: WebSocketBroadcaster.shared.clientCount
        )
        
        // Broadcast over WebSocket for upcoming gesture projects
        WebSocketBroadcaster.shared.broadcast(frame: frame)
    }
    
    // MARK: - ControlsOverlayDelegate
    public func controlsDidToggleTheme() {
        let allThemes = NodeTheme.allCases
        guard let idx = allThemes.firstIndex(of: canvasView.theme) else { return }
        let nextIdx = (idx + 1) % allThemes.count
        canvasView.theme = allThemes[nextIdx]
        controlsOverlay.updateThemeButton(name: canvasView.theme.rawValue)
    }
    
    public func controlsDidToggleMode() {
        let allModes = NodeDisplayMode.allCases
        guard let idx = allModes.firstIndex(of: canvasView.displayMode) else { return }
        let nextIdx = (idx + 1) % allModes.count
        canvasView.displayMode = allModes[nextIdx]
        controlsOverlay.updateModeButton(name: canvasView.displayMode.rawValue)
    }
    
    public func controlsDidToggleSize() {
        let allSizes = NodeSize.allCases
        guard let idx = allSizes.firstIndex(of: canvasView.nodeSize) else { return }
        let nextIdx = (idx + 1) % allSizes.count
        canvasView.nodeSize = allSizes[nextIdx]
        controlsOverlay.updateSizeButton(name: canvasView.nodeSize.rawValue)
    }
    
    public func controlsDidToggleLabels() {
        canvasView.showLabels.toggle()
        controlsOverlay.updateLabelsButton(enabled: canvasView.showLabels)
    }
    
    public func controlsDidToggleCoordinates() {
        canvasView.showCoordinates.toggle()
        controlsOverlay.updateCoordsButton(enabled: canvasView.showCoordinates)
    }
    
    public func controlsDidToggleSmoothing() {
        VisionTracker.shared.smoothingEnabled.toggle()
        controlsOverlay.updateSmoothButton(enabled: VisionTracker.shared.smoothingEnabled)
    }
    
    public func controlsDidToggleDimBackground() {
        isDimmed.toggle()
        canvasView.dimBackground = isDimmed
        controlsOverlay.updateDimButton(enabled: isDimmed)
    }
    
    // MARK: - Keyboard Shortcuts
    private func handleKeyDown(_ event: NSEvent) -> Bool {
        guard let chars = event.charactersIgnoringModifiers?.lowercased() else { return false }
        switch chars {
        case "t":
            controlsDidToggleTheme()
            return true
        case "m":
            controlsDidToggleMode()
            return true
        case "l":
            controlsDidToggleLabels()
            return true
        case "c":
            controlsDidToggleCoordinates()
            return true
        case "s":
            controlsDidToggleSmoothing()
            return true
        case "d":
            controlsDidToggleDimBackground()
            return true
        case "b":
            canvasView.showBoundingBox.toggle()
            return true
        case "n":
            canvasView.showPalmNormal.toggle()
            return true
        case "+", "=":
            controlsDidToggleSize()
            return true
        default:
            return false
        }
    }
}
