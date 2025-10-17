# ToolFinder AI - YOLOv8 Object Detection Flutter App

## 📱 App Structure

\`\`\`
lib/
├── main.dart                    # App entry point
├── models/
│   └── detection.dart          # Detection data model
├── services/
│   └── onnx_inference.dart     # ONNX inference service
├── widgets/
│   ├── glass_button.dart       # Glassmorphism button widget
│   └── bounding_box_overlay.dart # Custom painter for bounding boxes
└── screens/
    ├── home_screen.dart        # Main screen with camera/gallery options
    ├── image_preview_screen.dart # Image preview with detect button
    └── result_screen.dart      # Results with bounding boxes
\`\`\`

## 🧠 Model Details

**Framework**: YOLOv8 (Ultralytics) for object detection  
**Export Format**: ONNX (Open Neural Network Exchange)  
**ONNX Opset Version**: 13 (for maximum compatibility)  
**Model File**: `best.onnx` (placed in `assets/` folder)  
**Model Size**: ~103MB

### 🎯 Object Classes (3 total)
1. **FireExtinguisher** (Class ID: 0)
2. **ToolBox** (Class ID: 1) 
3. **OxygenTank** (Class ID: 2)

### 📊 Input Specifications
- **Input Shape**: `(1, 3, 640, 640)`
- **Format**: RGB images (not BGR)
- **Preprocessing**: 
  - Resize to 640x640 pixels
  - Normalize pixel values to [0, 1] range (divide by 255)
  - Convert to CHW format (Channels, Height, Width)
  - Data type: Float32

### 📈 Output Specifications
- **Output Shape**: `(1, 7, 8400)` 
- **Format**: YOLOv8 standard output format
- **Structure**:
  - **Batch**: 1 (single image)
  - **Features**: 7 (4 bbox coordinates + 3 class scores)
  - **Anchors**: 8400 (detection points across 3 scales)

### 🔍 Output Processing Details
**Feature Layout** (7 values per anchor):
1. `x_center` - Center X coordinate (0-640 scale)
2. `y_center` - Center Y coordinate (0-640 scale) 
3. `width` - Bounding box width (0-640 scale)
4. `height` - Bounding box height (0-640 scale)
5. `class_0_score` - FireExtinguisher confidence (raw logit)
6. `class_1_score` - ToolBox confidence (raw logit)
7. `class_2_score` - OxygenTank confidence (raw logit)

**Anchor Points** (8400 total):
- **80x80 grid**: 6400 anchors (large objects)
- **40x40 grid**: 1600 anchors (medium objects)  
- **20x20 grid**: 400 anchors (small objects)

### ⚙️ Post-Processing Pipeline
1. **Transpose**: Convert `[1, 7, 8400]` to process 8400 anchors
2. **Class Selection**: Find highest scoring class per anchor
3. **Sigmoid Activation**: Convert raw scores to confidence (0-1)
4. **Coordinate Conversion**: Center format → Corner format (x1,y1,x2,y2)
5. **Confidence Filtering**: Remove detections below threshold (**0.5**)
6. **Coordinate Scaling**: Scale from 640x640 to original image size
7. **NMS (Non-Maximum Suppression)**: Remove overlapping detections (IoU > **0.3**)

### 🚀 Inference Pipeline
1. **Load Image** → Decode image file
2. **Preprocess** → Resize to 640x640, normalize, convert to tensor
3. **Run Model** → ONNX Runtime inference
4. **Post-process** → Apply sigmoid, NMS, coordinate scaling
5. **Return Results** → List of Detection objects with bounding boxes

### 🔧 Technical Implementation
- **Runtime**: ONNX Runtime Mobile (CPU optimized)
- **Optimization**: Basic graph optimization for opset 13 compatibility
- **Memory Management**: Proper tensor cleanup to prevent memory leaks
- **Error Handling**: Comprehensive error handling with detailed logging
- **Platform**: Android-focused (no web dependencies)

### 📝 Model Training Details
- **Architecture**: YOLOv8n/s/m (exact variant depends on model size)
- **Training Data**: Custom dataset with FireExtinguisher, ToolBox, OxygenTank
- **Image Size**: 640x640 training resolution
- **Augmentations**: Standard YOLOv8 augmentations (rotation, scaling, etc.)
- **Export Command**: `model.export(format="onnx", opset=13)`

### 🎛️ Configurable Parameters
- **Confidence Threshold**: **0.5** (adjustable in code)
- **IoU Threshold**: **0.3** (for NMS)
- **Input Size**: 640x640 (fixed by model)
- **Max Detections**: **10** (limited for performance)

### 🐛 Common Issues & Solutions
1. **No Detections**: Check confidence threshold, ensure proper preprocessing
2. **Wrong Coordinates**: Verify coordinate scaling from 640x640 to original size
3. **Memory Issues**: Ensure proper tensor cleanup after inference
4. **Model Loading**: Verify `best.onnx` is in `assets/` and added to `pubspec.yaml`
5. **Performance**: Use CPU optimization for opset 13 compatibility
6. **Too Many Detections**: Increase confidence threshold or reduce max detections limit

### 📊 Expected Performance
- **Inference Time**: ~200-500ms on mobile CPU
- **Memory Usage**: ~200-300MB during inference
- **Accuracy**: 94.5%
- **Supported Formats**: JPEG, PNG, WebP images
- **Detection Quality**: High-confidence detections (>50%) with aggressive NMS filtering

### 🎯 Detection Quality Improvements
- **Higher Precision**: Only objects with >50% confidence are detected
- **Reduced False Positives**: Aggressive NMS removes duplicate detections
- **Size Filtering**: Minimum 10px width/height requirement
- **Coordinate Validation**: Ensures all detections are within image bounds
- **Performance Optimized**: Limited to top 10 highest confidence detections

