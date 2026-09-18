import AppKit

public protocol ControlsOverlayDelegate: AnyObject {
    func controlsDidToggleTheme()
    func controlsDidToggleMode()
    func controlsDidToggleSize()
    func controlsDidToggleLabels()
    func controlsDidToggleCoordinates()
    func controlsDidToggleSmoothing()
    func controlsDidToggleDimBackground()
}

public class ControlsOverlayView: NSView {
    public weak var delegate: ControlsOverlayDelegate?
    
    // UI Badges
    private let topBar = NSVisualEffectView()
    private let fpsBadge = NSTextField(labelWithString: "0 FPS")
    private let statusBadge = NSTextField(labelWithString: "Tracking Ready")
    private let handsBadge = NSTextField(labelWithString: "0 Hands")
    private let streamBadge = NSTextField(labelWithString: "📡 ws://localhost:8765")
    
    // Action Buttons
    private let themeBtn = NSButton()
    private let modeBtn = NSButton()
    private let sizeBtn = NSButton()
    private let labelsBtn = NSButton()
    private let coordsBtn = NSButton()
    private let smoothBtn = NSButton()
    private let dimBtn = NSButton()
    
    // Bottom shortcut hints
    private let hintLabel = NSTextField(labelWithString: "Hotkeys: [T] Theme  •  [M] Mode  •  [L] Labels  •  [C] Coordinates  •  [S] Smooth  •  [D] Dim BG  •  [+/-] Size")
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        wantsLayer = true
        
        // Top HUD Bar (Translucent glass effect)
        topBar.material = .hudWindow
        topBar.blendingMode = .withinWindow
        topBar.state = .active
        topBar.wantsLayer = true
        topBar.layer?.cornerRadius = 14
        topBar.layer?.masksToBounds = true
        topBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(topBar)
        
        // Setup Badges
        styleBadge(fpsBadge, textColor: .systemGreen)
        styleBadge(statusBadge, textColor: .white)
        styleBadge(handsBadge, textColor: .systemCyan)
        styleBadge(streamBadge, textColor: NSColor(red: 0.9, green: 0.7, blue: 1.0, alpha: 1.0))
        
        // Setup Control Buttons
        setupButton(themeBtn, title: "Theme: Neon", action: #selector(themeClicked))
        setupButton(modeBtn, title: "Mode: All Nodes", action: #selector(modeClicked))
        setupButton(sizeBtn, title: "Size: M", action: #selector(sizeClicked))
        setupButton(labelsBtn, title: "Labels: OFF", action: #selector(labelsClicked))
        setupButton(coordsBtn, title: "Coords: OFF", action: #selector(coordsClicked))
        setupButton(smoothBtn, title: "Smooth: ON", action: #selector(smoothClicked))
        setupButton(dimBtn, title: "Dim BG: OFF", action: #selector(dimClicked))
        
        let stack = NSStackView(views: [
            statusBadge,
            fpsBadge,
            handsBadge,
            streamBadge,
            themeBtn,
            modeBtn,
            sizeBtn,
            labelsBtn,
            coordsBtn,
            smoothBtn,
            dimBtn
        ])
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(stack)
        
        // Bottom Hint Label
        hintLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        hintLabel.textColor = NSColor(calibratedWhite: 0.85, alpha: 0.7)
        hintLabel.alignment = .center
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hintLabel)
        
        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            topBar.centerXAnchor.constraint(equalTo: centerXAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 38),
            
            stack.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -12),
            stack.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            
            hintLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            hintLabel.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])
    }
    
    private func styleBadge(_ label: NSTextField, textColor: NSColor) {
        label.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .bold)
        label.textColor = textColor
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
    }
    
    private func setupButton(_ btn: NSButton, title: String, action: Selector) {
        btn.title = title
        btn.target = self
        btn.action = action
        btn.bezelStyle = .inline
        btn.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        btn.isBordered = true
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 6
    }
    
    // MARK: - Updates
    public func updateMetrics(fps: Double, handCount: Int, clientCount: Int) {
        fpsBadge.stringValue = String(format: "%.0f FPS", fps)
        handsBadge.stringValue = "\(handCount) Hand\(handCount == 1 ? "" : "s")"
        if clientCount > 0 {
            streamBadge.stringValue = "📡 Live (\(clientCount) client\(clientCount == 1 ? "" : "s"))"
        } else {
            streamBadge.stringValue = "📡 ws://localhost:8765"
        }
    }
    
    public func updateThemeButton(name: String) {
        themeBtn.title = "Theme: \(name)"
    }
    
    public func updateModeButton(name: String) {
        modeBtn.title = "Mode: \(name)"
    }
    
    public func updateSizeButton(name: String) {
        sizeBtn.title = "Size: \(name)"
    }
    
    public func updateLabelsButton(enabled: Bool) {
        labelsBtn.title = "Labels: \(enabled ? "ON" : "OFF")"
    }
    
    public func updateCoordsButton(enabled: Bool) {
        coordsBtn.title = "Coords: \(enabled ? "ON" : "OFF")"
    }
    
    public func updateSmoothButton(enabled: Bool) {
        smoothBtn.title = "Smooth: \(enabled ? "ON" : "OFF")"
    }
    
    public func updateDimButton(enabled: Bool) {
        dimBtn.title = "Dim BG: \(enabled ? "ON" : "OFF")"
    }
    
    // MARK: - Actions
    @objc private func themeClicked() { delegate?.controlsDidToggleTheme() }
    @objc private func modeClicked() { delegate?.controlsDidToggleMode() }
    @objc private func sizeClicked() { delegate?.controlsDidToggleSize() }
    @objc private func labelsClicked() { delegate?.controlsDidToggleLabels() }
    @objc private func coordsClicked() { delegate?.controlsDidToggleCoordinates() }
    @objc private func smoothClicked() { delegate?.controlsDidToggleSmoothing() }
    @objc private func dimClicked() { delegate?.controlsDidToggleDimBackground() }
}
