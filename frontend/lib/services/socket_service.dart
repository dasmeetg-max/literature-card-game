// ---------------------------------------------------
// lib/services/socket_service.dart
// ---------------------------------------------------
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SocketService {
  // Singleton pattern so the exact same connection is shared across all screens
  static final SocketService _instance = SocketService._internal();
  static SocketService get instance => _instance;
  SocketService._internal();

  bool _isInitialized = false;
  late io.Socket socket;

  // A callback triggered immediately when the socket successfully connects/reconnects
  void Function()? onReconnected;

  Future<void> saveSession(String name, String code) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('playerName', name);
      await prefs.setString('roomCode', code);
      debugPrint('💾 Session saved: $name in room $code');
    } catch (e) {
      debugPrint('⚠️ Failed to save session: $e');
    }
  }

  Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('playerName');
      await prefs.remove('roomCode');
      debugPrint('🧹 Session cleared');
    } catch (e) {
      debugPrint('⚠️ Failed to clear session: $e');
    }
  }

  void connectToServer(String serverUrl) {
    // ✅ CRITICAL BUG FIX: Prevent overwriting an active socket which destroys listeners
    if (_isInitialized && socket.connected) {
      debugPrint(
          '⚡ Socket already initialized and connected, skipping duplicate connect.');
      return;
    }

    _isInitialized = true;

    socket = io.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'reconnection': true,
      'reconnectionAttempts': double.infinity,
      'reconnectionDelay': 1000,
    });

    socket.connect();

    socket.onConnect((_) async {
      debugPrint('✅ Connected to Socket.IO Server');

      try {
        final prefs = await SharedPreferences.getInstance();
        final name = prefs.getString('playerName');
        final code = prefs.getString('roomCode');

        if (name != null && code != null) {
          debugPrint('🔄 Auto-rejoining room $code as $name');
          socket.emit('joinRoom', {'name': name, 'room': code});
        }
      } catch (e) {
        debugPrint('⚠️ Failed to load session on connect: $e');
      }

      if (onReconnected != null) {
        onReconnected!();
      }
    });

    socket.onDisconnect((_) {
      debugPrint('❌ Disconnected from Server');
    });

    socket.onError((data) {
      debugPrint('⚠️ Socket Error: $data');
    });
  }

  /// Reconnects the **existing** socket without creating a new one.
  void reconnectExisting() {
    if (_isInitialized && !socket.connected) {
      debugPrint('🔄 [SOCKET] Reconnecting existing socket...');
      socket.connect();
    }
  }

  void emit(String event, [dynamic data]) {
    debugPrint('📤 [SOCKET EMIT] $event | Payload: $data');
    if (_isInitialized) socket.emit(event, data);
  }

  void on(String event, Function(dynamic) callback) {
    if (!_isInitialized) return;
    socket.on(event, (data) {
      debugPrint('📥 [SOCKET RECV] $event | Payload: $data');
      dynamic payload = data;
      if (data is List && data.length == 2 && data[1] is String) {
        payload = data[0];
      }
      callback(payload);
    });
  }

  void off(String event) {
    if (_isInitialized) socket.off(event);
  }

  void disconnect() {
    if (_isInitialized) socket.disconnect();
  }
}
