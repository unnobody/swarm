import UIKit
import Flutter
import MultipeerConnectivity

/// iOS AppDelegate для Secure Mesh Messenger
/// Регистрирует MethodChannel и EventChannel для связи Flutter с нативным транспортом
@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    private static let TAG = "AppDelegate"
    private static let TRANSPORT_CHANNEL = "secure_mesh/transport"
    private static let TRANSPORT_EVENTS_CHANNEL = "secure_mesh/transport_events"
    
    private var transportManager: MultipeerTransportManager?
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Получаем корневой view controller
        guard let controller = window?.rootViewController as? FlutterViewController else {
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }
        
        // Инициализация MethodChannel для вызовов из Flutter
        methodChannel = FlutterMethodChannel(
            name: AppDelegate.TRANSPORT_CHANNEL,
            binaryMessenger: controller.binaryMessenger
        )
        methodChannel?.setMethodCallHandler(handleMethodCall)
        
        // Инициализация EventChannel для потоковой передачи событий во Flutter
        eventChannel = FlutterEventChannel(
            name: AppDelegate.TRANSPORT_EVENTS_CHANNEL,
            binaryMessenger: controller.binaryMessenger
        )
        eventChannel?.setStreamHandler(StreamHandlerImpl { [weak self] events in
            self?.eventSink = events
            print("[\(AppDelegate.TAG)] Event stream listening started")
        }, onCancel: { [weak self] in
            self?.eventSink = nil
            print("[\(AppDelegate.TAG)] Event stream listening cancelled")
        })
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            guard let args = call.arguments as? [String: Any],
                  let deviceName = args["deviceName"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "deviceName is required", details: nil))
                return
            }
            
            let deviceId = args["deviceId"] as? String ?? generateDeviceId()
            initializeTransport(deviceName: deviceName, deviceId: deviceId)
            result(true)
            
        case "startDiscovery":
            transportManager?.startDiscovery()
            result(true)
            
        case "stopDiscovery":
            transportManager?.stopDiscovery()
            result(true)
            
        case "startAdvertising":
            transportManager?.startAdvertising()
            result(true)
            
        case "stopAdvertising":
            transportManager?.stopAdvertising()
            result(true)
            
        case "connectToPeer":
            guard let args = call.arguments as? [String: Any],
                  let peerId = args["peerId"] as? String else {
                result(FlutterError(code: "INVALID_PEER_ID", message: "Peer ID is required", details: nil))
                return
            }
            transportManager?.connectToPeer(peerId)
            result(true)
            
        case "disconnectFromPeer":
            guard let args = call.arguments as? [String: Any],
                  let peerId = args["peerId"] as? String else {
                result(FlutterError(code: "INVALID_PEER_ID", message: "Peer ID is required", details: nil))
                return
            }
            transportManager?.disconnectFromPeer(peerId)
            result(true)
            
        case "sendToPeer":
            guard let args = call.arguments as? [String: Any],
                  let peerId = args["peerId"] as? String,
                  let data = args["data"] as? [Int] else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Peer ID and data are required", details: nil))
                return
            }
            
            // Конвертируем [Int] в Data
            let byteData = Data(data.map { UInt8($0 & 0xFF) })
            let success = transportManager?.sendToPeer(peerId, data: byteData) ?? false
            result(success)
            
        case "getConnectedPeers":
            let peers = transportManager?.getConnectedPeers().map { Array($0) } ?? []
            result(peers)
            
        case "getDiscoveredPeers":
            let peers = transportManager?.getDiscoveredPeers() ?? [:]
            result(peers)
            
        case "stopAllConnections":
            transportManager?.stopAllConnections()
            result(true)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func initializeTransport(deviceName: String, deviceId: String) {
        transportManager = MultipeerTransportManager(deviceId: deviceId, deviceName: deviceName)
        
        // Устанавливаем callback для получения событий
        transportManager?.eventCallback = { [weak self] event in
            self?.sendEventToFlutter(event)
        }
        
        print("[\(AppDelegate.TAG)] Transport initialized: \(deviceName) (\(deviceId))")
    }
    
    private func sendEventToFlutter(_ event: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let eventSink = self.eventSink else { return }
            
            // Преобразуем Data в [Int] для передачи во Flutter
            var flutterEvent: [String: Any] = [:]
            for (key, value) in event {
                if let data = value as? Data {
                    flutterEvent[key] = data.map { Int($0) }
                } else {
                    flutterEvent[key] = value
                }
            }
            
            eventSink(flutterEvent)
        }
    }
    
    private func generateDeviceId() -> String {
        // Генерируем уникальный ID устройства на основе identifierForVendor
        if let vendorId = UIDevice.current.identifierForVendor?.uuidString {
            return vendorId
        }
        return "device_\(Date().timeIntervalSince1970)"
    }
    
    deinit {
        transportManager?.stopAllConnections()
        transportManager = nil
        print("[\(AppDelegate.TAG)] AppDelegate deinitialized, transport cleaned up")
    }
}

/// Helper class для обработки StreamHandler
class StreamHandlerImpl: NSObject, FlutterStreamHandler {
    private let onListen: (FlutterEventSink?) -> Void
    private let onCancel: () -> Void
    
    init(onListen: @escaping (FlutterEventSink?) -> Void, onCancel: @escaping () -> Void) {
        self.onListen = onListen
        self.onCancel = onCancel
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        onListen(events)
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        onCancel()
        return nil
    }
}
