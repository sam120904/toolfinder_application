import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:image/image.dart' as img;
import '../models/detection.dart';

class OnnxInference {
  OrtSession? _session;
  OrtRunOptions? _runOptions;
  static const _modelPath = 'assets/best.onnx';

  // Define the list of class names
  final List<String> _classNames = [
    'OxygenTank',
    'NitrogenTank',
    'FirstAidBox',
    'FireAlarm',
    'SafetySwitchPanel',
    'EmergencyPhone',
    'FireExtinguisher'
  ];

  // Initialize the ONNX session
  Future<void> initialize() async {
    try {
      final sessionOptions = OrtSessionOptions();
      final rawAssetFile = await rootBundle.load(_modelPath);
      final bytes = rawAssetFile.buffer.asUint8List();
      _session = OrtSession.fromBuffer(bytes, sessionOptions);
      _runOptions = OrtRunOptions();
      developer.log('✅ ONNX session initialized successfully.');
    } catch (e) {
      developer.log('❌ Error initializing ONNX session: $e');
      rethrow;
    }
  }

  // Run inference on a given image path
  Future<List<Detection>> runInference(String imagePath) async {
    final imageFile = File(imagePath);
    if (!await imageFile.exists()) {
      developer.log('❌ Image file not found at $imagePath');
      return [];
    }

    // Decode the image
    final image = img.decodeImage(await imageFile.readAsBytes())!;
    final originalWidth = image.width;
    final originalHeight = image.height;

    // Resize the image to 640x640
    final resizedImage = img.copyResize(image, width: 640, height: 640);

    // Normalize and prepare the image tensor in CHW format (Channel, Height, Width)
    final floatList = Float32List(1 * 3 * 640 * 640);
    int pixelIndex = 0;

    for (int y = 0; y < 640; y++) {
      for (int x = 0; x < 640; x++) {
        final pixel = resizedImage.getPixel(x, y);
        floatList[pixelIndex] = pixel.r / 255.0;
        floatList[pixelIndex + 640 * 640] = pixel.g / 255.0;
        floatList[pixelIndex + 2 * 640 * 640] = pixel.b / 255.0;
        pixelIndex++;
      }
    }

    // Create the ONNX tensor
    final inputTensor = OrtValueTensor.createTensorWithDataList(
      floatList,
      [1, 3, 640, 640],
    );

    try {
      // Run the model
      final inputs = {'images': inputTensor};
      final outputs = await _session!.run(_runOptions!, inputs);
      return _processOutput(outputs, originalWidth, originalHeight);
    } catch (e) {
      developer.log('❌ Error running inference: $e');
      return [];
    } finally {
      inputTensor.release();
    }
  }

  // Process the model's output
  List<Detection> _processOutput(
    List<OrtValue?> outputs,
    int originalImageWidth,
    int originalImageHeight,
  ) {
    if (outputs.isEmpty || outputs.first == null) {
      developer.log('❌ Model output is empty.');
      return [];
    }

    // Extract the output tensor
    final output = outputs.first!.value as List<List<double>>;
    final List<Rect> boxes = [];
    final List<double> confidences = [];
    final List<int> classIds = [];

    // The number of classes is the number of columns minus 4 (for bbox coordinates)
    final numClasses = output.length - 4;

    // Transpose the output for easier processing
    final transposedOutput = List.generate(
      output[0].length,
      (i) => List.generate(output.length, (j) => output[j][i]),
    );

    for (final row in transposedOutput) {
      final boxConfidences = row.sublist(4);

      // Find the class with the highest score
      double maxConfidence = 0;
      int maxIndex = -1;
      for (int i = 0; i < numClasses; i++) {
        if (boxConfidences[i] > maxConfidence) {
          maxConfidence = boxConfidences[i];
          maxIndex = i;
        }
      }

      // Filter detections based on confidence threshold
      if (maxConfidence > 0.5) {
        final double x = row[0];
        final double y = row[1];
        final double w = row[2];
        final double h = row[3];

        final left = x - w / 2;
        final top = y - h / 2;

        boxes.add(Rect.fromLTWH(left, top, w, h));
        confidences.add(maxConfidence);
        classIds.add(maxIndex);
      }
    }

    // Apply Non-Maximum Suppression
    final List<int> indices =
        _nonMaximumSuppression(boxes, confidences, 0.5, 0.5);
    final List<Detection> detections = [];

    for (final index in indices) {
      final box = boxes[index];
      final confidence = confidences[index];
      final classId = classIds[index];
      final className = _classNames[classId];

      // Scale bounding box back to the original image size
      final scaledBox = Rect.fromLTRB(
        box.left * originalImageWidth / 640,
        box.top * originalImageHeight / 640,
        (box.left + box.width) * originalImageWidth / 640,
        (box.top + box.height) * originalImageHeight / 640,
      );

      detections.add(Detection(
        className: className,
        confidence: confidence,
        x1: scaledBox.left,
        y1: scaledBox.top,
        x2: scaledBox.right,
        y2: scaledBox.bottom,
        classId: classId,
      ));
    }

    return detections;
  }

  // Non-Maximum Suppression algorithm
  List<int> _nonMaximumSuppression(
    List<Rect> boxes,
    List<double> scores,
    double iouThreshold,
    double scoreThreshold,
  ) {
    final List<int> selectedIndices = [];
    final List<int> sortedIndices = List.generate(scores.length, (i) => i)
      ..sort((a, b) => scores[b].compareTo(scores[a]));

    while (sortedIndices.isNotEmpty) {
      final int bestIndex = sortedIndices.removeAt(0);
      selectedIndices.add(bestIndex);

      final List<int> remainingIndices = [];
      for (final int index in sortedIndices) {
        final double iou = _calculateIoU(boxes[bestIndex], boxes[index]);
        if (iou < iouThreshold) {
          remainingIndices.add(index);
        }
      }
      sortedIndices.clear();
      sortedIndices.addAll(remainingIndices);
    }

    return selectedIndices;
  }

  // Calculate Intersection over Union (IoU)
  double _calculateIoU(Rect boxA, Rect boxB) {
    final double xA = (boxA.left > boxB.left) ? boxA.left : boxB.left;
    final double yA = (boxA.top > boxB.top) ? boxA.top : boxB.top;
    final double xB = (boxA.right < boxB.right) ? boxA.right : boxB.right;
    final double yB = (boxA.bottom < boxB.bottom) ? boxA.bottom : boxB.bottom;

    final double intersectionArea =
        (xB - xA > 0 ? xB - xA : 0) * (yB - yA > 0 ? yB - yA : 0);

    final double boxAArea = boxA.width * boxA.height;
    final double boxBArea = boxB.width * boxB.height;

    return intersectionArea / (boxAArea + boxBArea - intersectionArea);
  }

  // Dispose of the ONNX session
  void dispose() {
    _session?.release();
  }
}