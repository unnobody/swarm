//! Криптографический модуль на основе libsodium
//! 
//! Реализует:
//! - Генерацию ключей (ed25519 для идентификации, x25519 для шифрования)
//! - End-to-end шифрование (XSalsa20-Poly1305)
//! - Подпись сообщений
//! - Secure Enclave / Keystore интеграция

use crate::{DeviceId, Result};
use serde::{Deserialize, Serialize};

/// Пара ключей для идентификации (ed25519)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IdentityKeyPair {
    pub public_key: Vec<u8>,
    pub secret_key: Vec<u8>,
}

/// Пара ключей для шифрования (x25519)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EncryptionKeyPair {
    pub public_key: Vec<u8>,
    pub secret_key: Vec<u8>,
}

/// Зашифрованное сообщение
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EncryptedMessage {
    pub ciphertext: Vec<u8>,
    pub nonce: Vec<u8>,
    pub sender_public_key: Vec<u8>,
}

/// Инициализация криптографической библиотеки
#[frb(sync)]
pub fn init_crypto() -> Result<()> {
    // Инициализация libsodium
    if unsafe { libsodium_sys::sodium_init() } == -1 {
        return Result::err("Failed to initialize libsodium".to_string());
    }
    log::info!("Crypto module initialized");
    Result::ok(())
}

/// Генерация пары ключей идентификации
#[frb(sync)]
pub fn generate_identity_keys() -> Result<IdentityKeyPair> {
    let mut public_key = vec![0u8; 32];
    let mut secret_key = vec![0u8; 64];

    unsafe {
        if libsodium_sys::crypto_sign_ed25519_keypair(
            public_key.as_mut_ptr(),
            secret_key.as_mut_ptr(),
        ) != 0 {
            return Result::err("Failed to generate identity keys".to_string());
        }
    }

    log::debug!("Generated new identity key pair");
    Result::ok(IdentityKeyPair {
        public_key,
        secret_key,
    })
}

/// Генерация пары ключей шифрования
#[frb(sync)]
pub fn generate_encryption_keys() -> Result<EncryptionKeyPair> {
    let mut public_key = vec![0u8; 32];
    let mut secret_key = vec![0u8; 32];

    unsafe {
        libsodium_sys::crypto_box_keypair(
            public_key.as_mut_ptr(),
            secret_key.as_mut_ptr(),
        );
    }

    log::debug!("Generated new encryption key pair");
    Result::ok(EncryptionKeyPair {
        public_key,
        secret_key,
    })
}

/// Шифрование сообщения для получателя
#[frb(sync)]
pub fn encrypt_message(
    message: Vec<u8>,
    recipient_public_key: Vec<u8>,
    sender_secret_key: Vec<u8>,
) -> Result<EncryptedMessage> {
    if recipient_public_key.len() != 32 || sender_secret_key.len() != 32 {
        return Result::err("Invalid key length".to_string());
    }

    let mut ciphertext = vec![0u8; message.len() + libsodium_sys::crypto_box_MACBYTES as usize];
    let mut nonce = vec![0u8; libsodium_sys::crypto_box_NONCEBYTES as usize];

    // Генерация случайного nonce
    unsafe {
        libsodium_sys::randombytes_buf(nonce.as_mut_ptr() as *mut _, nonce.len());
    }

    unsafe {
        if libsodium_sys::crypto_box_easy(
            ciphertext.as_mut_ptr(),
            message.as_ptr(),
            message.len() as u64,
            nonce.as_ptr(),
            recipient_public_key.as_ptr(),
            sender_secret_key.as_ptr(),
        ) != 0 {
            return Result::err("Encryption failed".to_string());
        }
    }

    let sender_public_key = derive_public_from_secret(&sender_secret_key)?;

    log::debug!("Message encrypted successfully");
    Result::ok(EncryptedMessage {
        ciphertext,
        nonce,
        sender_public_key,
    })
}

/// Расшифровка сообщения
#[frb(sync)]
pub fn decrypt_message(
    encrypted: EncryptedMessage,
    recipient_secret_key: Vec<u8>,
) -> Result<Vec<u8>> {
    if recipient_secret_key.len() != 32 {
        return Result::err("Invalid secret key length".to_string());
    }

    let plaintext_len = encrypted.ciphertext.len() - libsodium_sys::crypto_box_MACBYTES as usize;
    let mut plaintext = vec![0u8; plaintext_len];

    unsafe {
        if libsodium_sys::crypto_box_open_easy(
            plaintext.as_mut_ptr(),
            encrypted.ciphertext.as_ptr(),
            encrypted.ciphertext.len() as u64,
            encrypted.nonce.as_ptr(),
            encrypted.sender_public_key.as_ptr(),
            recipient_secret_key.as_ptr(),
        ) != 0 {
            return Result::err("Decryption failed - invalid signature or corrupted data".to_string());
        }
    }

    log::debug!("Message decrypted successfully");
    Result::ok(plaintext)
}

/// Подпись данных
#[frb(sync)]
pub fn sign_data(data: Vec<u8>, secret_key: Vec<u8>) -> Result<Vec<u8>> {
    if secret_key.len() != 64 {
        return Result::err("Invalid identity secret key length".to_string());
    }

    let mut signature = vec![0u8; libsodium_sys::crypto_sign_BYTES as usize];
    let mut signed_len: u64 = 0;

    unsafe {
        if libsodium_sys::crypto_sign_detached(
            signature.as_mut_ptr(),
            &mut signed_len,
            data.as_ptr(),
            data.len() as u64,
            secret_key.as_ptr(),
        ) != 0 {
            return Result::err("Signing failed".to_string());
        }
    }

    log::debug!("Data signed successfully");
    Result::ok(signature)
}

/// Проверка подписи
#[frb(sync)]
pub fn verify_signature(
    data: Vec<u8>,
    signature: Vec<u8>,
    public_key: Vec<u8>,
) -> Result<bool> {
    if signature.len() != libsodium_sys::crypto_sign_BYTES as usize {
        return Result::err("Invalid signature length".to_string());
    }

    if public_key.len() != 32 {
        return Result::err("Invalid public key length".to_string());
    }

    let result = unsafe {
        libsodium_sys::crypto_sign_verify_detached(
            signature.as_ptr(),
            data.as_ptr(),
            data.len() as u64,
            public_key.as_ptr(),
        )
    };

    let is_valid = result == 0;
    log::debug!("Signature verification: {}", if is_valid { "valid" } else { "invalid" });
    Result::ok(is_valid)
}

/// Вывод публичного ключа из секретного (для x25519)
fn derive_public_from_secret(secret_key: &[u8]) -> Result<Vec<u8>> {
    let mut public_key = vec![0u8; 32];
    
    unsafe {
        libsodium_sys::crypto_scalarmult_base(
            public_key.as_mut_ptr(),
            secret_key.as_ptr(),
        );
    }

    Result::ok(public_key)
}

/// Хеширование данных (SHA-256)
#[frb(sync)]
pub fn hash_data(data: Vec<u8>) -> Result<Vec<u8>> {
    let mut hash = vec![0u8; libsodium_sys::crypto_hash_sha256_BYTES as usize];

    unsafe {
        libsodium_sys::crypto_hash_sha256(
            hash.as_mut_ptr(),
            data.as_ptr(),
            data.len() as u64,
        );
    }

    log::debug!("Data hashed successfully");
    Result::ok(hash)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_key_generation() {
        let identity = generate_identity_keys();
        assert!(identity.success);
        let identity = identity.data.unwrap();
        assert_eq!(identity.public_key.len(), 32);
        assert_eq!(identity.secret_key.len(), 64);

        let encryption = generate_encryption_keys();
        assert!(encryption.success);
        let encryption = encryption.data.unwrap();
        assert_eq!(encryption.public_key.len(), 32);
        assert_eq!(encryption.secret_key.len(), 32);
    }

    #[test]
    fn test_encrypt_decrypt() {
        init_crypto().unwrap();
        
        let sender_keys = generate_encryption_keys().data.unwrap();
        let recipient_keys = generate_encryption_keys().data.unwrap();

        let message = b"Hello, Secure Mesh!";
        let encrypted = encrypt_message(
            message.to_vec(),
            recipient_keys.public_key.clone(),
            sender_keys.secret_key.clone(),
        ).data.unwrap();

        let decrypted = decrypt_message(
            encrypted,
            recipient_keys.secret_key.clone(),
        ).data.unwrap();

        assert_eq!(message.to_vec(), decrypted);
    }

    #[test]
    fn test_sign_verify() {
        init_crypto().unwrap();
        
        let identity = generate_identity_keys().data.unwrap();
        let data = b"Test data for signing";

        let signature = sign_data(data.to_vec(), identity.secret_key.clone()).data.unwrap();
        let is_valid = verify_signature(
            data.to_vec(),
            signature.clone(),
            identity.public_key.clone(),
        ).data.unwrap();

        assert!(is_valid);

        // Проверка с неправильными данными
        let wrong_data = b"Wrong data";
        let is_invalid = verify_signature(
            wrong_data.to_vec(),
            signature,
            identity.public_key,
        ).data.unwrap();

        assert!(!is_invalid);
    }
}
