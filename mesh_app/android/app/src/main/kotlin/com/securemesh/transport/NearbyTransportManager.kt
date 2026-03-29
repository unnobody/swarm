package com.securemesh.transport

import android.content.Context
import android.util.Log
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleObserver
import androidx.lifecycle.OnLifecycleEvent
import com.google.android.gms.nearby.Nearby
import com.google.android.gms.nearby.connection.*
import java.nio.charset.StandardCharsets

/**
 * Android реализация транспорта через Google Nearby Connections API
 * Поддерживает BLE и Wi-Fi Direct автоматически
 */
class NearbyTransportManager(
    private val context: Context,
    private val eventCallback: (Map<String, Any>) -> Unit
) : LifecycleObserver {

    companion object {
        private const val TAG = "NearbyTransport"
        private const val SERVICE_ID = "com.securemesh.mesh" // Уникальный ID сервиса
    }

    private lateinit var connectionsClient: ConnectionsClient
    private val discoveredPeers = mutableMapOf<String, PeerInfo>()
    private val connectedPeers = mutableSetOf<String>()
    
    private var deviceName: String = "SecureMesh Device"
    private var deviceId: String = ""

    data class PeerInfo(
        val endpointId: String,
        val name: String,
        val isAdvertising: Boolean = false,
        val isDiscovering: Boolean = false
    )

    fun initialize(deviceName: String, deviceId: String) {
        this.deviceName = deviceName
        this.deviceId = deviceId
        
        connectionsClient = Nearby.getConnectionsClient(context, 
            ConnectionsClientOptions.Builder().build())
        
        Log.d(TAG, "Initialized Nearby Transport: $deviceName ($deviceId)")
        
        // Автоматически начинаем рекламу и поиск после инициализации
        startAdvertising()
        startDiscovery()
    }

    /**
     * Начать рекламу устройства для других
     */
    fun startAdvertising() {
        val advertisingOptions = AdvertisingOptions.Builder()
            .setStrategy(Strategy.P2P_CLUSTER) // Оптимально для mesh
            .build()

        val connectionLifecycleCallback = object : ConnectionLifecycleCallback() {
            override fun onConnectionInitiated(endpointId: String, info: ConnectionInfo) {
                Log.d(TAG, "Connection initiated with $endpointId by ${info.endpointName}")
                
                // Автоматически принимаем подключение
                connectionsClient.acceptConnection(endpointId, PayloadCallback())
                
                sendEvent(mapOf(
                    "type" to "connectionInitiated",
                    "peerId" to endpointId,
                    "peerName" to info.endpointName
                ))
            }

            override fun onConnectionResult(endpointId: String, result: ConnectionResolution) {
                when (result.status.statusCode) {
                    ConnectionsStatusCodes.RESULT_OK -> {
                        Log.d(TAG, "Connected to $endpointId")
                        connectedPeers.add(endpointId)
                        sendEvent(mapOf(
                            "type" to "connected",
                            "peerId" to endpointId
                        ))
                    }
                    else -> {
                        Log.w(TAG, "Connection failed to $endpointId: ${result.status}")
                        sendEvent(mapOf(
                            "type" to "connectionFailed",
                            "peerId" to endpointId,
                            "error" to result.status.toString()
                        ))
                    }
                }
            }

            override fun onDisconnected(endpointId: String) {
                Log.d(TAG, "Disconnected from $endpointId")
                connectedPeers.remove(endpointId)
                sendEvent(mapOf(
                    "type" to "disconnected",
                    "peerId" to endpointId
                ))
            }
        }

        connectionsClient.startAdvertising(
            deviceName,
            SERVICE_ID,
            connectionLifecycleCallback,
            advertisingOptions
        ).addOnSuccessListener {
            Log.d(TAG, "Advertising started successfully")
        }.addOnFailureListener { e ->
            Log.e(TAG, "Failed to start advertising", e)
            sendEvent(mapOf(
                "type" to "error",
                "action" to "startAdvertising",
                "error" to e.message
            ))
        }
    }

    /**
     * Начать поиск других устройств
     */
    fun startDiscovery() {
        val discoveryOptions = DiscoveryOptions.Builder()
            .setStrategy(Strategy.P2P_CLUSTER)
            .build()

        connectionsClient.startDiscovery(
            SERVICE_ID,
            object : EndpointDiscoveryCallback() {
                override fun onEndpointFound(endpointId: String, info: DiscoveredEndpointInfo) {
                    Log.d(TAG, "Peer discovered: ${info.endpointName} ($endpointId)")
                    
                    val peerInfo = PeerInfo(
                        endpointId = endpointId,
                        name = info.endpointName
                    )
                    discoveredPeers[endpointId] = peerInfo
                    
                    sendEvent(mapOf(
                        "type" to "peerDiscovered",
                        "peerId" to endpointId,
                        "peerName" to info.endpointName
                    ))
                    
                    // Автоматически пытаемся подключиться
                    connectToPeer(endpointId)
                }

                override fun onEndpointLost(endpointId: String) {
                    Log.d(TAG, "Peer lost: $endpointId")
                    discoveredPeers.remove(endpointId)
                    sendEvent(mapOf(
                        "type" to "peerLost",
                        "peerId" to endpointId
                    ))
                }
            },
            discoveryOptions
        ).addOnSuccessListener {
            Log.d(TAG, "Discovery started successfully")
        }.addOnFailureListener { e ->
            Log.e(TAG, "Failed to start discovery", e)
            sendEvent(mapOf(
                "type" to "error",
                "action" to "startDiscovery",
                "error" to e.message
            ))
        }
    }

    /**
     * Подключение к конкретному пиру
     */
    fun connectToPeer(endpointId: String) {
        if (connectedPeers.contains(endpointId)) {
            Log.d(TAG, "Already connected to $endpointId")
            return
        }

        val connectionOptions = ConnectionOptions.Builder()
            .setStrategy(Strategy.P2P_CLUSTER)
            .build()

        connectionsClient.requestConnection(
            deviceName,
            endpointId,
            object : ConnectionLifecycleCallback() {
                override fun onConnectionInitiated(endpointId: String, info: ConnectionInfo) {
                    Log.d(TAG, "Accepting connection from $endpointId")
                    connectionsClient.acceptConnection(endpointId, PayloadCallback())
                }

                override fun onConnectionResult(endpointId: String, result: ConnectionResolution) {
                    if (result.status.statusCode == ConnectionsStatusCodes.RESULT_OK) {
                        connectedPeers.add(endpointId)
                        Log.d(TAG, "Successfully connected to $endpointId")
                        sendEvent(mapOf(
                            "type" to "connected",
                            "peerId" to endpointId
                        ))
                    } else {
                        Log.w(TAG, "Connection request failed: ${result.status}")
                        sendEvent(mapOf(
                            "type" to "connectionFailed",
                            "peerId" to endpointId
                        ))
                    }
                }

                override fun onDisconnected(endpointId: String) {
                    connectedPeers.remove(endpointId)
                    Log.d(TAG, "Disconnected from $endpointId")
                    sendEvent(mapOf(
                        "type" to "disconnected",
                        "peerId" to endpointId
                    ))
                }
            },
            connectionOptions
        )
    }

    /**
     * Отправка данных пиру
     */
    fun sendToPeer(endpointId: String, data: ByteArray): Boolean {
        if (!connectedPeers.contains(endpointId)) {
            Log.w(TAG, "Cannot send to $endpointId - not connected")
            return false
        }

        val payload = Payload.fromBytes(data)
        
        connectionsClient.sendPayload(listOf(endpointId), payload)
            .addOnSuccessListener {
                Log.d(TAG, "Sent ${data.size} bytes to $endpointId")
            }
            .addOnFailureListener { e ->
                Log.e(TAG, "Failed to send to $endpointId", e)
                sendEvent(mapOf(
                    "type" to "sendError",
                    "peerId" to endpointId,
                    "error" to e.message
                ))
            }
        
        return true
    }

    /**
     * Отключение от пира
     */
    fun disconnectFromPeer(endpointId: String) {
        connectionsClient.disconnectFromEndpoint(endpointId)
        connectedPeers.remove(endpointId)
        Log.d(TAG, "Disconnected from $endpointId")
    }

    /**
     * Остановка рекламы
     */
    fun stopAdvertising() {
        connectionsClient.stopAdvertising()
        Log.d(TAG, "Advertising stopped")
    }

    /**
     * Остановка поиска
     */
    fun stopDiscovery() {
        connectionsClient.stopDiscovery()
        Log.d(TAG, "Discovery stopped")
    }

    /**
     * Очистка всех подключений
     */
    fun stopAllConnections() {
        connectionsClient.stopAllEndpoints()
        discoveredPeers.clear()
        connectedPeers.clear()
        Log.d(TAG, "All connections stopped")
    }

    /**
     * Callback для получения входящих данных
     */
    private inner class PayloadCallback : PayloadCallback() {
        override fun onPayloadReceived(endpointId: String, payload: Payload) {
            when (payload.type) {
                Payload.Type.BYTES -> {
                    val data = payload.asBytes()?.toByteArray() ?: return
                    Log.d(TAG, "Received ${data.size} bytes from $endpointId")
                    
                    sendEvent(mapOf(
                        "type" to "messageReceived",
                        "peerId" to endpointId,
                        "data" to data
                    ))
                }
                else -> {
                    Log.w(TAG, "Received unsupported payload type: ${payload.type}")
                }
            }
        }

        override fun onPayloadTransferUpdate(endpointId: String, update: PayloadTransferUpdate) {
            // Можно отслеживать прогресс передачи больших файлов
            if (update.status == PayloadTransferUpdate.Status.SUCCESS) {
                Log.d(TAG, "Payload transfer completed to $endpointId")
            }
        }
    }

    /**
     * Отправка события во Flutter
     */
    private fun sendEvent(event: Map<String, Any>) {
        eventCallback(event)
    }

    /**
     * Получение списка подключенных пиров
     */
    fun getConnectedPeers(): Set<String> = connectedPeers.toSet()

    /**
     * Получение списка обнаруженных пиров
     */
    fun getDiscoveredPeers(): Map<String, PeerInfo> = discoveredPeers.toMap()
}
