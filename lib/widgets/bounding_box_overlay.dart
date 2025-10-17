import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../models/detection.dart';

class BoundingBoxOverlay extends StatefulWidget {
  final String imagePath;
  final List<Detection> detections;

  const BoundingBoxOverlay({
    super.key,
    required this.imagePath,
    required this.detections,
  });

  @override
  State<BoundingBoxOverlay> createState() => _BoundingBoxOverlayState();
}

class _BoundingBoxOverlayState extends State<BoundingBoxOverlay>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Size>(
      future: _getImageSize(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final imageSize = snapshot.data!;
        
        return LayoutBuilder(
          builder: (context, constraints) {
            final containerSize = Size(constraints.maxWidth, constraints.maxHeight);
            final displaySize = _calculateDisplaySize(imageSize, containerSize);
            final offset = _calculateOffset(displaySize, containerSize);

            return Stack(
              children: widget.detections.map((detection) {
                return _buildBoundingBox(detection, imageSize, displaySize, offset, context);
              }).toList(),
            );
          },
        );
      },
    );
  }

  Future<Size> _getImageSize() async {
    final imageFile = File(widget.imagePath);
    final imageBytes = await imageFile.readAsBytes();
    final image = img.decodeImage(imageBytes);
    
    if (image != null) {
      return Size(image.width.toDouble(), image.height.toDouble());
    }
    
    return const Size(1, 1);
  }

  Size _calculateDisplaySize(Size imageSize, Size containerSize) {
    final imageAspectRatio = imageSize.width / imageSize.height;
    final containerAspectRatio = containerSize.width / containerSize.height;

    if (imageAspectRatio > containerAspectRatio) {
      return Size(
        containerSize.width,
        containerSize.width / imageAspectRatio,
      );
    } else {
      return Size(
        containerSize.height * imageAspectRatio,
        containerSize.height,
      );
    }
  }

  Offset _calculateOffset(Size displaySize, Size containerSize) {
    return Offset(
      (containerSize.width - displaySize.width) / 2,
      (containerSize.height - displaySize.height) / 2,
    );
  }

  Widget _buildBoundingBox(
    Detection detection,
    Size imageSize,
    Size displaySize,
    Offset offset,
    BuildContext context,
  ) {
    final scaleX = displaySize.width / imageSize.width;
    final scaleY = displaySize.height / imageSize.height;

    final left = (detection.x1 * scaleX + offset.dx).clamp(0.0, displaySize.width + offset.dx);
    final top = (detection.y1 * scaleY + offset.dy).clamp(0.0, displaySize.height + offset.dy);
    final right = (detection.x2 * scaleX + offset.dx).clamp(0.0, displaySize.width + offset.dx);
    final bottom = (detection.y2 * scaleY + offset.dy).clamp(0.0, displaySize.height + offset.dy);

    final width = (right - left).clamp(0.0, displaySize.width);
    final height = (bottom - top).clamp(0.0, displaySize.height);

    if (width <= 0 || height <= 0) {
      return const SizedBox.shrink();
    }

    final color = _getClassColor(detection.classId);

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Positioned(
          left: left,
          top: top,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              border: Border.all(
                color: color.withValues(alpha: _pulseAnimation.value),
                width: 3.0,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4 * _pulseAnimation.value),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Stack(
              children: [
                // Enhanced label with glassmorphism
                Positioned(
                  top: -4,
                  left: -4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: color.withValues(alpha: 0.6),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '${detection.className} ${(detection.confidence * 100).toInt()}%',
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.8),
                                offset: const Offset(1, 1),
                                blurRadius: 2,
                              ),
                            ],
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
      },
    );
  }

  Color _getClassColor(int classId) {
    const colors = [
      Color(0xFFFF6B6B), // FireExtinguisher - Bright red
      Color(0xFF4ECDC4), // ToolBox - Cyan  
      Color(0xFF45B7D1), // OxygenTank - Blue
    ];
    return colors[classId % colors.length];
  }
}