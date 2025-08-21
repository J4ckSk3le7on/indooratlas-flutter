import 'dart:async';
import 'package:flutter/services.dart';

class IALocation {
  final double latitude, longitude, accuracy;
  final int floorLevel, timestamp;

  IALocation(this.latitude, this.longitude, this.accuracy, this.floorLevel, this.timestamp);

  factory IALocation.fromMap(Map m) => IALocation(
        (m['latitude'] ?? 0).toDouble(),
        (m['longitude'] ?? 0).toDouble(),
        (m['accuracy'] ?? 0).toDouble(),
        (m['floorLevel'] ?? 0).toInt(),
        (m['timestamp'] ?? 0).toInt(),
      );
}

enum IAStatus { outOfService, temporarilyUnavailable, available, limited }

final _channel = MethodChannel('com.indooratlas.flutter');

// Streams for Dart events
final _statusStream = EventChannel('com.indooratlas.flutter/events/status');
Stream<IAStatus> get statusStream =>
    _statusStream.receiveBroadcastStream().map((e) {
      final m = Map<String, dynamic>.from(e);
      return IAStatus.values[m['status'] ?? 0];
    });

final _locationStream = EventChannel('com.indooratlas.flutter/events/location');
Stream<IALocation> get locationStream =>
    _locationStream.receiveBroadcastStream().map((e) => IALocation.fromMap(Map<String, dynamic>.from(e)));

final _regionStream = EventChannel('com.indooratlas.flutter/events/region');
Stream<bool> get regionEnterStream =>
    _regionStream.receiveBroadcastStream().map((e) {
      final m = Map<String, dynamic>.from(e);
      return m['enter'] as bool? ?? false;
    });

// API
class IndoorAtlas {
  static Future<void> initialize({required String apiKey, required String apiSecret}) async {
    await _channel.invokeMethod('initialize', {'apiKey': apiKey, 'apiSecret': apiSecret});
  }

  static Future<void> startPositioning() async {
    await _channel.invokeMethod('startPositioning');
  }

  static Future<void> stopPositioning() async {
    await _channel.invokeMethod('stopPositioning');
  }
}
