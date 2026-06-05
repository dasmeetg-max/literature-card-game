// ---------------------------------------------------
// lib/services/wakelock_service.dart
// ---------------------------------------------------
import 'package:wakelock_plus/wakelock_plus.dart';

class WakelockService {
  static Future<void> enable() async {
    try {
      // ✅ NEW: Use wakelock_plus package to handle native screen-on flags
      await WakelockPlus.enable();
    } catch (e) {
      // silently fail on web or if unsupported
    }
  }

  static Future<void> disable() async {
    try {
      await WakelockPlus.disable();
    } catch (e) {
      // silently fail on web or if unsupported
    }
  }
}