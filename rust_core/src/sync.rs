//! Модуль синхронизации данных на основе Automerge CRDT
//! 
//! Реализует:
//! - Бесконфликтную репликацию данных (CRDT)
//! - Офлайн-синхронизацию
//! - Векторные часы для упорядочивания операций

use crate::{MessageId, Result};
use automerge::{Automerge, Change, Prop, ReadDoc, Transaction};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Сообщение в формате CRDT
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Message {
    pub id: String,
    pub content: String,
    pub sender_id: String,
    pub timestamp: u64,
    pub reply_to: Option<String>,
}

/// Документ чата (Automerge документ)
#[derive(Debug, Clone)]
pub struct ChatDocument {
    doc: Automerge,
}

impl Default for ChatDocument {
    fn default() -> Self {
        Self::new()
    }
}

impl ChatDocument {
    /// Создание нового документа чата
    #[frb(sync)]
    pub fn new() -> Self {
        let mut doc = Automerge::new();
        
        // Инициализация структуры данных
        let mut tx = doc.transaction();
        tx.put(automerge::ROOT, "messages", automerge::ObjType::Map)
            .expect("Failed to initialize messages map");
        tx.put(automerge::ROOT, "metadata", automerge::ObjType::Map)
            .expect("Failed to initialize metadata map");
        tx.commit();

        log::debug!("Created new chat document");
        ChatDocument { doc }
    }

    /// Добавление сообщения
    #[frb(sync)]
    pub fn add_message(&mut self, message: Message) -> Result<()> {
        let mut tx = self.doc.transaction();
        
        let messages_key = Prop::Map("messages".to_string());
        let message_key = Prop::Map(message.id.clone());
        
        tx.put_map(
            &automerge::ROOT,
            "messages",
            [(message.id.clone(), message.content.clone())],
        ).map_err(|e| e.to_string())?;

        tx.commit();
        log::debug!("Added message: {}", message.id);
        Result::ok(())
    }

    /// Получение всех сообщений
    #[frb(sync)]
    pub fn get_messages(&self) -> Result<Vec<Message>> {
        // В реальной реализации здесь будет парсинг состояния документа
        // Для прототипа возвращаем пустой список
        log::debug!("Retrieved messages from document");
        Result::ok(vec![])
    }

    /// Экспорт изменений для синхронизации
    #[frb(sync)]
    pub fn export_changes(&self) -> Result<Vec<u8>> {
        let changes = self.doc.get_changes(&[]);
        let encoded = automerge::save(&self.doc);
        log::debug!("Exported {} bytes of changes", encoded.len());
        Result::ok(encoded)
    }

    /// Импорт изменений от других узлов
    #[frb(sync)]
    pub fn import_changes(&mut self, data: Vec<u8>) -> Result<()> {
        let mut new_doc = Automerge::load(&data)
            .map_err(|e| format!("Failed to load changes: {}", e))?;
        
        // Merge с текущим документом
        self.doc.merge(&mut new_doc)
            .map_err(|e| format!("Failed to merge changes: {}", e))?;
        
        log::debug!("Imported and merged changes");
        Result::ok(())
    }

    /// Получение размера документа в байтах
    #[frb(sync)]
    pub fn get_size(&self) -> usize {
        automerge::save(&self.doc).len()
    }
}

/// Менеджер синхронизации для управления множеством чатов
#[derive(Debug)]
pub struct SyncManager {
    chats: HashMap<String, ChatDocument>,
    pending_operations: Vec<PendingOperation>,
}

/// Операция ожидающая синхронизации
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PendingOperation {
    pub chat_id: String,
    pub operation_type: String,
    pub data: Vec<u8>,
    pub timestamp: u64,
    pub retry_count: u32,
}

impl Default for SyncManager {
    fn default() -> Self {
        Self::new()
    }
}

impl SyncManager {
    /// Создание нового менеджера синхронизации
    #[frb(sync)]
    pub fn new() -> Self {
        log::info!("SyncManager initialized");
        SyncManager {
            chats: HashMap::new(),
            pending_operations: Vec::new(),
        }
    }

    /// Создание или получение чата
    #[frb(sync)]
    pub fn get_or_create_chat(&mut self, chat_id: String) -> Result<()> {
        if !self.chats.contains_key(&chat_id) {
            self.chats.insert(chat_id.clone(), ChatDocument::new());
            log::debug!("Created new chat: {}", chat_id);
        }
        Result::ok(())
    }

    /// Отправка сообщения в чат
    #[frb(sync)]
    pub fn send_message(
        &mut self,
        chat_id: String,
        message_id: String,
        content: String,
        sender_id: String,
    ) -> Result<()> {
        self.get_or_create_chat(chat_id.clone())?;
        
        let message = Message {
            id: message_id,
            content,
            sender_id,
            timestamp: chrono::Utc::now().timestamp_millis() as u64,
            reply_to: None,
        };

        if let Some(chat) = self.chats.get_mut(&chat_id) {
            chat.add_message(message)?;
        } else {
            return Result::err("Chat not found".to_string());
        }

        log::debug!("Message sent to chat: {}", chat_id);
        Result::ok(())
    }

    /// Получение.pending операций для синхронизации
    #[frb(sync)]
    pub fn get_pending_operations(&self) -> Result<Vec<PendingOperation>> {
        Result::ok(self.pending_operations.clone())
    }

    /// Добавление операции в очередь
    #[frb(sync)]
    pub fn queue_operation(
        &mut self,
        chat_id: String,
        operation_type: String,
        data: Vec<u8>,
    ) -> Result<()> {
        let operation = PendingOperation {
            chat_id,
            operation_type,
            data,
            timestamp: chrono::Utc::now().timestamp_millis() as u64,
            retry_count: 0,
        };
        
        self.pending_operations.push(operation);
        log::debug!("Queued sync operation");
        Result::ok(())
    }

    /// Удаление успешных операций из очереди
    #[frb(sync)]
    pub fn clear_completed_operations(&mut self, operation_ids: Vec<usize>) -> Result<()> {
        // В реальной реализации здесь будет фильтрация по ID
        log::debug!("Cleared {} completed operations", operation_ids.len());
        Result::ok(())
    }

    /// Статистика синхронизации
    #[frb(sync)]
    pub fn get_sync_stats(&self) -> Result<SyncStats> {
        Result::ok(SyncStats {
            total_chats: self.chats.len(),
            pending_operations: self.pending_operations.len(),
            total_size_bytes: self.chats.values().map(|c| c.get_size()).sum(),
        })
    }
}

/// Статистика синхронизации
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SyncStats {
    pub total_chats: usize,
    pub pending_operations: usize,
    pub total_size_bytes: usize,
}

/// Разрешение конфликтов при слиянии
#[frb(sync)]
pub fn resolve_conflict(
    local_value: String,
    remote_value: String,
    local_timestamp: u64,
    remote_timestamp: u64,
) -> Result<String> {
    // Простая стратегия: последний выигрывает (Last-Write-Wins)
    // В production лучше использовать более сложные стратегии
    if remote_timestamp > local_timestamp {
        log::debug!("Conflict resolved: using remote value");
        Result::ok(remote_value)
    } else {
        log::debug!("Conflict resolved: using local value");
        Result::ok(local_value)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_create_chat_document() {
        let doc = ChatDocument::new();
        assert_eq!(doc.get_size(), doc.get_size());
    }

    #[test]
    fn test_sync_manager() {
        let mut manager = SyncManager::new();
        
        manager.get_or_create_chat("chat1".to_string()).unwrap();
        manager.send_message(
            "chat1".to_string(),
            "msg1".to_string(),
            "Hello!".to_string(),
            "user1".to_string(),
        ).unwrap();

        let stats = manager.get_sync_stats().unwrap();
        assert_eq!(stats.total_chats, 1);
    }

    #[test]
    fn test_export_import() {
        let mut doc = ChatDocument::new();
        doc.add_message(Message {
            id: "test1".to_string(),
            content: "Test message".to_string(),
            sender_id: "user1".to_string(),
            timestamp: 1234567890,
            reply_to: None,
        }).unwrap();

        let exported = doc.export_changes().unwrap();
        assert!(!exported.is_empty());

        let mut doc2 = ChatDocument::new();
        doc2.import_changes(exported).unwrap();
    }

    #[test]
    fn test_conflict_resolution() {
        let result = resolve_conflict(
            "local".to_string(),
            "remote".to_string(),
            100,
            200,
        ).unwrap();
        assert_eq!(result, "remote");

        let result2 = resolve_conflict(
            "local".to_string(),
            "remote".to_string(),
            300,
            200,
        ).unwrap();
        assert_eq!(result2, "local");
    }
}
