//! Rust Core для Secure Mesh Messenger
//! 
//! Этот модуль предоставляет основную логику приложения:
//! - Криптография (libsodium)
//! - Синхронизация данных (Automerge CRDT)
//! - P2P транспорт (libp2p)

pub mod crypto;
pub mod sync;
pub mod transport;

use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};

/// Результат операции с возможной ошибкой
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Result<T> {
    pub success: bool,
    pub data: Option<T>,
    pub error: Option<String>,
}

impl<T> Result<T> {
    pub fn ok(data: T) -> Self {
        Self {
            success: true,
            data: Some(data),
            error: None,
        }
    }

    pub fn err(error: String) -> Self {
        Self {
            success: false,
            data: None,
            error: Some(error),
        }
    }
}

/// Идентификатор устройства/пользователя
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeviceId(pub String);

/// Идентификатор сообщения
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MessageId(pub String);

/// Статус соединения
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum ConnectionStatus {
    /// Прямое соединение (Internet или BLE рядом)
    Direct,
    /// Mesh-ретрансляция (через других людей)
    MeshRelay,
    /// Ожидание (нет пути)
    Pending,
    /// Нет соединения
    Disconnected,
}

/// Режим работы приложения
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum OperationMode {
    /// Максимальная приватность - ретрансляция чужих сообщений
    MaxPrivacy,
    /// Стандартный режим - только свои сообщения
    Standard,
    /// Экономия энергии - минимальная активность
    PowerSave,
    /// Только интернет - без локальной сети
    InternetOnly,
}

/// Инициализация ядра приложения
#[frb(init)]
pub fn init_app() {
    env_logger::init();
    log::info!("Secure Mesh Core initialized");
}

/// Генерация нового идентификатора устройства
#[frb(sync)]
pub fn generate_device_id() -> DeviceId {
    let uuid = uuid::Uuid::new_v4().to_string();
    DeviceId(uuid)
}

/// Получение информации о версии ядра
#[frb(sync)]
pub fn get_core_version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_generate_device_id() {
        let id = generate_device_id();
        assert!(!id.0.is_empty());
        assert_eq!(id.0.len(), 36); // UUID format
    }

    #[test]
    fn test_result_ok() {
        let result: Result<String> = Result::ok("test".to_string());
        assert!(result.success);
        assert_eq!(result.data, Some("test".to_string()));
        assert!(result.error.is_none());
    }

    #[test]
    fn test_result_err() {
        let result: Result<String> = Result::err("error".to_string());
        assert!(!result.success);
        assert!(result.data.is_none());
        assert_eq!(result.error, Some("error".to_string()));
    }
}
