"""
Typed data models for the Hand Tracker WebSocket stream.
Mirrors the Swift HandFrame / TrackedHand / HandNode JSON schema exactly.
"""
from __future__ import annotations
from dataclasses import dataclass, field
from typing import Dict, Optional
import math


@dataclass
class Vector3D:
    x: float = 0.0
    y: float = 0.0
    z: float = 0.0

    @property
    def length(self) -> float:
        return math.sqrt(self.x**2 + self.y**2 + self.z**2)

    @classmethod
    def from_dict(cls, d: dict) -> "Vector3D":
        return cls(x=d.get("x", 0.0), y=d.get("y", 0.0), z=d.get("z", 0.0))


@dataclass
class HandNode:
    """Represents a single flexible tracking node (joint or virtual palm node)."""
    id: str = ""
    name: str = ""
    x: float = 0.0          # Normalized 0.0–1.0 (mirrored, left=left)
    y: float = 0.0          # Normalized 0.0–1.0 (top=0, bottom=1)
    z: float = 0.0          # Relative depth estimate
    confidence: float = 1.0
    vx: float = 0.0         # Horizontal velocity (norm/sec)
    vy: float = 0.0         # Vertical velocity (norm/sec)
    is_virtual: bool = False

    @classmethod
    def from_dict(cls, d: dict) -> "HandNode":
        return cls(
            id=d.get("id", ""),
            name=d.get("name", ""),
            x=d.get("x", 0.0),
            y=d.get("y", 0.0),
            z=d.get("z", 0.0),
            confidence=d.get("confidence", 1.0),
            vx=d.get("vx", 0.0),
            vy=d.get("vy", 0.0),
            is_virtual=d.get("isVirtual", False),
        )

    def distance_to(self, other: "HandNode") -> float:
        """Euclidean 3D distance to another node."""
        return math.sqrt((self.x - other.x)**2 + (self.y - other.y)**2 + (self.z - other.z)**2)

    def speed(self) -> float:
        """Magnitude of velocity vector."""
        return math.sqrt(self.vx**2 + self.vy**2)


@dataclass
class PalmData:
    """Palm-specific orientation and geometric data."""
    center: HandNode = field(default_factory=HandNode)
    normal: Vector3D = field(default_factory=Vector3D)
    roll_degrees: float = 0.0    # Roll angle (palm rotation)
    pitch_degrees: float = 0.0   # Pitch angle (tilt forward/back)
    yaw_degrees: float = 0.0     # Yaw angle (tilt left/right)
    facing: str = "Unknown"      # "Towards Camera", "Away from Camera", "Facing Left", etc.
    radius: float = 0.1          # Estimated palm span

    @classmethod
    def from_dict(cls, d: dict) -> "PalmData":
        return cls(
            center=HandNode.from_dict(d.get("center", {})),
            normal=Vector3D.from_dict(d.get("normal", {})),
            roll_degrees=d.get("rollDegrees", 0.0),
            pitch_degrees=d.get("pitchDegrees", 0.0),
            yaw_degrees=d.get("yawDegrees", 0.0),
            facing=d.get("facing", "Unknown"),
            radius=d.get("radius", 0.1),
        )


@dataclass
class TrackedHand:
    """A single detected and tracked hand with all its nodes and kinematics."""
    id: int = 0
    handedness: str = "Unknown"   # "Left" or "Right"
    confidence: float = 1.0
    nodes: Dict[str, HandNode] = field(default_factory=dict)
    palm: PalmData = field(default_factory=PalmData)
    bounding_box: dict = field(default_factory=dict)
    finger_extensions: Dict[str, float] = field(default_factory=dict)  # 0.0=curled, 1.0=extended
    finger_spreads: Dict[str, float] = field(default_factory=dict)      # degrees

    @classmethod
    def from_dict(cls, d: dict) -> "TrackedHand":
        nodes = {k: HandNode.from_dict(v) for k, v in d.get("nodes", {}).items()}
        return cls(
            id=d.get("id", 0),
            handedness=d.get("handedness", "Unknown"),
            confidence=d.get("confidence", 1.0),
            nodes=nodes,
            palm=PalmData.from_dict(d.get("palm", {})),
            bounding_box=d.get("boundingBox", {}),
            finger_extensions=d.get("fingerExtensions", {}),
            finger_spreads=d.get("fingerSpreads", {}),
        )

    def node(self, node_id: str) -> Optional[HandNode]:
        """Convenience getter for a node by its ID."""
        return self.nodes.get(node_id)

    def distance(self, node_a_id: str, node_b_id: str) -> Optional[float]:
        """Euclidean distance between two nodes if both exist."""
        a = self.nodes.get(node_a_id)
        b = self.nodes.get(node_b_id)
        if a and b:
            return a.distance_to(b)
        return None

    def angle(self, node_a_id: str, vertex_id: str, node_b_id: str) -> Optional[float]:
        """
        Angle in degrees at vertex node, formed by a->vertex->b.
        Useful for computing bend/flex angles in your gesture algorithms.
        """
        a = self.nodes.get(node_a_id)
        v = self.nodes.get(vertex_id)
        b = self.nodes.get(node_b_id)
        if not (a and v and b):
            return None
        va = (a.x - v.x, a.y - v.y)
        vb = (b.x - v.x, b.y - v.y)
        dot = va[0]*vb[0] + va[1]*vb[1]
        mag_a = math.sqrt(va[0]**2 + va[1]**2)
        mag_b = math.sqrt(vb[0]**2 + vb[1]**2)
        if mag_a < 1e-6 or mag_b < 1e-6:
            return None
        cos_a = max(-1.0, min(1.0, dot / (mag_a * mag_b)))
        return math.degrees(math.acos(cos_a))

    def is_finger_extended(self, finger: str, threshold: float = 0.6) -> bool:
        """True if the finger extension ratio is above threshold (default 60%)."""
        return self.finger_extensions.get(finger, 0.0) > threshold

    # Convenience properties
    @property
    def palm_center(self) -> Optional[HandNode]:
        return self.nodes.get("palm_center")

    @property
    def wrist(self) -> Optional[HandNode]:
        return self.nodes.get("wrist")

    @property
    def index_tip(self) -> Optional[HandNode]:
        return self.nodes.get("index_tip")

    @property
    def thumb_tip(self) -> Optional[HandNode]:
        return self.nodes.get("thumb_tip")

    @property
    def middle_tip(self) -> Optional[HandNode]:
        return self.nodes.get("middle_tip")

    @property
    def ring_tip(self) -> Optional[HandNode]:
        return self.nodes.get("ring_tip")

    @property
    def little_tip(self) -> Optional[HandNode]:
        return self.nodes.get("little_tip")


@dataclass
class HandFrame:
    """Complete hand tracking frame from the HandTracker app."""
    timestamp: float = 0.0
    frame_index: int = 0
    fps: float = 0.0
    hands: list = field(default_factory=list)

    @classmethod
    def from_dict(cls, d: dict) -> "HandFrame":
        hands = [TrackedHand.from_dict(h) for h in d.get("hands", [])]
        return cls(
            timestamp=d.get("timestamp", 0.0),
            frame_index=d.get("frameIndex", 0),
            fps=d.get("fps", 0.0),
            hands=hands,
        )

    @property
    def has_hands(self) -> bool:
        return len(self.hands) > 0

    @property
    def primary_hand(self) -> Optional[TrackedHand]:
        """Returns the first detected hand (primary)."""
        return self.hands[0] if self.hands else None
