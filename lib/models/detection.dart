class Detection {
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final double confidence;
  final int classId;
  final String className;

  Detection({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.confidence,
    required this.classId,
    required this.className,
  });

  factory Detection.fromMap(Map<String, dynamic> map) {
    return Detection(
      x1: (map['x1'] as num).toDouble(),
      y1: (map['y1'] as num).toDouble(),
      x2: (map['x2'] as num).toDouble(),
      y2: (map['y2'] as num).toDouble(),
      confidence: (map['confidence'] as num).toDouble(),
      classId: map['classId'] as int,
      className: map['className'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'x1': x1,
      'y1': y1,
      'x2': x2,
      'y2': y2,
      'confidence': confidence,
      'classId': classId,
      'className': className,
    };
  }

  @override
  String toString() {
    return 'Detection(className: $className, confidence: ${(confidence * 100).toStringAsFixed(1)}%, bbox: [$x1, $y1, $x2, $y2])';
  }
}
