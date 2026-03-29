//! Mesh Core Library
//! 
//! Provides cryptographic operations, data synchronization, and message handling
//! for the secure mesh messaging application.

use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};
use sodiumoxide::crypto::box_;
use sodiumoxide::crypto::secretbox;
use std::sync::Mutex;

// Initialize sodiumoxide crypto library
fn init_crypto() {
    sodiumoxide::init().expect("Failed to initialize cryptography");
}

// ============================================================================
// Data Structures
// ============================================================================

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Identity {
    pub public_key: String,
    pub secret_key: String, // Encrypted in production!
    pub created_at: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Message {
    pub id: String,
    pub sender_id: String,
    pub content: String,
    pub timestamp: u64,
    pub encrypted: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EncryptedPayload {
    pub ciphertext: Vec<u8>,
    pub nonce: Vec<u8>,
}

// ============================================================================
// Global State (Thread-safe)
// ============================================================================

lazy_static::lazy_static! {
    static ref CURRENT_IDENTITY: Mutex<Option<Identity>> = Mutex::new(None);
}

// ============================================================================
// Identity Management
// ============================================================================

/// Generate a new identity with cryptographic keypair
#[frb(sync)]
pub fn generate_identity() -> Identity {
    init_crypto();
    
    let (public_key, secret_key) = box_::gen_keypair();
    
    Identity {
        public_key: base64::encode(public_key.as_ref()),
        secret_key: base64::encode(secret_key.as_ref()),
        created_at: std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs(),
    }
}

/// Store identity securely (in production, use Secure Enclave/Keystore)
#[frb(sync)]
pub fn store_identity(identity: Identity) -> bool {
    let mut current = CURRENT_IDENTITY.lock().unwrap();
    *current = Some(identity);
    true
}

/// Get current identity
#[frb(sync)]
pub fn get_current_identity() -> Option<Identity> {
    let current = CURRENT_IDENTITY.lock().unwrap();
    current.clone()
}

// ============================================================================
// Encryption/Decryption
// ============================================================================

/// Encrypt a message for a specific recipient
#[frb(sync)]
pub fn encrypt_message(message_content: String, recipient_public_key: String) -> Result<EncryptedPayload, String> {
    init_crypto();
    
    // Decode recipient public key
    let recipient_pk_bytes = match base64::decode(&recipient_public_key) {
        Ok(bytes) => bytes,
        Err(_) => return Err("Invalid public key".to_string()),
    };
    
    // Get our secret key
    let current = CURRENT_IDENTITY.lock().unwrap();
    let identity = match current.as_ref() {
        Some(id) => id,
        None => return Err("No identity stored".to_string()),
    };
    
    let our_sk_bytes = match base64::decode(&identity.secret_key) {
        Ok(bytes) => bytes,
        Err(_) => return Err("Invalid secret key".to_string()),
    };
    
    // Convert to crypto types
    let recipient_pk = box_::PublicKey::from_slice(&recipient_pk_bytes)
        .map_err(|_| "Invalid recipient public key")?;
    let our_sk = box_::SecretKey::from_slice(&our_sk_bytes)
        .map_err(|_| "Invalid secret key")?;
    
    // Encrypt
    let message_bytes = message_content.as_bytes();
    let (ciphertext, nonce) = box_::seal_precomputed(message_bytes, &recipient_pk, &our_sk);
    
    Ok(EncryptedPayload {
        ciphertext,
        nonce: nonce.as_ref().to_vec(),
    })
}

/// Decrypt a received message
#[frb(sync)]
pub fn decrypt_message(encrypted_payload: EncryptedPayload, sender_public_key: String) -> Result<String, String> {
    init_crypto();
    
    // Decode sender public key
    let sender_pk_bytes = match base64::decode(&sender_public_key) {
        Ok(bytes) => bytes,
        Err(_) => return Err("Invalid sender key".to_string()),
    };
    
    // Get our secret key
    let current = CURRENT_IDENTITY.lock().unwrap();
    let identity = match current.as_ref() {
        Some(id) => id,
        None => return Err("No identity stored".to_string()),
    };
    
    let our_sk_bytes = match base64::decode(&identity.secret_key) {
        Ok(bytes) => bytes,
        Err(_) => return Err("Invalid secret key".to_string()),
    };
    
    // Convert to crypto types
    let sender_pk = box_::PublicKey::from_slice(&sender_pk_bytes)
        .map_err(|_| "Invalid sender public key")?;
    let our_sk = box_::SecretKey::from_slice(&our_sk_bytes)
        .map_err(|_| "Invalid secret key")?;
    
    // Decrypt
    let nonce = box_::Nonce::from_slice(&encrypted_payload.nonce)
        .map_err(|_| "Invalid nonce")?;
    
    match box_::open_precomputed(&encrypted_payload.ciphertext, &nonce, &sender_pk, &our_sk) {
        Ok(plaintext) => {
            String::from_utf8(plaintext)
                .map_err(|_| "Decrypted content is not valid UTF-8".to_string())
        }
        Err(_) => Err("Decryption failed".to_string()),
    }
}

// ============================================================================
// Automerge Sync Operations (Placeholder for future implementation)
// ============================================================================

/// Create a new Automerge document for chat history
#[frb(sync)]
pub fn create_sync_document() -> Vec<u8> {
    let doc = automerge::AutoCommit::new();
    doc.save()
}

/// Apply changes from another device
#[frb(sync)]
pub fn apply_sync_changes(_document: Vec<u8>, _changes: Vec<u8>) -> Result<Vec<u8>, String> {
    // Placeholder - will be implemented with full Automerge integration
    Ok(vec![])
}
