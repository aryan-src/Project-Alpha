# 🖐️ Hand & Palm Tracking System

A high-performance, native macOS hand and palm tracking system with **22 flexible visual nodes**, real-time WebSocket streaming, and a Python SDK — designed as a **gesture-ready foundation** for upcoming projects.

> **No gestures are included.** This is a pure tracking and visualization engine. All gesture logic lives in your project.

---

## 🚀 Quick Start

### Build & Run (first time)
```bash
cd /Users/aryan/.gemini/antigravity/scratch/hand-tracking-system
bash build_and_run.sh --run
```

### Run (after first build)
```bash
bash run.sh
# OR double-click: HandTracker.app
```

Grant **Camera access** when prompted. The tracking window will open with live node visualization.

---

## 🗂️ Project Structure

```
hand-tracking-system/
├── Sources/HandTracker/
│   ├── Models/
│   │   ├── HandNode.swift        — Single flexible node data model
│   │   ├── PalmNode.swift        — Palm center, normal vector, orientation angles
│   │   ├── HandSkeleton.swift    — 21-joint hierarchy, bone connections, fingertip defs
│   │   └── HandFrame.swift       — Complete per-frame data (TrackedHand, HandFrame)
│   ├── Kinematics/
│   │   ├── OneEuroFilter.swift   — Adaptive jitter-suppression filter (1€ Filter)
│   │   └── Kinematics.swift      — Math helpers: distance, angle, extension, spread, bbox
│   ├── Core/
│   │   ├── CameraManager.swift   — AVCapture camera session management
│   │   └── VisionTracker.swift   — Apple Vision hand pose detection pipeline
│   ├── UI/
│   │   ├── TrackingCanvasView.swift    — Multi-node visual renderer (themes, modes, glow)
│   │   ├── ControlsOverlayView.swift   — HUD controls + keyboard shortcuts
│   │   └── MainWindowController.swift  — Window orchestrator and delegate hub
│   ├── Stream/
│   │   └── WebSocketBroadcaster.swift  — Live JSON WebSocket server on ws://localhost:8765
│   ├── AppDelegate.swift
│   └── main.swift
├── python/
│   ├── hand_tracker/
│   │   ├── __init__.py           — Public Python SDK package
│   │   ├── client.py             — WebSocket client (no external deps)
│   │   └── models.py             — Typed Python dataclasses mirroring Swift JSON
│   └── examples/
│       ├── template_gesture_listener.py   — Your gesture project starter template
│       └── quicktest.py                   — 5-frame connectivity test
├── Resources/Info.plist
├── build_and_run.sh
├── run.sh
└── Package.swift
```

---

## 🦴 Node Reference — All 22 Flexible Nodes

| Node ID | Name | Type |
|---|---|---|
| `wrist` | Wrist | Anatomical |
| `thumb_cmc` | Thumb CMC | Anatomical |
| `thumb_mcp` | Thumb MCP | Anatomical |
| `thumb_ip` | Thumb IP | Anatomical |
| `thumb_tip` | **Thumb Tip** | Anatomical (Fingertip) |
| `index_mcp` | Index MCP (Knuckle) | Anatomical |
| `index_pip` | Index PIP | Anatomical |
| `index_dip` | Index DIP | Anatomical |
| `index_tip` | **Index Tip** | Anatomical (Fingertip) |
| `middle_mcp` | Middle MCP (Knuckle) | Anatomical |
| `middle_pip` | Middle PIP | Anatomical |
| `middle_dip` | Middle DIP | Anatomical |
| `middle_tip` | **Middle Tip** | Anatomical (Fingertip) |
| `ring_mcp` | Ring MCP (Knuckle) | Anatomical |
| `ring_pip` | Ring PIP | Anatomical |
| `ring_dip` | Ring DIP | Anatomical |
| `ring_tip` | **Ring Tip** | Anatomical (Fingertip) |
| `little_mcp` | Pinky MCP (Knuckle) | Anatomical |
| `little_pip` | Pinky PIP | Anatomical |
| `little_dip` | Pinky DIP | Anatomical |
| `little_tip` | **Pinky Tip** | Anatomical (Fingertip) |
| `palm_center` | **Palm Center** ⭐ | **Virtual (computed)** |

Each node contains:
- `x`, `y` — Normalized `[0.0, 1.0]` (mirrored for natural webcam view: left=left)
- `z` — Relative depth estimate
- `confidence` — Detection confidence `[0.0, 1.0]`
- `vx`, `vy` — Velocity in normalized units/second

---

## 🖐️ Palm Data

Available via `hand.palm` (Swift) or `frame.primary_hand.palm` (Python):

| Field | Description |
|---|---|
| `center` | Geometric palm center node (virtual, computed from anatomy) |
| `normal` | 3D normal vector perpendicular to the palm |
| `roll_degrees` | Palm roll (in-plane rotation) |
| `pitch_degrees` | Palm tilt forward/backward |
| `yaw_degrees` | Palm tilt left/right |
| `facing` | `"Towards Camera"`, `"Away from Camera"`, `"Facing Left"`, `"Facing Right"`, `"Facing Up"`, `"Facing Down"` |
| `radius` | Estimated palm span (wrist to center) in normalized units |

---

## ⌨️ Keyboard Shortcuts (in app)

| Key | Action |
|---|---|
| `T` | Cycle visual theme |
| `M` | Cycle node display mode |
| `L` | Toggle joint name labels |
| `C` | Toggle coordinate overlays |
| `S` | Toggle 1€ jitter smoothing |
| `D` | Toggle dim video background |
| `B` | Toggle bounding boxes |
| `N` | Toggle palm normal vector indicator |
| `+` / `=` | Cycle node sizes (Compact → Default → Prominent) |

---

## 🎨 Visual Themes

| Theme | Description |
|---|---|
| **Cyber Neon** (default) | Cyan bones, pink fingertips, gold palm center |
| **Laser Emerald** | High-contrast green & amber |
| **Electric Cyan** | Monochrome electric blue |
| **Rainbow Spectrum** | Each finger gets its own distinct color |
| **Minimalist White** | Clean white nodes, subtle bones |

---

## 📺 Node Display Modes

| Mode | Nodes Visible |
|---|---|
| **All 22 Nodes** | Every anatomical joint + virtual palm center |
| **Palm & Fingertips** | 5 tips + palm center + wrist |
| **Palm Center Only** | Palm center, wrist, and knuckle bases |
| **Skeletal Wireframe** | Fingertips + palm center only (for gesture projects) |

---

## 📡 WebSocket JSON Stream (for your gesture projects)

The app broadcasts on **`ws://localhost:8765`** every frame.

### Frame Schema
```json
{
  "timestamp": 1726589000.123,
  "frameIndex": 4201,
  "fps": 29.8,
  "hands": [
    {
      "id": 0,
      "handedness": "Right",
      "confidence": 0.99,
      "nodes": {
        "wrist":        { "id": "wrist", "name": "Wrist", "x": 0.52, "y": 0.88, "z": 0.0, "confidence": 0.99, "vx": 0.0, "vy": 0.0, "isVirtual": false },
        "palm_center":  { "id": "palm_center", "name": "Palm Center", "x": 0.50, "y": 0.65, "z": 0.0, "confidence": 0.95, "vx": 0.0, "vy": 0.0, "isVirtual": true },
        "index_tip":    { "id": "index_tip", "name": "Index", "x": 0.48, "y": 0.22, "z": 0.0, "confidence": 0.97, "vx": 0.0, "vy": 0.0, "isVirtual": false },
        "...": "..."
      },
      "palm": {
        "center": { "...": "..." },
        "normal": { "x": 0.0, "y": 0.0, "z": -0.98 },
        "rollDegrees": -12.5,
        "pitchDegrees": 5.0,
        "yawDegrees": 2.3,
        "facing": "Towards Camera",
        "radius": 0.12
      },
      "boundingBox": { "x": 0.32, "y": 0.18, "width": 0.35, "height": 0.72 },
      "fingerExtensions": {
        "thumb": 0.85, "index": 0.91, "middle": 0.88, "ring": 0.12, "little": 0.09
      },
      "fingerSpreads": {
        "thumb_index": 28.5, "index_middle": 12.3, "middle_ring": 8.1, "ring_little": 6.4
      }
    }
  ]
}
```

---

## 🐍 Python SDK Usage

```python
from hand_tracker import HandTrackerClient

client = HandTrackerClient()
client.connect()

for frame in client.stream():
    hand = frame.primary_hand
    if not hand:
        continue

    # All 22 nodes
    palm    = hand.palm_center      # HandNode: .x .y .z .vx .vy .confidence
    wrist   = hand.wrist
    i_tip   = hand.index_tip
    t_tip   = hand.thumb_tip

    # Palm orientation
    facing  = hand.palm.facing      # "Towards Camera", "Away from Camera", etc.
    roll    = hand.palm.roll_degrees

    # Finger extension (0.0=curled, 1.0=straight)
    ext_idx = hand.finger_extensions.get("index", 0.0)

    # Distance between any two nodes
    pinch_dist = hand.distance("thumb_tip", "index_tip")

    # Angle at a vertex joint
    bend_angle = hand.angle("index_mcp", "index_pip", "index_tip")

    # All available node IDs
    all_node_ids = list(hand.nodes.keys())
```

### Gesture Template
Start from the clean template:
```bash
python3 python/examples/template_gesture_listener.py
```

### Connectivity Test
```bash
python3 python/examples/quicktest.py
```

---

## 🛠️ Architecture Notes

- **Vision Framework**: Uses Apple's `VNDetectHumanHandPoseRequest` for hardware-accelerated detection. On Apple Silicon this runs on the Neural Engine at up to 60 FPS.
- **1€ Filter**: The One Euro Filter adaptively smooths node positions — minimal lag during fast movement, maximum stability during holds.
- **Palm Center (Virtual Node)**: Geometrically computed as the weighted centroid of wrist + four knuckle bases (58% towards knuckles). It is stable, smooth, and reliable even with partial occlusion.
- **WebSocket Server**: Uses Apple's `Network.framework` (`NWListener`) — zero dependencies, no third-party libraries required.
- **Python SDK**: Zero external dependencies — only Python stdlib (`socket`, `json`, `threading`, `hashlib`).

---

## 📝 Extending for Your Gesture Projects

1. **Python approach (fastest to prototype):**  
   Edit `python/examples/template_gesture_listener.py` → fill in `detect_gestures()`.

2. **Swift approach (lowest latency):**  
   In `VisionTracker.swift`, the delegate callback `didProcessFrame` gives you every frame directly in Swift — add your gesture state machine there.

3. **Any language via WebSocket:**  
   Connect to `ws://localhost:8765` from Node.js, C++, Unity, browser JS, or anything that speaks WebSocket. Frames are plain JSON.
