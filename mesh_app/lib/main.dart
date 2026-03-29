import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/crypto_service.dart';
import 'services/identity_service.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'bridges/mesh_core_bridge.dart';
import 'storage/storage_service.dart';
import 'storage/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Flutter Rust Bridge
  try {
    await initMeshCoreBridge();
  } catch (e) {
    debugPrint('Warning: Rust bridge initialization failed (expected in development): $e');
  }
  
  // Initialize local storage services
  try {
    await StorageService.initialize();
    await SettingsService.initialize();
    debugPrint('Storage services initialized successfully');
  } catch (e) {
    debugPrint('Error initializing storage services: $e');
  }
  
  runApp(const MeshSecureApp());
}

class MeshSecureApp extends StatelessWidget {
  const MeshSecureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CryptoService()),
        ChangeNotifierProvider(create: (_) => IdentityService()),
      ],
      child: MaterialApp(
        title: 'Mesh Secure',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: ThemeMode.system,
        home: const AppStartup(),
      ),
    );
  }
}

class AppStartup extends StatefulWidget {
  const AppStartup({super.key});

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  @override
  void initState() {
    super.initState();
    _checkIdentity();
  }

  Future<void> _checkIdentity() async {
    final identityService = context.read<IdentityService>();
    await identityService.loadIdentity();
    
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final identityService = context.watch<IdentityService>();
    
    if (identityService.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return identityService.hasIdentity
        ? const HomeScreen()
        : const OnboardingScreen();
  }
}
