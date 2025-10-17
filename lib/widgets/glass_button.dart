import 'package:flutter/material.dart';
import 'dart:ui';

class GlassButton extends StatefulWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isFullWidth;
  final bool isCompactMode;
  final bool isPrimary;

  const GlassButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isFullWidth = false,
    this.isCompactMode = false,
    this.isPrimary = false,
  });

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _animationController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _animationController.reverse();
  }

  void _onTapCancel() {
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            onTap: widget.onPressed,
            child: Container(
              width: widget.isFullWidth ? double.infinity : null,
              padding: EdgeInsets.all(widget.isCompactMode ? 20 : 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.isCompactMode ? 20 : 24),
                border: Border.all(
                  color: widget.isPrimary
                      ? Colors.white.withValues(alpha: 0.3 + (0.2 * _glowAnimation.value))
                      : Colors.white.withValues(alpha: 0.1 + (0.1 * _glowAnimation.value)),
                  width: 1,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.isPrimary
                      ? [
                          Colors.white.withValues(alpha: 0.15 + (0.05 * _glowAnimation.value)),
                          Colors.white.withValues(alpha: 0.08 + (0.02 * _glowAnimation.value)),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.08 + (0.02 * _glowAnimation.value)),
                          Colors.white.withValues(alpha: 0.03 + (0.01 * _glowAnimation.value)),
                        ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                  if (widget.isPrimary)
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.1 * _glowAnimation.value),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.isCompactMode ? 20 : 24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: widget.isCompactMode
                      ? Row(
                          mainAxisSize: widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.2),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                              child: Icon(
                                widget.icon,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.title,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.subtitle,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Icon Container
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.2),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                              child: Icon(
                                widget.icon,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Title
                            Text(
                              widget.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            
                            const SizedBox(height: 6),
                            
                            // Subtitle
                            Text(
                              widget.subtitle,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}