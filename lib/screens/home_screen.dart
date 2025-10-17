import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import '../widgets/settings_dialog.dart';
import 'image_preview_screen.dart';
import 'realtime_detection_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _particleController;
  late AnimationController _glowController;
  late List<Particle> _particles;

  // Accelerometer variables
  double _accelerometerX = 0.0;
  double _accelerometerY = 0.0;
  double _velocityX = 0.0;
  double _velocityY = 0.0;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  
  // Calibration variables
  bool _isCalibrated = false;
  double _baselineX = 0.0;
  double _baselineY = 0.0;
  int _calibrationSamples = 0;
  static const int _calibrationCount = 5; // Reduced from 10 for faster response

  @override
  void initState() {
    super.initState();
    
    // Rotation animation for the main icon rings
    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    
    // Particle floating animation
    _particleController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat();
    
    // Glow pulse animation
    _glowController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);
    
    // Initialize floating particles (stars) with extended area
    _particles = List.generate(25, (index) => Particle());
    
    // Start accelerometer listening
    _startAccelerometer();
  }

  void _startAccelerometer() {
    try {
      _accelerometerSubscription = accelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 16), // Reduced from 50ms for faster response
      ).listen((AccelerometerEvent event) {
        if (!_isCalibrated) {
          // Calibration phase - establish baseline
          _baselineX += event.x;
          _baselineY += event.y;
          _calibrationSamples++;
          
          if (_calibrationSamples >= _calibrationCount) {
            _baselineX /= _calibrationCount;
            _baselineY /= _calibrationCount;
            _isCalibrated = true;
          }
        } else {
          // Apply baseline correction and update accelerometer values
          final correctedX = event.x - _baselineX;
          final correctedY = event.y - _baselineY;
          
          // Immediate response with reduced smoothing
          _accelerometerX = _accelerometerX * 0.7 + correctedX * 0.3; // Reduced smoothing from 0.9/0.1
          _accelerometerY = _accelerometerY * 0.7 + correctedY * 0.3;
          
          // Update velocity with momentum
          const sensitivity = 0.08; // Increased slightly from 0.05 for better response
          _velocityX = (_velocityX * 0.92) + (_accelerometerX * sensitivity); // Reduced damping from 0.95
          _velocityY = (_velocityY * 0.92) + (-_accelerometerY * sensitivity); // Inverted Y for natural feel
          
          // Cap velocity to prevent extreme movements
          _velocityX = _velocityX.clamp(-2.0, 2.0); // Increased from 1.5 for better range
          _velocityY = _velocityY.clamp(-2.0, 2.0);
        }
      });
    } catch (e) {
      // Fallback: mark as calibrated to prevent blocking
      _isCalibrated = true;
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _particleController.dispose();
    _glowController.dispose();
    _accelerometerSubscription?.cancel();
    super.dispose();
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      
      if (pickedFile != null && mounted) {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                ImagePreviewScreen(imagePath: pickedFile.path),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                )),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to capture image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      
      if (pickedFile != null && mounted) {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                ImagePreviewScreen(imagePath: pickedFile.path),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                )),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to select image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openRealtimeDetection() {
    if (mounted) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const RealtimeDetectionScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 1.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              )),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  void _openSettings() {
    showDialog(
      context: context,
      builder: (context) => const SettingsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Animated Background Grid (subtle) - NO accelerometer influence
          _buildBackgroundGrid(),
          
          // Floating Particles (Stars) - WITH accelerometer influence
          _buildFloatingParticles(),
          
          // Animated Glow Effects - NO accelerometer influence
          _buildGlowEffects(),
          
          // Main Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const SizedBox(height: 48),
                  
                  // Header with animated icon
                  _buildAnimatedHeader(),
                  
                  const SizedBox(height: 64),
                  
                  // Main Action Buttons
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildRoundGlassButton(
                          onPressed: _pickImageFromCamera,
                          icon: Icons.camera_alt_rounded,
                          title: 'Capture Image',
                          delay: 0,
                        ),
                        
                        const SizedBox(height: 24),
                        
                        _buildRoundGlassButton(
                          onPressed: _pickImageFromGallery,
                          icon: Icons.photo_library_rounded,
                          title: 'Select from Gallery',
                          delay: 100,
                        ),
                        
                        const SizedBox(height: 24),
                        
                        _buildRoundGlassButton(
                          onPressed: _openRealtimeDetection,
                          icon: Icons.videocam_rounded,
                          title: 'Live Detection',
                          delay: 200,
                        ),
                      ],
                    ),
                  ),
                  
                  // Enhanced Status Section
                  _buildStatusSection(),
                  
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          
          // Settings Button (Top Right)
          Positioned(
            top: 60,
            right: 24,
            child: _buildSettingsButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundGrid() {
    return Positioned.fill(
      child: Opacity(
        opacity: 0.02,
        child: CustomPaint(
          painter: GridPainter(),
        ),
      ),
    );
  }

  Widget _buildFloatingParticles() {
    return AnimatedBuilder(
      animation: _particleController,
      builder: (context, child) {
        return Stack(
          children: _particles.map((particle) {
            final progress = _particleController.value;
            final baseYOffset = math.sin(progress * 2 * math.pi + particle.phase) * 20;
            
            // Apply accelerometer influence only if calibrated
            final accelerometerInfluence = _isCalibrated ? 15.0 : 0.0;
            final accelerometerXOffset = _velocityX * accelerometerInfluence * particle.sensitivity;
            final accelerometerYOffset = _velocityY * accelerometerInfluence * particle.sensitivity;
            
            // Calculate final position with extended area (120% of screen)
            final screenWidth = MediaQuery.of(context).size.width;
            final screenHeight = MediaQuery.of(context).size.height;
            final extendedWidth = screenWidth * 1.2;
            final extendedHeight = screenHeight * 1.2;
            
            final finalX = (particle.x * extendedWidth) - (extendedWidth - screenWidth) / 2 + accelerometerXOffset;
            final finalY = (particle.y * extendedHeight) - (extendedHeight - screenHeight) / 2 + baseYOffset + accelerometerYOffset;
            
            // Enhanced visual effects based on movement
            final movementIntensity = (math.sqrt(_velocityX * _velocityX + _velocityY * _velocityY) * 0.5).clamp(0.0, 1.0);
            final dynamicOpacity = (particle.opacity + movementIntensity * 0.3).clamp(0.0, 1.0);
            final dynamicSize = particle.size + movementIntensity * 1.0;
            
            return Positioned(
              left: finalX,
              top: finalY,
              child: Transform.rotate(
                angle: progress * 2 * math.pi * particle.sensitivity,
                child: Container(
                  width: dynamicSize,
                  height: dynamicSize,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: dynamicOpacity),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: dynamicOpacity * 0.5),
                        blurRadius: 2 + movementIntensity * 2,
                        spreadRadius: 0.5 + movementIntensity * 0.5,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildGlowEffects() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        return Stack(
          children: [
            Positioned(
              top: MediaQuery.of(context).size.height * 0.25,
              left: MediaQuery.of(context).size.width * 0.5 - 192,
              child: Container(
                width: 384,
                height: 384,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.blue.withValues(alpha: 0.05 * _glowController.value),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.25,
              right: MediaQuery.of(context).size.width * 0.5 - 160,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.purple.withValues(alpha: 0.05 * (1 - _glowController.value)),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAnimatedHeader() {
    return Column(
      children: [
        // Animated Icon with Rotating Rings
        SizedBox(
          width: 96,
          height: 96,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer rotating ring
              AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _rotationController.value * 2 * math.pi,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 2,
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              // Inner counter-rotating ring
              AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: -_rotationController.value * 1.5 * math.pi,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                          width: 1,
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              // Center icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.1),
                      Colors.white.withValues(alpha: 0.05),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: const Icon(
                      Icons.satellite_alt_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Title
        const Text(
          'Lunar Lens',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w300,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Subtitle
        Text(
          'Space Station Operations',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w300,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Animated underline
        AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) {
            return Container(
              width: 64,
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.white.withValues(alpha: 0.3 * _glowController.value),
                    Colors.transparent,
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRoundGlassButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String title,
    required int delay,
  }) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 500 + delay),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: _RoundGlassButton(
              onPressed: onPressed,
              icon: icon,
              title: title,
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusSection() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [
                Colors.green.withValues(alpha: 0.1),
                const Color(0xFF10B981).withValues(alpha: 0.1),
              ],
            ),
            border: Border.all(
              color: Colors.green.withValues(alpha: 0.2),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _glowController,
                        builder: (context, child) {
                          return Container(
                            width: 12 + (8 * _glowController.value),
                            height: 12 + (8 * _glowController.value),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'System Ready',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.flash_on_rounded,
                    color: Colors.green,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        Text(
          'Neural Network Active',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.4),
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsButton() {
    return GestureDetector(
      onTap: _openSettings,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.1),
              Colors.white.withValues(alpha: 0.05),
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: const Icon(
              Icons.settings_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundGlassButton extends StatefulWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String title;

  const _RoundGlassButton({
    required this.onPressed,
    required this.icon,
    required this.title,
  });

  @override
  State<_RoundGlassButton> createState() => _RoundGlassButtonState();
}

class _RoundGlassButtonState extends State<_RoundGlassButton> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _shimmerController.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40), // ROUND GLASS LOOK
          gradient: LinearGradient(
            colors: _isPressed
                ? [
                    Colors.white.withValues(alpha: 0.15),
                    Colors.white.withValues(alpha: 0.2),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.08),
                    Colors.white.withValues(alpha: 0.12),
                  ],
          ),
          border: Border.all(
            color: _isPressed
                ? Colors.white.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
            if (_isPressed)
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.1),
                blurRadius: 30,
                spreadRadius: 5,
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40), // ROUND GLASS LOOK
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Stack(
              children: [
                // Shimmer effect
                AnimatedBuilder(
                  animation: _shimmerController,
                  builder: (context, child) {
                    return Positioned(
                      left: -100 + (MediaQuery.of(context).size.width + 200) * _shimmerController.value,
                      top: 0,
                      bottom: 0,
                      width: 100,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.1),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                
                // Button content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle, // ROUND ICON CONTAINER
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.2),
                              Colors.white.withValues(alpha: 0.1),
                            ],
                          ),
                        ),
                        transform: _isPressed
                            ? (Matrix4.identity()..scale(1.1))
                            : Matrix4.identity(),
                        child: Icon(
                          widget.icon,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
  final double size;
  final double opacity;
  final double sensitivity;

  Particle()
      : x = math.Random().nextDouble(),
        y = math.Random().nextDouble(),
        phase = math.Random().nextDouble() * 2 * math.pi,
        size = 1.5 + (math.Random().nextDouble() * 2.5), // Match splash screen size
        opacity = 0.1 + (math.Random().nextDouble() * 0.3),
        sensitivity = 0.5 + (math.Random().nextDouble() * 0.5); // Variable sensitivity
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 0.5;

    const spacing = 60.0;

    // Draw vertical lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}