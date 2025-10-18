import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  static SettingsService get instance => _instance;
  SettingsService._internal();

  SharedPreferences? _prefs;
  
  // Default settings
  double _confidenceThreshold = 0.5;
  Map<String, bool> _enabledObjects = {
    'OxygenTank': true,
    'NitrogenTank': true,
    'FirstAidBox': true,
    'FireAlarm': true,
    'SafetySwitchPanel': true,
    'EmergencyPhone': true,
    'FireExtinguisher': true,
  };

  // Getters
  double get confidenceThreshold => _confidenceThreshold;
  Map<String, bool> get enabledObjects => Map.from(_enabledObjects);

  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadSettings();
      developer.log('⚙️ Settings service initialized successfully');
    } catch (e) {
      developer.log('❌ Settings initialization failed: $e');
      // Use defaults if initialization fails
    }
  }

  Future<void> _loadSettings() async {
    if (_prefs == null) return;
    
    // Load confidence threshold
    _confidenceThreshold = _prefs!.getDouble('confidence_threshold') ?? 0.5;
    
    // Load enabled objects
    for (final key in _enabledObjects.keys) {
      _enabledObjects[key] = _prefs!.getBool('enabled_$key') ?? true;
    }
    
    developer.log('📋 Settings loaded: confidence=${(_confidenceThreshold * 100).toInt()}%, objects=$_enabledObjects');
  }

  Future<void> setConfidenceThreshold(double threshold) async {
    _confidenceThreshold = threshold.clamp(0.0, 1.0);
    await _prefs?.setDouble('confidence_threshold', _confidenceThreshold);
    developer.log('💾 Confidence threshold saved: ${(_confidenceThreshold * 100).toInt()}%');
  }

  Future<void> setObjectEnabled(String objectName, bool enabled) async {
    if (_enabledObjects.containsKey(objectName)) {
      _enabledObjects[objectName] = enabled;
      await _prefs?.setBool('enabled_$objectName', enabled);
      developer.log('💾 Object setting saved: $objectName = $enabled');
    }
  }

  Future<void> resetToDefaults() async {
    _confidenceThreshold = 0.5;
    _enabledObjects = {
      'OxygenTank': true,
      'NitrogenTank': true,
      'FirstAidBox': true,
      'FireAlarm': true,
      'SafetySwitchPanel': true,
      'EmergencyPhone': true,
      'FireExtinguisher': true,
    };

    // Clear all settings from preferences
    await _prefs?.remove('confidence_threshold');
    for (final key in _enabledObjects.keys) {
      await _prefs?.remove('enabled_$key');
    }

    developer.log('🔄 Settings reset to defaults');
  }

  // Helper methods for UI
  String getDisplayName(String objectName) {
    switch (objectName) {
      case 'OxygenTank':
        return 'Oxygen Tank';
      case 'NitrogenTank':
        return 'Nitrogen Tank';
      case 'FirstAidBox':
        return 'First Aid Box';
      case 'FireAlarm':
        return 'Fire Alarm';
      case 'SafetySwitchPanel':
        return 'Safety Switch Panel';
      case 'EmergencyPhone':
        return 'Emergency Phone';
      case 'FireExtinguisher':
        return 'Fire Extinguisher';
      default:
        return objectName;
    }
  }

  String getObjectIcon(String objectName) {
    switch (objectName) {
      case 'OxygenTank':
        return '🫁';
      case 'NitrogenTank':
        return '💨';
      case 'FirstAidBox':
        return '🏥';
      case 'FireAlarm':
        return '🚨';
      case 'SafetySwitchPanel':
        return '⚡';
      case 'EmergencyPhone':
        return '📞';
      case 'FireExtinguisher':
        return '🧯';
      default:
        return '📦';
    }
  }
}
