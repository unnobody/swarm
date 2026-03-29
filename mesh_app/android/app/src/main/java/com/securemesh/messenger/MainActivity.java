package com.securemesh.messenger;

import android.Manifest;
import android.content.pm.PackageManager;
import android.os.Build;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import com.securemesh.transport.NearbyTransportManager;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * Главная Activity приложения Secure Mesh Messenger
 * Регистрирует MethodChannel и EventChannel для связи Flutter с нативным транспортом
 */
public class MainActivity extends FlutterActivity {
    private static final String TAG = "MainActivity";
    private static final String TRANSPORT_CHANNEL = "secure_mesh/transport";
    private static final String TRANSPORT_EVENTS_CHANNEL = "secure_mesh/transport_events";
    private static final int PERMISSIONS_REQUEST_CODE = 1001;

    private NearbyTransportManager transportManager;
    private MethodChannel methodChannel;
    private EventChannel eventChannel;
    private EventChannel.EventSink eventSink;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        // Инициализация MethodChannel для вызовов из Flutter
        methodChannel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), TRANSPORT_CHANNEL);
        methodChannel.setMethodCallHandler(this::handleMethodCall);

        // Инициализация EventChannel для потоковой передачи событий во Flutter
        eventChannel = new EventChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), TRANSPORT_EVENTS_CHANNEL);
        eventChannel.setStreamHandler(new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object arguments, EventChannel.EventSink events) {
                eventSink = events;
                Log.d(TAG, "Event stream listening started");
            }

            @Override
            public void onCancel(Object arguments) {
                eventSink = null;
                Log.d(TAG, "Event stream listening cancelled");
            }
        });

        // Запрос разрешений
        requestPermissions();
    }

    private void handleMethodCall(MethodCall call, MethodChannel.Result result) {
        switch (call.method) {
            case "initialize": {
                String deviceName = call.argument("deviceName");
                if (deviceName == null) deviceName = "SecureMesh Device";
                
                String deviceId = call.argument("deviceId");
                if (deviceId == null) deviceId = generateDeviceId();
                
                initializeTransport(deviceName, deviceId);
                result.success(true);
                break;
            }
            
            case "startDiscovery":
                if (transportManager != null) transportManager.startDiscovery();
                result.success(true);
                break;
                
            case "stopDiscovery":
                if (transportManager != null) transportManager.stopDiscovery();
                result.success(true);
                break;
                
            case "startAdvertising":
                if (transportManager != null) transportManager.startAdvertising();
                result.success(true);
                break;
                
            case "stopAdvertising":
                if (transportManager != null) transportManager.stopAdvertising();
                result.success(true);
                break;
                
            case "connectToPeer": {
                String peerId = call.argument("peerId");
                if (peerId != null && transportManager != null) {
                    transportManager.connectToPeer(peerId);
                    result.success(true);
                } else {
                    result.error("INVALID_PEER_ID", "Peer ID is required", null);
                }
                break;
            }
            
            case "disconnectFromPeer": {
                String peerId = call.argument("peerId");
                if (peerId != null && transportManager != null) {
                    transportManager.disconnectFromPeer(peerId);
                    result.success(true);
                } else {
                    result.error("INVALID_PEER_ID", "Peer ID is required", null);
                }
                break;
            }
            
            case "sendToPeer": {
                String peerId = call.argument("peerId");
                byte[] data = call.argument("data");
                
                if (peerId != null && data != null && transportManager != null) {
                    boolean success = transportManager.sendToPeer(peerId, data);
                    result.success(success);
                } else {
                    result.error("INVALID_ARGUMENTS", "Peer ID and data are required", null);
                }
                break;
            }
            
            case "getConnectedPeers": {
                if (transportManager != null) {
                    List<String> peers = new ArrayList<>(transportManager.getConnectedPeers());
                    result.success(peers);
                } else {
                    result.success(new ArrayList<String>());
                }
                break;
            }
            
            case "getDiscoveredPeers": {
                if (transportManager != null) {
                    Map<String, NearbyTransportManager.PeerInfo> discovered = transportManager.getDiscoveredPeers();
                    Map<String, String> peers = new HashMap<>();
                    for (Map.Entry<String, NearbyTransportManager.PeerInfo> entry : discovered.entrySet()) {
                        peers.put(entry.getKey(), entry.getValue().getName());
                    }
                    result.success(peers);
                } else {
                    result.success(new HashMap<String, String>());
                }
                break;
            }
            
            case "stopAllConnections":
                if (transportManager != null) transportManager.stopAllConnections();
                result.success(true);
                break;
                
            default:
                result.notImplemented();
        }
    }

    private void initializeTransport(String deviceName, String deviceId) {
        transportManager = new NearbyTransportManager(getApplicationContext(), this::sendEventToFlutter);
        transportManager.initialize(deviceName, deviceId);
        Log.d(TAG, "Transport initialized: " + deviceName + " (" + deviceId + ")");
    }

    @SuppressWarnings("unchecked")
    private void sendEventToFlutter(Map<String, Object> event) {
        // Преобразуем ByteArray в ArrayList<Integer> для передачи во Flutter
        Map<String, Object> flutterEvent = new HashMap<>();
        for (Map.Entry<String, Object> entry : event.entrySet()) {
            Object value = entry.getValue();
            if (value instanceof byte[]) {
                byte[] byteArray = (byte[]) value;
                List<Integer> intList = new ArrayList<>();
                for (byte b : byteArray) {
                    intList.add((int) b & 0xFF);
                }
                flutterEvent.put(entry.getKey(), intList);
            } else {
                flutterEvent.put(entry.getKey(), value);
            }
        }

        runOnUiThread(() -> {
            if (eventSink != null) {
                eventSink.success(flutterEvent);
            }
        });
    }

    private void requestPermissions() {
        List<String> permissions = new ArrayList<>();
        
        // Bluetooth permissions for Android 12+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            permissions.add(Manifest.permission.BLUETOOTH_SCAN);
            permissions.add(Manifest.permission.BLUETOOTH_ADVERTISE);
            permissions.add(Manifest.permission.BLUETOOTH_CONNECT);
        } else {
            permissions.add(Manifest.permission.BLUETOOTH);
            permissions.add(Manifest.permission.BLUETOOTH_ADMIN);
        }
        
        // Location permission is required for BLE scanning on older Android versions
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            permissions.add(Manifest.permission.ACCESS_FINE_LOCATION);
            permissions.add(Manifest.permission.ACCESS_COARSE_LOCATION);
        }
        
        // WiFi permissions for Android 13+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissions.add("android.permission.NEARBY_WIFI_DEVICES");
        }

        List<String> permissionsToRequest = new ArrayList<>();
        for (String permission : permissions) {
            if (ContextCompat.checkSelfPermission(this, permission) != PackageManager.PERMISSION_GRANTED) {
                permissionsToRequest.add(permission);
            }
        }

        if (!permissionsToRequest.isEmpty()) {
            ActivityCompat.requestPermissions(
                this,
                permissionsToRequest.toArray(new String[0]),
                PERMISSIONS_REQUEST_CODE
            );
            Log.d(TAG, "Requested permissions: " + String.join(", ", permissionsToRequest));
        } else {
            Log.d(TAG, "All permissions already granted");
        }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        
        if (requestCode == PERMISSIONS_REQUEST_CODE) {
            boolean allGranted = true;
            for (int result : grantResults) {
                if (result != PackageManager.PERMISSION_GRANTED) {
                    allGranted = false;
                    break;
                }
            }
            
            if (allGranted) {
                Log.d(TAG, "All permissions granted");
            } else {
                Log.w(TAG, "Some permissions denied");
                Map<String, Object> errorEvent = new HashMap<>();
                errorEvent.put("type", "error");
                errorEvent.put("action", "permissions");
                errorEvent.put("error", "Required permissions were denied");
                sendEventToFlutter(errorEvent);
            }
        }
    }

    private String generateDeviceId() {
        // Генерируем уникальный ID устройства
        String androidId = android.provider.Settings.Secure.getString(
            getContentResolver(),
            android.provider.Settings.Secure.ANDROID_ID
        );
        return androidId != null ? androidId : "device_" + System.currentTimeMillis();
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        if (transportManager != null) {
            transportManager.stopAllConnections();
            transportManager = null;
        }
        eventSink = null;
        Log.d(TAG, "MainActivity destroyed, transport cleaned up");
    }
}
