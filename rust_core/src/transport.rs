//! Транспортный модуль на основе libp2p и нативных API
//! 
//! Реализует:
//! - P2P соединение через Internet (libp2p)
//! - Локальное соединение через BLE/Wi-Fi Direct (Platform Channels)
//! - Обнаружение узлов (mDNS, DHT)

use crate::{ConnectionStatus, DeviceId, OperationMode, Result};
use serde::{Deserialize, Serialize};

/// Информация о пире (узле сети)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PeerInfo {
    pub id: String,
    pub public_key: Vec<u8>,
    pub status: ConnectionStatus,
    pub last_seen: u64,
    pub is_relay: bool,
}

/// Тип транспорта
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum TransportType {
    /// Интернет (TCP/WebSocket через libp2p)
    Internet,
    /// Bluetooth Low Energy
    BLE,
    /// Wi-Fi Direct
    WiFiDirect,
    /// Apple Multipeer Connectivity
    Multipeer,
}

/// Событие транспорта
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum TransportEvent {
    /// Обнаружен новый пир
    PeerDiscovered(PeerInfo),
    /// Пир подключился
    PeerConnected(PeerInfo),
    /// Пир отключился
    PeerDisconnected(String),
    /// Получено сообщение
    MessageReceived {
        from: String,
        data: Vec<u8>,
        transport: TransportType,
    },
    /// Ошибка транспорта
    Error(String),
}

/// Менеджер транспорта для управления соединениями
#[derive(Debug)]
pub struct TransportManager {
    peers: Vec<PeerInfo>,
    mode: OperationMode,
    is_running: bool,
}

impl Default for TransportManager {
    fn default() -> Self {
        Self::new()
    }
}

impl TransportManager {
    /// Создание нового менеджера транспорта
    #[frb(sync)]
    pub fn new() -> Self {
        log::info!("TransportManager initialized");
        TransportManager {
            peers: Vec::new(),
            mode: OperationMode::Standard,
            is_running: false,
        }
    }

    /// Запуск транспорта
    #[frb(sync)]
    pub fn start(&mut self, mode: OperationMode) -> Result<()> {
        if self.is_running {
            return Result::err("Transport already running".to_string());
        }

        self.mode = mode;
        self.is_running = true;
        
        log::info!("Transport started in {:?} mode", mode);
        Result::ok(())
    }

    /// Остановка транспорта
    #[frb(sync)]
    pub fn stop(&mut self) -> Result<()> {
        if !self.is_running {
            return Result::err("Transport not running".to_string());
        }

        self.is_running = false;
        
        // Отключение всех пиров
        self.peers.clear();
        
        log::info!("Transport stopped");
        Result::ok(())
    }

    /// Добавление пира в список
    #[frb(sync)]
    pub fn add_peer(&mut self, peer: PeerInfo) -> Result<()> {
        // Проверка на дубликаты
        if self.peers.iter().any(|p| p.id == peer.id) {
            log::debug!("Peer {} already exists, updating", peer.id);
            if let Some(existing) = self.peers.iter_mut().find(|p| p.id == peer.id) {
                *existing = peer;
            }
        } else {
            log::debug!("Added new peer: {}", peer.id);
            self.peers.push(peer);
        }
        
        Result::ok(())
    }

    /// Удаление пира
    #[frb(sync)]
    pub fn remove_peer(&mut self, peer_id: String) -> Result<()> {
        let initial_len = self.peers.len();
        self.peers.retain(|p| p.id != peer_id);
        
        if self.peers.len() < initial_len {
            log::debug!("Removed peer: {}", peer_id);
            Result::ok(())
        } else {
            Result::err(format!("Peer {} not found", peer_id))
        }
    }

    /// Получение списка пиров
    #[frb(sync)]
    pub fn get_peers(&self) -> Result<Vec<PeerInfo>> {
        Result::ok(self.peers.clone())
    }

    /// Получение количества активных пиров
    #[frb(sync)]
    pub fn get_peer_count(&self) -> usize {
        self.peers.len()
    }

    /// Отправка данных пиру
    #[frb(sync)]
    pub fn send_to_peer(&self, peer_id: String, data: Vec<u8>) -> Result<()> {
        if !self.is_running {
            return Result::err("Transport not running".to_string());
        }

        if !self.peers.iter().any(|p| p.id == peer_id) {
            return Result::err(format!("Peer {} not found", peer_id));
        }

        // В реальной реализации здесь будет отправка через Platform Channel
        log::debug!("Sending {} bytes to peer {}", data.len(), peer_id);
        Result::ok(())
    }

    /// Широковещательная рассылка всем пирам
    #[frb(sync)]
    pub fn broadcast(&self, data: Vec<u8>) -> Result<usize> {
        if !self.is_running {
            return Result::err("Transport not running".to_string());
        }

        let mut sent_count = 0;
        for peer in &self.peers {
            match peer.status {
                ConnectionStatus::Direct | ConnectionStatus::MeshRelay => {
                    // В реальной реализации здесь будет отправка
                    sent_count += 1;
                }
                _ => {}
            }
        }

        log::debug!("Broadcast to {} peers", sent_count);
        Result::ok(sent_count)
    }

    /// Обновление статуса пира
    #[frb(sync)]
    pub fn update_peer_status(
        &mut self,
        peer_id: String,
        status: ConnectionStatus,
    ) -> Result<()> {
        if let Some(peer) = self.peers.iter_mut().find(|p| p.id == peer_id) {
            peer.status = status;
            peer.last_seen = chrono::Utc::now().timestamp_millis() as u64;
            log::debug!("Updated peer {} status to {:?}", peer_id, status);
            Result::ok(())
        } else {
            Result::err(format!("Peer {} not found", peer_id))
        }
    }

    /// Проверка доступности пути к получателю
    #[frb(sync)]
    pub fn has_route_to(&self, target_id: String) -> Result<bool> {
        // Простая проверка: есть ли прямой путь или через relay
        let has_direct = self.peers.iter().any(|p| {
            p.status == ConnectionStatus::Direct && p.id == target_id
        });

        let has_relay = self.peers.iter().any(|p| {
            p.status == ConnectionStatus::MeshRelay && p.is_relay
        });

        let reachable = has_direct || has_relay;
        log::debug!(
            "Route to {}: {}",
            target_id,
            if reachable { "found" } else { "not found" }
        );
        
        Result::ok(reachable)
    }

    /// Получение статистики транспорта
    #[frb(sync)]
    pub fn get_transport_stats(&self) -> Result<TransportStats> {
        let direct_count = self
            .peers
            .iter()
            .filter(|p| p.status == ConnectionStatus::Direct)
            .count();
        
        let relay_count = self
            .peers
            .iter()
            .filter(|p| p.status == ConnectionStatus::MeshRelay)
            .count();

        Result::ok(TransportStats {
            total_peers: self.peers.len(),
            direct_connections: direct_count,
            relay_connections: relay_count,
            is_running: self.is_running,
            mode: self.mode,
        })
    }
}

/// Статистика транспорта
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TransportStats {
    pub total_peers: usize,
    pub direct_connections: usize,
    pub relay_connections: usize,
    pub is_running: bool,
    pub mode: OperationMode,
}

/// Конфигурация транспорта
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TransportConfig {
    /// Порт для TCP соединений (Internet)
    pub tcp_port: u16,
    /// Включить mDNS обнаружение
    pub enable_mdns: bool,
    /// Включить DHT
    pub enable_dht: bool,
    /// Таймаут соединения (мс)
    pub connection_timeout_ms: u64,
    /// Максимальное количество одновременных соединений
    pub max_connections: u32,
}

impl Default for TransportConfig {
    fn default() -> Self {
        Self {
            tcp_port: 4001,
            enable_mdns: true,
            enable_dht: true,
            connection_timeout_ms: 30000,
            max_connections: 50,
        }
    }
}

/// Создание конфигурации по умолчанию
#[frb(sync)]
pub fn create_default_transport_config() -> TransportConfig {
    TransportConfig::default()
}

/// Инициализация libp2p (для Internet транспорта)
#[frb(async)]
pub async fn init_libp2p(config: TransportConfig) -> Result<String> {
    // В реальной реализации здесь будет инициализация libp2p
    // Для прототипа просто возвращаем mock ID
    let peer_id = format!("12D3KooW{}", uuid::Uuid::new_v4());
    log::info!("libp2p initialized with peer ID: {}", peer_id);
    Result::ok(peer_id)
}

/// Обнаружение пиров через mDNS (локальная сеть)
#[frb(sync)]
pub fn discover_local_peers() -> Result<Vec<PeerInfo>> {
    // В реальной реализации здесь будет mDNS поиск
    log::debug!("Discovering local peers via mDNS");
    Result::ok(vec![])
}

/// Генерация QR-кода для обмена ключами
#[frb(sync)]
pub fn generate_connection_qr(device_id: String, public_key: Vec<u8>) -> Result<String> {
    use base64::{engine::general_purpose, Engine as _};
    
    // Формирование строки подключения
    let connection_string = format!(
        "securemesh://{}?key={}",
        device_id,
        general_purpose::STANDARD.encode(&public_key)
    );
    
    log::debug!("Generated connection QR data");
    Result::ok(connection_string)
}

/// Парсинг QR-кода для подключения
#[frb(sync)]
pub fn parse_connection_qr(qr_data: String) -> Result<PeerConnectionData> {
    if !qr_data.starts_with("securemesh://") {
        return Result::err("Invalid QR code format".to_string());
    }

    // Парсинг URL
    let url = qr_data.trim_start_matches("securemesh://");
    let parts: Vec<&str> = url.split('?').collect();
    
    if parts.len() != 2 {
        return Result::err("Invalid QR code structure".to_string());
    }

    let device_id = parts[0].to_string();
    let query_parts: Vec<&str> = parts[1].split('=').collect();
    
    if query_parts.len() != 2 || query_parts[0] != "key" {
        return Result::err("Invalid QR code key parameter".to_string());
    }

    use base64::{engine::general_purpose, Engine as _};
    let public_key = general_purpose::STANDARD
        .decode(query_parts[1])
        .map_err(|e| format!("Failed to decode public key: {}", e))?;

    log::debug!("Parsed connection QR data for device: {}", device_id);
    Result::ok(PeerConnectionData {
        device_id,
        public_key,
    })
}

/// Данные для подключения к пиру
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PeerConnectionData {
    pub device_id: String,
    pub public_key: Vec<u8>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_transport_manager() {
        let mut manager = TransportManager::new();
        
        manager.start(OperationMode::Standard).unwrap();
        
        let peer = PeerInfo {
            id: "peer1".to_string(),
            public_key: vec![1, 2, 3],
            status: ConnectionStatus::Direct,
            last_seen: 1234567890,
            is_relay: false,
        };
        
        manager.add_peer(peer).unwrap();
        assert_eq!(manager.get_peer_count(), 1);
        
        let stats = manager.get_transport_stats().unwrap();
        assert_eq!(stats.total_peers, 1);
        assert_eq!(stats.direct_connections, 1);
        
        manager.remove_peer("peer1".to_string()).unwrap();
        assert_eq!(manager.get_peer_count(), 0);
        
        manager.stop().unwrap();
    }

    #[test]
    fn test_has_route() {
        let mut manager = TransportManager::new();
        
        let direct_peer = PeerInfo {
            id: "direct".to_string(),
            public_key: vec![1],
            status: ConnectionStatus::Direct,
            last_seen: 0,
            is_relay: false,
        };
        
        manager.add_peer(direct_peer).unwrap();
        
        assert!(manager.has_route_to("direct".to_string()).unwrap());
        assert!(!manager.has_route_to("unknown".to_string()).unwrap());
    }

    #[test]
    fn test_qr_generation_parsing() {
        let device_id = "device123".to_string();
        let public_key = vec![1, 2, 3, 4, 5];
        
        let qr = generate_connection_qr(device_id.clone(), public_key.clone()).unwrap();
        assert!(qr.starts_with("securemesh://"));
        
        let parsed = parse_connection_qr(qr).unwrap();
        assert_eq!(parsed.device_id, device_id);
        assert_eq!(parsed.public_key, public_key);
    }

    #[test]
    fn test_invalid_qr() {
        let result = parse_connection_qr("invalid".to_string());
        assert!(!result.success);
        
        let result2 = parse_connection_qr("securemesh://incomplete".to_string());
        assert!(!result2.success);
    }
}
