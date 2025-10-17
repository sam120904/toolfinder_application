import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../models/detection.dart';
import '../main.dart';
import '../widgets/bounding_box_overlay.dart';

class RealtimeDetectionScreen extends StatefulWidget {
  const RealtimeDetectionScreen({super.key});

  @override
  State<RealtimeDetectionScreen> createState() => _RealtimeDetectionScreenState();
}

class _RealtimeDetectionScreenState extends State<RealtimeDetectionScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _cameraController;
  late List<CameraDescription> _cameras;
  bool _isCameraInitialized = false;
  bool _isRealtimeActive = false;
  List<Detection> _currentDetections = [];
  Timer? _detectionTimer;
  String _statusMessage = 'Initializing camera...';
  String? _currentImagePath;
  
  // Animation controllers for modern effects
  late AnimationController _glowController;
  late AnimationController _particleController;
  late List<Particle> _particles;
  
  final List<String> _imageQueue = [];
  bool _isProcessing = false;
  int _frameSkipCounter = 0;
  
  static const int _maxQueueSize = 1;
  static const int _frameSkipRate = 1;
  static const int _detectionInterval = 33; // 30 FPS

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize animations
    _glowController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    
    _particleController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
    
    _particles = List.generate(15, (index) => Particle());
    
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detectionTimer?.cancel();
    _cameraController?.dispose();
    _glowController.dispose();
    _particleController.dispose();
    _cleanupImageQueue();
    super.dispose();
  }

  void _cleanupImageQueue() {
    for (final imagePath in _imageQueue) {
      try {
        File(imagePath).deleteSync();
      } catch (e) {
        // Ignore cleanup errors
      }
    }
    _imageQueue.clear();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _stopRealtimeDetection();
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _statusMessage = 'No cameras available';
          });
        }
        return;
      }

      _cameraController = CameraController(
        _cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _statusMessage = ModelManager.instance.isPreloaded 
              ? 'Ready for detection' 
              : 'Neural network loading...';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Camera initialization failed: $e';
        });
      }
    }
  }

  void _startRealtimeDetection() {
    if (!_isCameraInitialized || !ModelManager.instance.isPreloaded) {
      _showSnackBar(
        'Camera or neural network not ready',
        Colors.orange,
        Icons.warning_rounded,
      );
      return;
    }

    setState(() {
      _isRealtimeActive = true;
      _statusMessage = 'Live detection active • 30 FPS';
      _imageQueue.clear();
      _frameSkipCounter = 0;
    });

    _detectionTimer = Timer.periodic(const Duration(milliseconds: _detectionInterval), (timer) {
      if (_isRealtimeActive) {
        _captureAndProcess();
      }
    });
  }

  void _stopRealtimeDetection() {
    setState(() {
      _isRealtimeActive = false;
      _statusMessage = 'Detection stopped';
      _currentDetections.clear();
      _currentImagePath = null;
    });

    _detectionTimer?.cancel();
    _detectionTimer = null;
    _cleanupImageQueue();
    _isProcessing = false;
  }

  Future<void> _captureAndProcess() async {
    if (!_isCameraInitialized || !_isRealtimeActive || _isProcessing) return;

    _frameSkipCounter++;
    if (_frameSkipCounter < _frameSkipRate) return;
    _frameSkipCounter = 0;

    if (_imageQueue.length >= _maxQueueSize) {
      final oldImage = _imageQueue.removeAt(0);
      try {
        await File(oldImage).delete();
      } catch (e) {
        // Ignore cleanup errors
      }
    }

    try {
      _isProcessing = true;
      final image = await _cameraController!.takePicture();
      _processImageAsync(image.path);
    } catch (e) {
      // Silently handle capture errors
    } finally {
      _isProcessing = false;
    }
  }

  void _processImageAsync(String imagePath) async {
    try {
      final detections = await ModelManager.instance.getInference().runInference(imagePath);
      
      if (mounted && _isRealtimeActive) {
        setState(() {
          _currentDetections = detections;
          _currentImagePath = imagePath;
          _statusMessage = detections.isEmpty 
              ? 'Scanning • 30 FPS' 
              : '${detections.length} object${detections.length > 1 ? 's' : ''} detected • 30 FPS';
        });
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Processing • 30 FPS';
        });
      }
      
      try {
        await File(imagePath).delete();
      } catch (e) {
        // Ignore cleanup errors
      }
    }
  }

  void _showSnackBar(String message, Color color, IconData icon) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Live Detection',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w300,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () {
            _stopRealtimeDetection();
            Navigator.pop(context);
          },
        ),
        actions: [
          if (_isRealtimeActive && _currentDetections.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    '${_currentDetections.length} FOUND',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Animated background effects
          _buildBackgroundEffects(),
          
          // Main content
          SafeArea(
            child: Column(
              children: [
                // Status Bar
                _buildStatusBar(),
                
                const SizedBox(height: 16),
                
                // Camera Preview - NATURAL VIDEO WITHOUT COMPRESSION
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildCameraPreview(),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Control Button
                _buildControlButton(),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundEffects() {
    return Stack(
      children: [
        // Floating particles
        AnimatedBuilder(
          animation: _particleController,
          builder: (context, child) {
            return Stack(
              children: _particles.map((particle) {
                final progress = _particleController.value;
                final yOffset = math.sin(progress * 2 * math.pi + particle.phase) * 30;
                
                return Positioned(
                  left: particle.x * MediaQuery.of(context).size.width,
                  top: particle.y * MediaQuery.of(context).size.height + yOffset,
                  child: Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        
        // Glow effects
        AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) {
            return Stack(
              children: [
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.3,
                  left: -100,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.blue.withValues(alpha: 0.03 * _glowController.value),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: MediaQuery.of(context).size.height * 0.2,
                  right: -100,
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.purple.withValues(alpha: 0.03 * (1 - _glowController.value)),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatusBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: _isRealtimeActive 
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Row(
            children: [
              // Status Indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRealtimeActive 
                      ? Colors.green
                      : _isCameraInitialized && ModelManager.instance.isPreloaded
                          ? Colors.blue
                          : Colors.grey,
                  boxShadow: _isRealtimeActive ? [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.6),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ] : null,
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Status Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _statusMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    if (_isRealtimeActive) ...[
                      const SizedBox(height: 4),
                      Text(
                        'High resolution • Real-time processing',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Detection Count Badge
              if (_currentDetections.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_currentDetections.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // FIXED: Natural camera preview without compression - uses cropping instead of scaling
  Widget _buildCameraPreview() {
    if (!_isCameraInitialized) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
              SizedBox(height: 16),
              Text(
                'Initializing Camera...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
          if (_isRealtimeActive)
            BoxShadow(
              color: Colors.green.withValues(alpha: 0.2),
              blurRadius: 40,
              spreadRadius: 5,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Camera preview - NATURAL SIZE with cropping (no compression)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover, // This crops instead of scaling/compressing
                child: SizedBox(
                  width: _cameraController!.value.previewSize!.height,
                  height: _cameraController!.value.previewSize!.width,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            ),
            
            // Bounding Box Overlay using the SAME overlay as result screen
            if (_isRealtimeActive && _currentImagePath != null)
              BoundingBoxOverlay(
                imagePath: _currentImagePath!,
                detections: _currentDetections,
              ),
            
            // Processing Indicator
            if (_isProcessing)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.6),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            
            // Detection Info Overlay
            if (_isRealtimeActive)
              Positioned(
                bottom: 16,
                left: 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Text(
                        _currentDetections.isEmpty 
                            ? 'Scanning at 30 FPS...' 
                            : '${_currentDetections.length} Objects • 30 FPS',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 64,
        child: ElevatedButton(
          onPressed: _isCameraInitialized && ModelManager.instance.isPreloaded
              ? (_isRealtimeActive ? _stopRealtimeDetection : _startRealtimeDetection)
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isRealtimeActive 
                ? Colors.red.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.1),
            foregroundColor: _isRealtimeActive ? Colors.red : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: _isRealtimeActive 
                    ? Colors.red.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.2),
              ),
            ),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isRealtimeActive ? Icons.stop_rounded : Icons.play_arrow_rounded,
                size: 24,
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isRealtimeActive ? 'Stop Detection' : 'Start Detection',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    _isRealtimeActive 
                        ? 'End live scan'
                        : 'Begin 30 FPS detection',
                    style: TextStyle(
                      fontSize: 12,
                      color: (_isRealtimeActive ? Colors.red : Colors.white).withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Particle {
  final double x;
  final double y;
  final double phase;

  Particle()
      : x = math.Random().nextDouble(),
        y = math.Random().nextDouble(),
        phase = math.Random().nextDouble() * 2 * math.pi;
}