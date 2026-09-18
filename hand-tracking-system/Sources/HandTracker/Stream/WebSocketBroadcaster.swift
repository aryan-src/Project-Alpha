import Foundation
import Network

/// Lightweight zero-dependency WebSocket broadcaster using Apple Network.framework
public class WebSocketBroadcaster: NSObject {
    public static let shared = WebSocketBroadcaster()
    
    public let port: UInt16
    private var listener: NWListener?
    private var connectedClients: [NWConnection] = []
    private let queue = DispatchQueue(label: "com.handtracker.websocket", qos: .default)
    
    @Published public private(set) var clientCount: Int = 0
    @Published public private(set) var isRunning: Bool = false
    
    public init(port: UInt16 = 8765) {
        self.port = port
        super.init()
    }
    
    public func start() {
        queue.async { [weak self] in
            guard let self = self else { return }
            do {
                let parameters = NWParameters.tcp
                let wsOptions = NWProtocolWebSocket.Options()
                wsOptions.autoReplyPing = true
                parameters.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)
                
                guard let nwPort = NWEndpoint.Port(rawValue: self.port) else { return }
                self.listener = try NWListener(using: parameters, on: nwPort)
                
                self.listener?.newConnectionHandler = { [weak self] connection in
                    self?.handleNewConnection(connection)
                }
                
                self.listener?.stateUpdateHandler = { [weak self] state in
                    switch state {
                    case .ready:
                        DispatchQueue.main.async {
                            self?.isRunning = true
                        }
                        print("📡 Hand Tracker WebSocket live on ws://localhost:\(self?.port ?? 8765)")
                    case .failed(let error):
                        print("❌ WebSocket listener failed: \(error)")
                        DispatchQueue.main.async {
                            self?.isRunning = false
                        }
                    default:
                        break
                    }
                }
                
                self.listener?.start(queue: self.queue)
            } catch {
                print("Failed to start WebSocket server: \(error)")
            }
        }
    }
    
    public func stop() {
        queue.async { [weak self] in
            guard let self = self else { return }
            for client in self.connectedClients {
                client.cancel()
            }
            self.connectedClients.removeAll()
            self.listener?.cancel()
            self.listener = nil
            DispatchQueue.main.async {
                self.clientCount = 0
                self.isRunning = false
            }
        }
    }
    
    private func handleNewConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self = self, let conn = connection else { return }
            switch state {
            case .ready:
                self.queue.async {
                    self.connectedClients.append(conn)
                    DispatchQueue.main.async {
                        self.clientCount = self.connectedClients.count
                    }
                }
                self.receiveMessage(on: conn)
            case .failed, .cancelled:
                self.queue.async {
                    if let idx = self.connectedClients.firstIndex(where: { $0 === conn }) {
                        self.connectedClients.remove(at: idx)
                        DispatchQueue.main.async {
                            self.clientCount = self.connectedClients.count
                        }
                    }
                }
            default:
                break
            }
        }
        connection.start(queue: queue)
    }
    
    private func receiveMessage(on connection: NWConnection) {
        connection.receiveMessage { [weak self, weak connection] (_, context, _, error) in
            guard let self = self, let conn = connection, error == nil else { return }
            // Keep connection open and listening
            self.receiveMessage(on: conn)
        }
    }
    
    /// Broadcasts hand tracking frame JSON string to all connected WebSocket clients
    public func broadcast(frame: HandFrame) {
        guard !connectedClients.isEmpty else { return }
        guard let jsonString = frame.toJSON(), let data = jsonString.data(using: .utf8) else { return }
        
        queue.async { [weak self] in
            guard let self = self else { return }
            let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
            let context = NWConnection.ContentContext(identifier: "textContext", metadata: [metadata])
            
            for client in self.connectedClients {
                client.send(content: data, contentContext: context, isComplete: true, completion: .idempotent)
            }
        }
    }
}
