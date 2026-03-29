import Foundation
import MultipeerConnectivity

/// iOS реализация транспорта через Multipeer Connectivity Framework
/// Поддерживает BLE и Wi-Fi Direct автоматически
class MultipeerTransportManager: NSObject {
    
    private static let SERVICE_TYPE = "secure-mesh"
    private let deviceId: String
    private let deviceName: String
    
    private var session: MCSession?
    private var advertiserAssistant: MCNearbyServiceAdvertiser?
    private var browserViewController: MCBrowserViewController?
    
    private var discoveredPeers: [String: MCPeerID] = [:]
    private var connectedPeers: Set<String> = []
    
    /// Callback для отправки событий во Flutter
    var eventCallback: (([String: Any]) -> Void)?
    
    init(deviceId: String, deviceName: String) {
        self.deviceId = deviceId
        self.deviceName = deviceName
        
        super.init()
        
        setupSession()
    }
    
    private func setupSession() {
        // Создаем PeerID для нашего устройства
        let peerID = MCPeerID(displayName: deviceName)
        
        // Инициализируем сессию
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session?.delegate = self
        
        print("[MultipeerTransport] Initialized session for \(deviceName) (\(deviceId))")
    }
    
    /// Начать рекламу устройства для других
    func startAdvertising() {
        guard session != nil else {
            sendEvent(["type": "error", "action": "startAdvertising", "error": "Session not initialized"])
            return
        }
        
        let serviceType = MultipeerTransportManager.SERVICE_TYPE
        let peerID = session?.myPeerID ?? MCPeerID(displayName: deviceName)
        
        // Создаем сервис для рекламы
        advertiserAssistant = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: ["deviceId": deviceId],
            serviceType: serviceType
        )
        
        advertiserAssistant?.delegate = self
        advertiserAssistant?.startAdvertisingPeer()
        
        print("[MultipeerTransport] Started advertising")
    }
    
    /// Начать поиск других устройств
    func startDiscovery() {
        guard session != nil else {
            sendEvent(["type": "error", "action": "startDiscovery", "error": "Session not initialized"])
            return
        }
        
        let serviceType = MultipeerTransportManager.SERVICE_TYPE
        let peerID = session?.myPeerID ?? MCPeerID(displayName: deviceName)
        
        // Создаем браузер
        let browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser.delegate = self
        
        // Сохраняем браузер как свойство если нужно управление
        // Для простоты используем локальную переменную и сразу начинаем поиск
        browser.startBrowsingForPeers()
        
        print("[MultipeerTransport] Started discovery")
    }
    
    /// Подключение к конкретному пиру
    func connectToPeer(_ peerId: String) {
        guard let peerID = discoveredPeers[peerId] else {
            print("[MultipeerTransport] Peer not found: \(peerId)")
            return
        }
        
        guard !connectedPeers.contains(peerId) else {
            print("[MultipeerTransport] Already connected to \(peerId)")
            return
        }
        
        session?.invite(peerID, withContext: nil)
        print("[MultipeerTransport] Invited peer: \(peerId)")
    }
    
    /// Отправка данных пиру
    func sendToPeer(_ peerId: String, data: Data) -> Bool {
        guard connectedPeers.contains(peerId) else {
            print("[MultipeerTransport] Cannot send to \(peerId) - not connected")
            return false
        }
        
        guard let peerID = discoveredPeers[peerId] ?? connectedPeers.compactMap({ discoveredPeers[$0] }).first(where: { _ in true }) else {
            print("[MultipeerTransport] Peer ID not found for \(peerId)")
            return false
        }
        
        do {
            try session?.send(data, toPeers: [peerID], with: .reliable)
            print("[MultipeerTransport] Sent \(data.count) bytes to \(peerId)")
            return true
        } catch {
            print("[MultipeerTransport] Failed to send to \(peerId): \(error)")
            sendEvent(["type": "sendError", "peerId": peerId, "error": error.localizedDescription])
            return false
        }
    }
    
    /// Отключение от пира
    func disconnectFromPeer(_ peerId: String) {
        guard let peerID = discoveredPeers[peerId] else {
            return
        }
        
        session?.cancelConnectPeer(peerID)
        connectedPeers.remove(peerId)
        print("[MultipeerTransport] Disconnected from \(peerId)")
        
        sendEvent(["type": "disconnected", "peerId": peerId])
    }
    
    /// Остановка рекламы
    func stopAdvertising() {
        advertiserAssistant?.stopAdvertisingPeer()
        advertiserAssistant = nil
        print("[MultipeerTransport] Stopped advertising")
    }
    
    /// Остановка поиска
    func stopDiscovery() {
        // Браузер останавливается автоматически при dealloc
        print("[MultipeerTransport] Stopped discovery")
    }
    
    /// Очистка всех подключений
    func stopAllConnections() {
        session?.disconnect()
        discoveredPeers.removeAll()
        connectedPeers.removeAll()
        print("[MultipeerTransport] All connections stopped")
    }
    
    /// Отправка события во Flutter
    private func sendEvent(_ event: [String: Any]) {
        eventCallback?(event)
    }
    
    /// Получение списка подключенных пиров
    func getConnectedPeers() -> Set<String> {
        return connectedPeers
    }
    
    /// Получение списка обнаруженных пиров
    func getDiscoveredPeers() -> [String: String] {
        return discoveredPeers.mapValues { $0.displayName }
    }
}

// MARK: - MCSessionDelegate
extension MultipeerTransportManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let peerId = peerID.displayName
        
        switch state {
        case .connected:
            print("[MultipeerTransport] Connected to \(peerId)")
            connectedPeers.insert(peerId)
            sendEvent(["type": "connected", "peerId": peerId])
            
        case .connecting:
            print("[MultipeerTransport] Connecting to \(peerId)")
            sendEvent(["type": "connecting", "peerId": peerId])
            
        case .notConnected:
            print("[MultipeerTransport] Not connected to \(peerId)")
            connectedPeers.remove(peerId)
            sendEvent(["type": "disconnected", "peerId": peerId])
            
        @unknown default:
            print("[MultipeerTransport] Unknown state for \(peerId)")
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        let peerId = peerID.displayName
        print("[MultipeerTransport] Received \(data.count) bytes from \(peerId)")
        
        sendEvent([
            "type": "messageReceived",
            "peerId": peerId,
            "data": data
        ])
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        print("[MultipeerTransport] Received stream from \(peerID.displayName)")
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        print("[MultipeerTransport] Started receiving resource: \(resourceName) from \(peerID.displayName)")
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        if let error = error {
            print("[MultipeerTransport] Failed to receive resource \(resourceName): \(error)")
        } else {
            print("[MultipeerTransport] Finished receiving resource: \(resourceName)")
        }
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension MultipeerTransportManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        let peerId = peerID.displayName
        print("[MultipeerTransport] Received invitation from \(peerId)")
        
        // Автоматически принимаем подключение
        discoveredPeers[peerId] = peerID
        sendEvent(["type": "peerDiscovered", "peerId": peerId, "peerName": peerId])
        
        invitationHandler(true, session)
        sendEvent(["type": "connectionInitiated", "peerId": peerId, "peerName": peerId])
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("[MultipeerTransport] Failed to start advertising: \(error)")
        sendEvent(["type": "error", "action": "startAdvertising", "error": error.localizedDescription])
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension MultipeerTransportManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        let peerId = peerID.displayName
        print("[MultipeerTransport] Found peer: \(peerId)")
        
        discoveredPeers[peerId] = peerID
        sendEvent(["type": "peerDiscovered", "peerId": peerId, "peerName": peerId])
        
        // Автоматически пытаемся подключиться
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        let peerId = peerID.displayName
        print("[MultipeerTransport] Lost peer: \(peerId)")
        
        discoveredPeers.removeValue(forKey: peerId)
        sendEvent(["type": "peerLost", "peerId": peerId])
    }
}
