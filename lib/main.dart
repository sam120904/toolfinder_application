import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'services/onnx_inference.dart';
import 'services/settings_service.dart';
import 'screens/splash_screen.dart';

// Global cameras list
List<CameraDescription> cameras = [];

// Model Manager Singleton
class ModelManager {
  static final ModelManager _instance = ModelManager._internal();
  static ModelManager get instance => _instance;
  ModelManager._internal();

  final OnnxInference _inference = OnnxInference();
  bool _isPreloaded = false;

  bool get isPreloaded => _isPreloaded;
  OnnxInference getInference() => _inference;

  // Preload model at app startup
  Future<void> preloadModel() async {
    if (_isPreloaded) {
      developer.log('🔄 Model already preloaded');
      return;
    }

    try {
      developer.log('🚀 Starting model preload...');
      await _inference.initialize();
      _isPreloaded = true;
      developer.log('✅ Model preloaded successfully!');
    } catch (e) {
      developer.log('❌ Model preload failed: $e');
      // Don't block app startup - model can load later
    }
  }

  void dispose() {
    _inference.dispose();
    _isPreloaded = false;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // FIXED: COMPLETELY ELIMINATE GRALLOC4 TERMINAL SPAM
  // Override all system logging to suppress gralloc4 and other system messages
  SystemChannels.platform.setMethodCallHandler((call) async {
    // Suppress all platform method calls that cause spam
    return null;
  });
  
  // FIXED: Redirect all Flutter framework logs to suppress gralloc4 spam
  debugPrint = (String? message, {int? wrapWidth}) {
    // Only show our app's important messages with emojis
    if (message != null && 
        (message.contains('🚀') || 
         message.contains('✅') || 
         message.contains('❌') ||
         message.contains('⚠️') ||
         message.contains('📷') ||
         message.contains('⚙️') ||
         message.contains('ToolFinder'))) {
      developer.log(message);
    }
    // COMPLETELY SUPPRESS all other debug output including gralloc4 spam
  };
  
  try {
    // Initialize cameras
    cameras = await availableCameras();
    developer.log('📷 Found ${cameras.length} cameras');
  } catch (e) {
    developer.log('❌ Camera initialization failed: $e');
  }

  // Initialize settings service
  try {
    await SettingsService.instance.initialize();
    developer.log('⚙️ Settings service initialized');
  } catch (e) {
    developer.log('❌ Settings initialization failed: $e');
  }

  // Start model preloading in background
  ModelManager.instance.preloadModel().catchError((error) {
    developer.log('⚠️ Background model loading failed: $error');
  });

  runApp(const ToolFinderApp());
}

class ToolFinderApp extends StatelessWidget {
  const ToolFinderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ToolFinder AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
          surface: const Color(0xFF1A1A2E), // FIXED: Changed from background
        ),
        scaffoldBackgroundColor: const Color(0xFF0B0E1A),
        fontFamily: 'SF Pro Display',
      ),
      home: const SplashScreen(),
    );
  }
}
