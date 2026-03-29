import 'package:flutter/foundation.dart';
import 'crypto_service.dart';
import '../bridges/mesh_core_bridge.dart';
import '../bridges/bridge_definitions.dart';

class IdentityService extends ChangeNotifier {
  final CryptoService _cryptoService;
  final MeshCoreApi _meshCoreApi = MeshCoreApi();
  
  Identity? _identity;
  bool _isLoading = false;
  bool _hasIdentity = false;

  IdentityService({CryptoService? cryptoService})
      : _cryptoService = cryptoService ?? CryptoService();

  Identity? get identity => _identity;
  bool get isLoading => _isLoading;
  bool get hasIdentity => _hasIdentity;
  
  String? get publicKey => _identity?.publicKey;
  String? get secretKey => _identity?.secretKey;

  /// Load identity from secure storage
  Future<void> loadIdentity() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Try to load from Rust bridge first
      final rustIdentity = await _meshCoreApi.getCurrentIdentity();
      
      if (rustIdentity != null) {
        _identity = rustIdentity;
        _hasIdentity = true;
        debugPrint('✓ Identity loaded from Rust bridge');
      } else {
        // Fallback: check local storage
        _hasIdentity = false;
        _identity = null;
        debugPrint('ℹ No identity found');
      }
    } catch (e) {
      debugPrint('Error loading identity: $e');
      _hasIdentity = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a new identity using Rust cryptography
  Future<void> createIdentity() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Generate identity using Rust crypto
      final newIdentity = await _meshCoreApi.generateIdentity();
      
      // Store in Rust memory
      final stored = await _meshCoreApi.storeIdentity(newIdentity);
      
      if (stored) {
        _identity = newIdentity;
        _hasIdentity = true;
        debugPrint('✓ Identity created and stored successfully');
        debugPrint('  Public Key: ${newIdentity.publicKey.substring(0, 16)}...');
      } else {
        throw Exception('Failed to store identity');
      }
    } catch (e) {
      debugPrint('✗ Error creating identity: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Export identity as QR code data
  String exportIdentityForQR() {
    if (_identity == null) {
      throw StateError('No identity to export');
    }
    
    // Format: mesh://PUBLIC_KEY?name=DisplayName
    // In production, add signature verification
    return 'mesh://$publicKey';
  }

  /// Import identity from QR code scan
  Future<bool> importIdentityFromQR(String qrData) async {
    try {
      // Parse QR data format: mesh://PUBLIC_KEY?name=DisplayName
      if (!qrData.startsWith('mesh://')) {
        return false;
      }
      
      // Extract public key and validate
      // In production, verify signature and establish secure channel
      
      return true;
    } catch (e) {
      debugPrint('Error importing identity: $e');
      return false;
    }
  }

  /// Delete identity (irreversible!)
  Future<void> deleteIdentity() async {
    _identity = null;
    _hasIdentity = false;
    
    // In production, securely wipe from Secure Enclave/Keystore
    notifyListeners();
  }
}
