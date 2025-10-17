import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../main.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _progressController;
  late AnimationController _particleController;
  late AnimationController _glowController;
  late Animation<double> _logoAnimation;
  late Animation<double> _progressAnimation;
  late List<Particle> _particles;
  
  String _statusText = 'Initializing ToolFinder AI...';
  double _progress = 0.0;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _particleController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
    
    _glowController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    
    _logoAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));
    
    // Initialize floating particles (stars)
    _particles = List.generate(30, (index) => Particle());
    
    // Start animations
    _logoController.forward();
    
    // Start initialization after a short delay
    Timer(const Duration(milliseconds: 800), () {
      _startInitialization();
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _progressController.dispose();
    _particleController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _startInitialization() async {
    try {
      // Step 1: Basic setup
      await _updateProgress(0.2, 'Initializing space systems...');
      await Future.delayed(const Duration(milliseconds: 400));
      
      // Step 2: Camera check
      await _updateProgress(0.4, 'Checking camera access...');
      if (cameras.isEmpty) {
        throw Exception('No cameras found on device');
      }
      await Future.delayed(const Duration(milliseconds: 400));
      
      // Step 3: Start model loading
      await _updateProgress(0.6, 'Loading neural network...');
      
      // Start model loading in background
      ModelManager.instance.preloadModel().catchError((error) {
        developer.log('⚠️ Model loading failed, but continuing: $error');
      });
      
      await Future.delayed(const Duration(milliseconds: 800));
      
      // Step 4: Finalizing
      await _updateProgress(0.9, 'Preparing mission control...');
      await Future.delayed(const Duration(milliseconds: 400));
      
      // Step 5: Complete
      await _updateProgress(1.0, 'Ready for space operations! 🚀');
      await Future.delayed(const Duration(milliseconds: 600));
      
      // Navigate to home screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const HomeScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 1000),
          ),
        );
      }
      
    } catch (e) {
      developer.log('❌ Splash initialization error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _statusText = 'Initialization failed';
        });
      }
    }
  }

  Future<void> _updateProgress(double progress, String status) async {
    if (mounted) {
      setState(() {
        _progress = progress;
        _statusText = status;
      });
      _progressController.animateTo(progress);
    }
  }

  void _retryInitialization() {
    setState(() {
      _hasError = false;
      _errorMessage = null;
      _progress = 0.0;
      _statusText = 'Retrying initialization...';
    });
    _progressController.reset();
    _startInitialization();
  }

  void _continueWithoutModel() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Floating Particles (Stars)
          _buildFloatingParticles(),
          
          // Glow Effects
          _buildGlowEffects(),
          
          // Main Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  
                  // Animated Logo with Orbital Rings
                  _buildAnimatedLogo(),
                  
                  const SizedBox(height: 48),
                  
                  // App Title
                  _buildAppTitle(),
                  
                  const Spacer(flex: 1),
                  
                  // Progress Section or Error
                  if (!_hasError) ...[
                    _buildProgressSection(),
                  ] else ...[
                    _buildErrorSection(),
                  ],
                  
                  const Spacer(flex: 1),
                  
                  // Footer
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ],
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
            final yOffset = math.sin(progress * 2 * math.pi + particle.phase) * 30;
            
            return Positioned(
              left: particle.x * MediaQuery.of(context).size.width,
              top: particle.y * MediaQuery.of(context).size.height + yOffset,
              child: Container(
                width: particle.size,
                height: particle.size,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: particle.opacity),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: particle.opacity * 0.5),
                      blurRadius: 2,
                      spreadRadius: 0.5,
                    ),
                  ],
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
              top: MediaQuery.of(context).size.height * 0.2,
              left: -150,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.blue.withValues(alpha: 0.06 * _glowController.value),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.2,
              right: -150,
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.purple.withValues(alpha: 0.06 * (1 - _glowController.value)),
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

  Widget _buildAnimatedLogo() {
    return AnimatedBuilder(
      animation: _logoAnimation,
      builder: (context, child) {
        final opacity = _logoAnimation.value.clamp(0.0, 1.0);
        return Transform.scale(
          scale: opacity,
          child: SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer rotating ring
                AnimatedBuilder(
                  animation: _particleController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _particleController.value * 2 * math.pi,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1 * opacity),
                            width: 2,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                
                // Inner counter-rotating ring
                AnimatedBuilder(
                  animation: _particleController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: -_particleController.value * 1.5 * math.pi,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05 * opacity),
                            width: 1,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                
                // Center logo with glow
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.15 * opacity),
                        Colors.white.withValues(alpha: 0.05 * opacity),
                        Colors.transparent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.3 * opacity),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Icon(
                        Icons.rocket_launch_rounded,
                        size: 40,
                        color: Colors.white.withValues(alpha: opacity),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppTitle() {
    return AnimatedBuilder(
      animation: _logoAnimation,
      builder: (context, child) {
        final opacity = _logoAnimation.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: Column(
            children: [
              Text(
                'ToolFinder AI',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w300,
                  color: Colors.white.withValues(alpha: opacity),
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Space Station Object Detection',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.7 * opacity),
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressSection() {
    return Column(
      children: [
        // Progress Bar with Glow
        Container(
          width: double.infinity,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Colors.white.withValues(alpha: 0.1),
          ),
          child: AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return Stack(
                children: [
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _progressAnimation.value.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: const LinearGradient(
                          colors: [
                            Colors.blue,
                            Colors.cyan,
                            Colors.white,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Status Text
        Text(
          _statusText,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 12),
        
        // Progress Percentage
        Text(
          '${(_progress * 100).toInt()}%',
          style: const TextStyle(
            fontSize: 14,
            color: Colors.cyan,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorSection() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.red.withValues(alpha: 0.1),
            border: Border.all(
              color: Colors.red.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Initialization Failed',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? 'Unknown error occurred',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _retryInitialization,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Retry'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      onPressed: _continueWithoutModel,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white.withValues(alpha: 0.7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Continue'),
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

  Widget _buildFooter() {
    return Text(
      'Powered by Advanced Neural Networks for Space Missions',
      style: TextStyle(
        fontSize: 12,
        color: Colors.white.withValues(alpha: 0.5),
        fontWeight: FontWeight.w300,
      ),
      textAlign: TextAlign.center,
    );
  }
}

class Particle {
  final double x;
  final double y;
  final double phase;
  final double size;
  final double opacity;

  Particle()
      : x = math.Random().nextDouble(),
        y = math.Random().nextDouble(),
        phase = math.Random().nextDouble() * 2 * math.pi,
        size = 1.5 + (math.Random().nextDouble() * 2.5),
        opacity = 0.1 + (math.Random().nextDouble() * 0.4);
}
