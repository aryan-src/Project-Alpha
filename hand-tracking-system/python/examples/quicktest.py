"""
Quick connectivity test — prints raw JSON from 5 frames then quits.
Run: python3 quicktest.py
"""
import sys, os, json
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from hand_tracker import HandTrackerClient

client = HandTrackerClient()
try:
    client.connect()
    print("Connected! Printing 5 raw frames...\n")
    count = 0
    for frame in client.stream():
        count += 1
        print(f"Frame {count}: {frame.frame_index} | FPS: {frame.fps:.1f} | Hands: {len(frame.hands)}")
        if frame.primary_hand:
            pc = frame.primary_hand.palm_center
            print(f"  Palm center: ({pc.x:.3f}, {pc.y:.3f})")
        if count >= 5:
            break
    print("Done.")
except ConnectionRefusedError:
    print("Could not connect. Is HandTracker.app running?")
finally:
    client.disconnect()
