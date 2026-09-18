"""
╔═══════════════════════════════════════════════════════════════════════════════╗
║         🖐️  Hand Tracker — Gesture Project Starter Template                   ║
║                                                                               ║
║  This is the clean starting point for your upcoming gesture tracking          ║
║  projects. Drop your custom gesture detection logic in the clearly            ║
║  marked sections below.                                                       ║
║                                                                               ║
║  Before running:                                                              ║
║    1. Launch HandTracker.app                                                  ║
║    2. Confirm camera access is granted                                        ║
║    3. Run: python3 template_gesture_listener.py                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
"""
import sys
import os
import time

# Add the python/ directory to path so hand_tracker is importable
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from hand_tracker import HandTrackerClient
from hand_tracker.models import HandFrame, TrackedHand


# ─────────────────────────────────────────────────────────────────────────────
#  Configuration
# ─────────────────────────────────────────────────────────────────────────────
HANDTRACKER_HOST = "localhost"
HANDTRACKER_PORT = 8765

# Print every Nth frame to reduce console spam during development
PRINT_EVERY_N_FRAMES = 5


# ─────────────────────────────────────────────────────────────────────────────
#  YOUR GESTURE LOGIC GOES HERE
#
#  Called once per frame (up to ~30-60 times per second).
#  `frame` contains all tracked hands with 22 flexible nodes each.
# ─────────────────────────────────────────────────────────────────────────────
def detect_gestures(frame: HandFrame) -> None:
    """
    Add your custom gesture detection logic here.
    
    Available data per hand:
    - hand.nodes["wrist"], hand.nodes["palm_center"], hand.nodes["index_tip"], etc.
    - hand.palm.facing  → "Towards Camera" / "Away from Camera" / "Facing Left" / ...
    - hand.palm.roll_degrees, .pitch_degrees, .yaw_degrees
    - hand.finger_extensions["index"]  → 0.0 (curled) to 1.0 (extended)
    - hand.finger_spreads["index_middle"]  → angle in degrees
    - hand.distance("thumb_tip", "index_tip")  → normalized Euclidean distance
    - hand.angle("thumb_tip", "palm_center", "index_tip")  → angle in degrees
    """
    if not frame.has_hands:
        return

    for hand in frame.hands:
        # ── Example: Read raw flexible node positions ──────────────────────
        wrist       = hand.wrist
        palm_center = hand.palm_center
        index_tip   = hand.index_tip
        thumb_tip   = hand.thumb_tip
        middle_tip  = hand.middle_tip
        ring_tip    = hand.ring_tip
        little_tip  = hand.little_tip

        # ── Example: Palm orientation ──────────────────────────────────────
        palm_facing  = hand.palm.facing
        palm_roll    = hand.palm.roll_degrees

        # ── Example: Finger extension ratios (0.0=curl, 1.0=straight) ─────
        ext_thumb  = hand.finger_extensions.get("thumb", 0.0)
        ext_index  = hand.finger_extensions.get("index", 0.0)
        ext_middle = hand.finger_extensions.get("middle", 0.0)
        ext_ring   = hand.finger_extensions.get("ring", 0.0)
        ext_little = hand.finger_extensions.get("little", 0.0)

        # ── Example: Distance between any two nodes ────────────────────────
        thumb_index_dist = hand.distance("thumb_tip", "index_tip")

        # ── Example: Angle at a vertex ─────────────────────────────────────
        # index_bend = hand.angle("index_mcp", "index_pip", "index_tip")

        # ──────────────────────────────────────────────────────────────────
        #  TODO: ADD YOUR GESTURE DETECTION BELOW
        #  Replace these print statements with your logic:
        # ──────────────────────────────────────────────────────────────────
        print(
            f"  [{hand.handedness}] Palm: {palm_facing:20s} | "
            f"Roll: {palm_roll:+6.1f}° | "
            f"Ext [Th:{ext_thumb:.2f} Ix:{ext_index:.2f} Mid:{ext_middle:.2f} Rg:{ext_ring:.2f} Pk:{ext_little:.2f}] | "
            f"Thumb↔Index: {thumb_index_dist:.3f}"
        )


# ─────────────────────────────────────────────────────────────────────────────
#  Frame Handler — called on every received frame
# ─────────────────────────────────────────────────────────────────────────────
frame_count = 0
last_fps_print = time.time()

def on_frame(frame: HandFrame) -> None:
    global frame_count, last_fps_print
    frame_count += 1

    # Print FPS every 2 seconds
    now = time.time()
    if now - last_fps_print >= 2.0:
        print(f"\n📡 HandTracker | FPS: {frame.fps:.1f} | Frame #{frame.frame_index} | Hands: {len(frame.hands)}")
        last_fps_print = now

    # Only call gesture detection every N frames
    if frame_count % PRINT_EVERY_N_FRAMES == 0:
        detect_gestures(frame)


# ─────────────────────────────────────────────────────────────────────────────
#  Main
# ─────────────────────────────────────────────────────────────────────────────
def main():
    print("=" * 70)
    print("  🖐️  Hand Tracker Gesture Listener")
    print(f"  Connecting to ws://{HANDTRACKER_HOST}:{HANDTRACKER_PORT} ...")
    print("  Make sure HandTracker.app is running with camera access.")
    print("  Press Ctrl+C to stop.")
    print("=" * 70)

    client = HandTrackerClient(host=HANDTRACKER_HOST, port=HANDTRACKER_PORT)

    try:
        client.connect()
        print("✅ Connected! Receiving hand tracking data...\n")
        for frame in client.stream():
            on_frame(frame)
    except ConnectionRefusedError:
        print("\n❌ Could not connect. Is HandTracker.app running?")
        print("   Launch it first: open HandTracker.app")
        sys.exit(1)
    except KeyboardInterrupt:
        print("\n\n👋 Stopped by user.")
    finally:
        client.disconnect()


if __name__ == "__main__":
    main()
