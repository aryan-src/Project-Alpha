"""
HandTrackerClient — connects to the HandTracker macOS app's WebSocket
and provides live streaming frame data for building gesture projects.

Usage:
    from hand_tracker import HandTrackerClient

    # Option 1: Generator (blocking loop)
    client = HandTrackerClient()
    for frame in client.stream():
        hand = frame.primary_hand
        if hand:
            print(hand.palm_center)

    # Option 2: Callback
    def on_frame(frame):
        ...
    client.listen(on_frame)
"""
import json
import socket
import struct
import hashlib
import base64
import threading
from typing import Callable, Generator, Optional
from .models import HandFrame


class HandTrackerClient:
    """
    Lightweight WebSocket client for the HandTracker app.
    No external dependencies — uses only stdlib socket for maximum compatibility.
    """

    def __init__(self, host: str = "localhost", port: int = 8765):
        self.host = host
        self.port = port
        self._sock: Optional[socket.socket] = None
        self._connected = False
        self._running = False

    def connect(self) -> None:
        """Open WebSocket connection to HandTracker app."""
        self._sock = socket.create_connection((self.host, self.port), timeout=5)
        self._do_handshake()
        self._connected = True

    def disconnect(self) -> None:
        """Close the WebSocket connection."""
        self._running = False
        self._connected = False
        if self._sock:
            try:
                self._sock.close()
            except Exception:
                pass
            self._sock = None

    def stream(self) -> Generator[HandFrame, None, None]:
        """
        Blocking generator that yields HandFrame objects.
        Call this in a for loop on a dedicated thread.

        Example:
            for frame in client.stream():
                if frame.has_hands:
                    print(frame.primary_hand.palm.facing)
        """
        if not self._connected:
            self.connect()
        self._running = True
        try:
            while self._running:
                msg = self._recv_frame()
                if msg is None:
                    break
                try:
                    data = json.loads(msg)
                    yield HandFrame.from_dict(data)
                except (json.JSONDecodeError, Exception):
                    continue
        finally:
            self.disconnect()

    def listen(self, callback: Callable[[HandFrame], None], daemon: bool = True) -> threading.Thread:
        """
        Launches a background thread calling `callback(frame)` on every frame.
        Returns the thread so you can join() it if needed.

        Example:
            def on_frame(frame):
                if frame.primary_hand:
                    print(frame.primary_hand.finger_extensions)

            client.listen(on_frame)
        """
        def _run():
            for frame in self.stream():
                try:
                    callback(frame)
                except Exception as e:
                    print(f"[HandTracker] Callback error: {e}")

        t = threading.Thread(target=_run, daemon=daemon)
        t.start()
        return t

    # ───────────────────────── WebSocket Protocol (RFC 6455) ────────────────────────
    def _do_handshake(self) -> None:
        key = base64.b64encode(hashlib.sha1(b"hand-tracker-key").digest()).decode()
        request = (
            f"GET / HTTP/1.1\r\n"
            f"Host: {self.host}:{self.port}\r\n"
            f"Upgrade: websocket\r\n"
            f"Connection: Upgrade\r\n"
            f"Sec-WebSocket-Key: {key}\r\n"
            f"Sec-WebSocket-Version: 13\r\n"
            f"\r\n"
        )
        self._sock.sendall(request.encode())
        response = b""
        while b"\r\n\r\n" not in response:
            chunk = self._sock.recv(4096)
            if not chunk:
                raise ConnectionError("WebSocket handshake failed: connection closed")
            response += chunk

    def _recv_frame(self) -> Optional[str]:
        """Read one WebSocket text frame and return its payload as a string."""
        try:
            header = self._recv_bytes(2)
            if not header:
                return None
            b1, b2 = header[0], header[1]
            is_masked = bool(b2 & 0x80)
            payload_len = b2 & 0x7F

            if payload_len == 126:
                ext = self._recv_bytes(2)
                payload_len = struct.unpack(">H", ext)[0]
            elif payload_len == 127:
                ext = self._recv_bytes(8)
                payload_len = struct.unpack(">Q", ext)[0]

            mask = self._recv_bytes(4) if is_masked else b""
            data = bytearray(self._recv_bytes(payload_len))

            if is_masked:
                for i in range(len(data)):
                    data[i] ^= mask[i % 4]

            return data.decode("utf-8", errors="replace")
        except Exception:
            return None

    def _recv_bytes(self, n: int) -> bytes:
        data = b""
        while len(data) < n:
            chunk = self._sock.recv(n - len(data))
            if not chunk:
                raise ConnectionError("Connection closed by server")
            data += chunk
        return data
