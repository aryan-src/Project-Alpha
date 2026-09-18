"""
Hand Tracker Python SDK
Connects to the HandTracker macOS app's WebSocket stream and
provides typed frame data for building gesture recognition projects.
"""
from .client import HandTrackerClient
from .models import HandNode, PalmData, TrackedHand, HandFrame, Vector3D

__all__ = ["HandTrackerClient", "HandNode", "PalmData", "TrackedHand", "HandFrame", "Vector3D"]
__version__ = "1.0.0"
