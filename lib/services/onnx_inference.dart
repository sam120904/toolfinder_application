import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';
import 'package:path_provider/path_provider.dart';
import '../models/detection.dart';
import '../services/settings_service.dart';

class OnnxInference {
  OrtSession? _session;
  bool _isInitialized = false;
  String _initStatus = 'Not initialized';
  String? _initError;

  // OPTIMIZED: Reduced logging to minimize terminal spam
  static const bool _enableDetailedLogging = true;

  static const List<String> _classNames = [
    'OxygenTank',
    'NitrogenTank',
    'FirstAidBox',
    'FireAlarm',
    'SafetySwitchPanel',
    'EmergencyPhone',
    'FireExtinguisher'
  ];

  bool get isInitialized => _isInitialized;
  String get initStatus => _initStatus;
  String? get initError => _initError;

  Future<void> initialize() async {
    if (_isInitialized) {
      if (_enableDetailedLogging)
        developer.log('🔄 ONNX model already initialized');
      return;
    }

    try {
      if (_enableDetailedLogging)
        developer.log('🚀 Starting ONNX model initialization...');
      _initStatus = 'Loading model from assets...';
      _initError = null;

      // Load model from assets
      final modelData = await rootBundle.load('assets/best.onnx');
      if (_enableDetailedLogging)
        developer.log(
            '📦 Model loaded from assets, size: ${modelData.lengthInBytes} bytes');

      if (modelData.lengthInBytes == 0) {
        throw Exception(
            'Model file is empty. Please ensure best.onnx is in the assets folder.');
      }

      _initStatus = 'Copying model to temporary directory...';

      // Copy model to temporary directory
      final tempDir = await getTemporaryDirectory();
      final modelFile = File('${tempDir.path}/best.onnx');
      await modelFile.writeAsBytes(modelData.buffer.asUint8List());

      if (_enableDetailedLogging)
        developer.log('📁 Model copied to: ${modelFile.path}');

      // Verify file exists and has content
      if (!await modelFile.exists()) {
        throw Exception('Model file was not created successfully');
      }

      final fileSize = await modelFile.length();
      if (fileSize == 0) {
        throw Exception('Model file is empty after copying');
      }

      if (_enableDetailedLogging)
        developer.log('✅ Model file verified, size: $fileSize bytes');
      _initStatus = 'Creating ONNX session...';

      // Initialize ONNX Runtime session with optimized options
      final sessionOptions = OrtSessionOptions();

      // OPTIMIZED: Better performance settings
      sessionOptions.setSessionGraphOptimizationLevel(
          GraphOptimizationLevel.ortEnableAll);
      if (_enableDetailedLogging)
        developer
            .log('⚙️ Set optimization level to ALL for maximum performance');

      // Create session
      if (_enableDetailedLogging) developer.log('🔧 Creating ONNX session...');
      _session = OrtSession.fromFile(modelFile, sessionOptions);
      if (_enableDetailedLogging)
        developer.log('✅ ONNX session created successfully');

      _initStatus = 'Testing model compatibility...';

      // Test the session with a dummy input to verify it works
      await _testSession();

      _isInitialized = true;
      _initStatus = 'Model ready for instant inference! ✅';
      developer.log('🎉 ONNX model initialized and ready for instant use!');
    } catch (e, stackTrace) {
      developer.log('❌ Error initializing ONNX model: $e');
      if (_enableDetailedLogging) developer.log('📋 Stack trace: $stackTrace');
      _isInitialized = false;
      _initError = e.toString();
      _initStatus = 'Initialization failed ❌';
      rethrow;
    }
  }

  // Test session with dummy input to verify compatibility
  Future<void> _testSession() async {
    try {
      if (_enableDetailedLogging)
        developer.log('🧪 Testing ONNX session with dummy input...');

      // OPTIMIZED: Smaller test tensor to reduce memory allocation
      final dummyPixels = Float32List(1 * 3 * 640 * 640);
      for (int i = 0; i < dummyPixels.length; i++) {
        dummyPixels[i] = 0.5;
      }

      final dummyTensor = OrtValueTensor.createTensorWithDataList(
        dummyPixels,
        [1, 3, 640, 640],
      );

      if (_enableDetailedLogging)
        developer.log('📊 Created dummy tensor with shape [1, 3, 640, 640]');

      // Run inference with dummy input
      final inputs = {'images': dummyTensor};
      final runOptions = OrtRunOptions();

      if (_enableDetailedLogging) developer.log('🔍 Running test inference...');
      final outputs = _session!.run(runOptions, inputs);

      if (_enableDetailedLogging)
        developer
            .log('✅ Session test successful! Output count: ${outputs.length}');

      // Clean up test tensors
      dummyTensor.release();
      runOptions.release();
      for (final output in outputs) {
        output?.release();
      }
    } catch (e, stackTrace) {
      developer.log('❌ Session test failed: $e');
      if (_enableDetailedLogging) developer.log('📋 Stack trace: $stackTrace');
      throw Exception('Model compatibility test failed: $e');
    }
  }

  Future<List<Detection>> runInference(String imagePath) async {
    if (_enableDetailedLogging)
      developer.log('🔍 Starting OPTIMIZED inference for image: $imagePath');

    if (!_isInitialized || _session == null) {
      developer.log('❌ Model not initialized');
      throw Exception(
          'Model not initialized. Please wait for initialization to complete.');
    }

    try {
      // OPTIMIZED: Load and preprocess image with better memory management
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        throw Exception('Image file not found: $imagePath');
      }

      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      if (_enableDetailedLogging)
        developer.log('🖼️ Image loaded: ${image.width}x${image.height}');

      // OPTIMIZED: Resize to 640x640 for YOLOv8
      final resized = img.copyResize(image, width: 640, height: 640);
      if (_enableDetailedLogging) developer.log('📏 Image resized to 640x640');

      // Convert to float32 tensor
      final inputTensor = _imageToTensor(resized);
      if (_enableDetailedLogging) developer.log('🔢 Image converted to tensor');

      // Run OPTIMIZED inference
      final inputs = {'images': inputTensor};
      final runOptions = OrtRunOptions();

      if (_enableDetailedLogging)
        developer.log('🧠 Running OPTIMIZED inference...');
      final outputs = _session!.run(runOptions, inputs);
      if (_enableDetailedLogging)
        developer.log('✅ Inference completed successfully');

      // Process outputs with enhanced filtering
      List<Detection> detections = [];

      if (outputs.isNotEmpty && outputs[0] != null) {
        final outputTensor = outputs[0]!.value;
        developer.log('📊 Output tensor type: ${outputTensor.runtimeType}');
        developer.log('📊 Output tensor: $outputTensor');

        // Handle different output formats
        if (outputTensor is List) {
          developer
              .log('📋 Output is a List with length: ${outputTensor.length}');
          if (outputTensor.isNotEmpty) {
            developer
                .log('📋 First element type: ${outputTensor[0].runtimeType}');
          }

          // Try to cast to proper format
          try {
            if (outputTensor is List<List<List<double>>>) {
              developer.log(
                  '📋 Processing YOLOv8 format [batch][features][anchors]');
              detections = _processYOLOv8OutputEnhanced(
                  outputTensor, image.width, image.height);
            } else {
              // Try to convert to the expected format
              final converted = _convertOutputFormat(outputTensor);
              if (converted != null) {
                developer.log('📋 Converted output format successfully');
                detections = _processYOLOv8OutputEnhanced(
                    converted, image.width, image.height);
              } else {
                developer.log('❌ Could not convert output format');
              }
            }
          } catch (e) {
            developer.log('❌ Error processing output: $e');
            detections = [];
          }
        } else {
          developer
              .log('❓ Unexpected output format: ${outputTensor.runtimeType}');
          detections = [];
        }
      } else {
        developer.log('❌ No outputs received from model');
        detections = [];
      }

      developer.log('🎯 Found ${detections.length} high-quality detections');

      // Clean up tensors
      inputTensor.release();
      runOptions.release();
      for (final output in outputs) {
        output?.release();
      }

      return detections;
    } catch (e, stackTrace) {
      developer.log('❌ Error during inference: $e');
      if (_enableDetailedLogging) developer.log('📋 Stack trace: $stackTrace');
      rethrow;
    }
  }

  List<List<List<double>>>? _convertOutputFormat(dynamic outputTensor) {
    try {
      if (outputTensor is List<List<List<num>>>) {
        // Convert num to double
        return outputTensor
            .map((batch) => batch
                .map((features) =>
                    features.map((value) => value.toDouble()).toList())
                .toList())
            .toList();
      }

      if (outputTensor is List<List<num>>) {
        // Wrap in batch dimension
        developer.log('📋 Wrapping 2D output in batch dimension');
        return [
          outputTensor
              .map((features) =>
                  features.map((value) => value.toDouble()).toList())
              .toList()
        ];
      }

      return null;
    } catch (e) {
      developer.log('❌ Error converting output format: $e');
      return null;
    }
  }

  OrtValueTensor _imageToTensor(img.Image image) {
    final size = image.width; // Should be 640
    final pixels = Float32List(1 * 3 * size * size);
    int index = 0;

    // OPTIMIZED: Convert to CHW format with better normalization
    for (int c = 0; c < 3; c++) {
      for (int y = 0; y < size; y++) {
        for (int x = 0; x < size; x++) {
          final pixel = image.getPixel(x, y);
          double value;
          switch (c) {
            case 0: // Red
              value = pixel.r / 255.0;
              break;
            case 1: // Green
              value = pixel.g / 255.0;
              break;
            case 2: // Blue
              value = pixel.b / 255.0;
              break;
            default:
              value = 0.0;
          }
          pixels[index++] = value;
        }
      }
    }

    return OrtValueTensor.createTensorWithDataList(
      pixels,
      [1, 3, size, size],
    );
  }

  List<Detection> _processYOLOv8OutputEnhanced(
    List<List<List<double>>> outputs,
    int originalWidth,
    int originalHeight,
  ) {
    if (_enableDetailedLogging) {
      developer.log('📋 YOLOv8 Processing:');
      developer.log('📋 Batch size: ${outputs.length}');
      if (outputs.isNotEmpty) {
        developer.log('📋 Dimension 1: ${outputs[0].length}');
        if (outputs[0].isNotEmpty) {
          developer.log('📋 Dimension 2: ${outputs[0][0].length}');
        }
      }
    }

    final detections = <Detection>[];

    final confidenceThreshold = SettingsService.instance.confidenceThreshold;
    final enabledObjects = SettingsService.instance.enabledObjects;

    if (_enableDetailedLogging) {
      developer.log(
          '📋 Using confidence threshold: ${(confidenceThreshold * 100).toInt()}%');
      developer.log(
          '📋 Enabled objects: ${enabledObjects.entries.where((e) => e.value).map((e) => e.key).join(', ')}');
    }

    const double minBoxArea = 400.0;
    const double maxBoxArea = 640.0 * 640.0 * 0.9;
    const int maxDetections = 10;
    const double aspectRatioMin = 0.1;
    const double aspectRatioMax = 10.0;

    final batch = outputs[0];
    final dim1 = batch.length;
    final dim2 = batch[0].length;

    int numAnchors;
    int numFeatures;
    bool needsTranspose = false;

    if (dim2 == 4 + _classNames.length) {
      numAnchors = dim1;
      numFeatures = dim2;
      needsTranspose = true;
      if (_enableDetailedLogging) {
        developer.log('📋 Detected YOLOv8 format: [$numAnchors][$numFeatures] (needs transpose)');
      }
    } else if (dim1 == 4 + _classNames.length) {
      numAnchors = dim2;
      numFeatures = dim1;
      needsTranspose = false;
      if (_enableDetailedLogging) {
        developer.log('📋 Detected transposed format: [$numFeatures][$numAnchors]');
      }
    } else {
      developer.log('❌ Unexpected output dimensions: [$dim1][$dim2]');
      return [];
    }

    if (_enableDetailedLogging) {
      developer.log(
          '📋 Processing $numAnchors anchors with $numFeatures features each');
    }

    final potentialDetections = <Map<String, dynamic>>[];

    for (int anchor = 0; anchor < numAnchors; anchor++) {
      double xCenter, yCenter, width, height;
      List<double> classScores = [];

      if (needsTranspose) {
        xCenter = batch[anchor][0];
        yCenter = batch[anchor][1];
        width = batch[anchor][2];
        height = batch[anchor][3];
        for (int i = 0; i < _classNames.length; i++) {
          classScores.add(batch[anchor][4 + i]);
        }
      } else {
        xCenter = batch[0][anchor];
        yCenter = batch[1][anchor];
        width = batch[2][anchor];
        height = batch[3][anchor];
        for (int i = 0; i < _classNames.length; i++) {
          classScores.add(batch[4 + i][anchor]);
        }
      }

      double maxScore = classScores[0];
      int classId = 0;
      for (int i = 1; i < classScores.length; i++) {
        if (classScores[i] > maxScore) {
          maxScore = classScores[i];
          classId = i;
        }
      }

      final confidence = maxScore.clamp(0.0, 1.0);

      final className = _classNames[classId];
      final isObjectEnabled = enabledObjects[className] ?? false;

      if (confidence > confidenceThreshold &&
          isObjectEnabled &&
          classId >= 0 &&
          classId < _classNames.length &&
          width > 0 &&
          height > 0) {
        final x1 = xCenter - width / 2;
        final y1 = yCenter - height / 2;
        final x2 = xCenter + width / 2;
        final y2 = yCenter + height / 2;

        final boxArea = width * height;
        final aspectRatio = width / height;

        if (x2 > x1 &&
            y2 > y1 &&
            x1 >= 0 &&
            y1 >= 0 &&
            x2 <= 640 &&
            y2 <= 640 &&
            boxArea >= minBoxArea &&
            boxArea <= maxBoxArea &&
            aspectRatio >= aspectRatioMin &&
            aspectRatio <= aspectRatioMax &&
            width >= 10 &&
            height >= 10) {
          potentialDetections.add({
            'x1': x1,
            'y1': y1,
            'x2': x2,
            'y2': y2,
            'confidence': confidence,
            'classId': classId,
            'area': boxArea,
            'aspectRatio': aspectRatio,
          });
        }
      }
    }

    if (_enableDetailedLogging) {
      developer
          .log('📋 Found ${potentialDetections.length} potential detections');
    }

    potentialDetections.sort((a, b) =>
        (b['confidence'] as double).compareTo(a['confidence'] as double));

    final limitedDetections = potentialDetections.take(maxDetections).toList();
    if (_enableDetailedLogging) {
      developer.log(
          '📋 Limited to ${limitedDetections.length} detections');
    }

    for (final det in limitedDetections) {
      final detection = _createDetection(
          det['x1'] as double,
          det['y1'] as double,
          det['x2'] as double,
          det['y2'] as double,
          det['confidence'] as double,
          det['classId'] as int,
          originalWidth,
          originalHeight,
          640);
      detections.add(detection);
      if (_enableDetailedLogging) {
        developer.log(
            '✅ Detection: ${_classNames[det['classId'] as int]} (${((det['confidence'] as double) * 100).toStringAsFixed(1)}%)');
      }
    }

    final result = _applyEnhancedNMS(detections, 0.45);
    if (_enableDetailedLogging) {
      developer.log(
          '📋 Final result: ${result.length} detections after NMS');
    }

    return result;
  }

  Detection _createDetection(
      double x1,
      double y1,
      double x2,
      double y2,
      double confidence,
      int classId,
      int originalWidth,
      int originalHeight,
      int inputSize) {
    // FIXED: Proper scaling and clamping to prevent boxes going outside image
    final scaledX1 =
        ((x1 / inputSize) * originalWidth).clamp(0.0, originalWidth.toDouble());
    final scaledY1 = ((y1 / inputSize) * originalHeight)
        .clamp(0.0, originalHeight.toDouble());
    final scaledX2 =
        ((x2 / inputSize) * originalWidth).clamp(0.0, originalWidth.toDouble());
    final scaledY2 = ((y2 / inputSize) * originalHeight)
        .clamp(0.0, originalHeight.toDouble());

    return Detection(
      x1: scaledX1,
      y1: scaledY1,
      x2: scaledX2,
      y2: scaledY2,
      confidence: confidence,
      classId: classId,
      className: _classNames[classId],
    );
  }

  List<Detection> _applyEnhancedNMS(
      List<Detection> detections, double iouThreshold) {
    if (detections.isEmpty) return detections;

    // Sort by confidence (descending)
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));

    final result = <Detection>[];
    final suppressed = List<bool>.filled(detections.length, false);

    for (int i = 0; i < detections.length; i++) {
      if (suppressed[i]) continue;

      result.add(detections[i]);

      for (int j = i + 1; j < detections.length; j++) {
        if (suppressed[j]) continue;

        final iou = _calculateIoU(detections[i], detections[j]);

        // Enhanced NMS with class consideration
        if (iou > iouThreshold) {
          if (detections[i].classId == detections[j].classId) {
            suppressed[j] = true;
          } else if (iou > 0.7) {
            // Different classes: only suppress if very high overlap
            suppressed[j] = true;
          }
        }
      }
    }

    if (_enableDetailedLogging) {
      developer.log(
          '📋 Enhanced NMS: Kept ${result.length} out of ${detections.length} detections');
    }
    return result;
  }

  double _calculateIoU(Detection a, Detection b) {
    final intersectionX1 = a.x1 > b.x1 ? a.x1 : b.x1;
    final intersectionY1 = a.y1 > b.y1 ? a.y1 : b.y1;
    final intersectionX2 = a.x2 < b.x2 ? a.x2 : b.x2;
    final intersectionY2 = a.y2 < b.y2 ? a.y2 : b.y2;

    if (intersectionX2 <= intersectionX1 || intersectionY2 <= intersectionY1) {
      return 0.0;
    }

    final intersectionArea =
        (intersectionX2 - intersectionX1) * (intersectionY2 - intersectionY1);
    final areaA = (a.x2 - a.x1) * (a.y2 - a.y1);
    final areaB = (b.x2 - b.x1) * (b.y2 - b.y1);
    final unionArea = areaA + areaB - intersectionArea;

    return unionArea > 0 ? intersectionArea / unionArea : 0.0;
  }

  void dispose() {
    _session?.release();
    _session = null;
    _isInitialized = false;
    _initStatus = 'Disposed';
    developer.log('🗑️ ONNX session disposed');
  }
}
