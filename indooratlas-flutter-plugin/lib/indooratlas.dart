// lib/indooratlas.dart
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

// ----------------- Models -----------------

/// Represents a geographic coordinate (latitude, longitude)
class IACoordinate {
  final double latitude, longitude;
  
  const IACoordinate(this.latitude, this.longitude);
  const IACoordinate.zero() : latitude = 0, longitude = 0;
  
  @override
  String toString() => 'IACoordinate(lat: $latitude, lon: $longitude)';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is IACoordinate &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }
  
  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;
}

/// Represents a point in pixel coordinates
class IAPoint {
  final double x, y;
  
  const IAPoint(this.x, this.y);
  const IAPoint.zero() : x = 0, y = 0;
  
  @override
  String toString() => 'IAPoint(x: $x, y: $y)';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is IAPoint && other.x == x && other.y == y;
  }
  
  @override
  int get hashCode => x.hashCode ^ y.hashCode;
}

/// Represents a floorplan with all its properties and coordinate transformations
class IAFloorplan {
  final String id;
  final String name;
  final String url;
  final int floor;
  final double bearing;
  final int bitmapWidth;
  final int bitmapHeight;
  final double widthMeters;
  final double heightMeters;
  final double metersToPixels;
  final double pixelsToMeters;
  final IACoordinate bottomLeft;
  final IACoordinate bottomRight;
  final IACoordinate center;
  final IACoordinate topLeft;
  final IACoordinate topRight;

  const IAFloorplan({
    required this.id,
    required this.name,
    required this.url,
    required this.floor,
    required this.bearing,
    required this.bitmapWidth,
    required this.bitmapHeight,
    required this.widthMeters,
    required this.heightMeters,
    required this.metersToPixels,
    required this.pixelsToMeters,
    required this.bottomLeft,
    required this.bottomRight,
    required this.center,
    required this.topLeft,
    required this.topRight,
  });

  factory IAFloorplan.fromMap(Map<String, dynamic> map) {
    return IAFloorplan(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      url: map['url'] as String? ?? '',
      floor: map['floorLevel'] as int? ?? 0,
      bearing: (map['bearing'] as num?)?.toDouble() ?? 0.0,
      bitmapWidth: map['bitmapWidth'] as int? ?? 0,
      bitmapHeight: map['bitmapHeight'] as int? ?? 0,
      widthMeters: (map['widthMeters'] as num?)?.toDouble() ?? 0.0,
      heightMeters: (map['heightMeters'] as num?)?.toDouble() ?? 0.0,
      metersToPixels: (map['metersToPixels'] as num?)?.toDouble() ?? 0.0,
      pixelsToMeters: (map['pixelsToMeters'] as num?)?.toDouble() ?? 0.0,
      bottomLeft: _parseCoordinate(map['bottomLeft']),
      bottomRight: _parseCoordinate(map['bottomRight']),
      center: _parseCoordinate(map['center']),
      topLeft: _parseCoordinate(map['topLeft']),
      topRight: _parseCoordinate(map['topRight']),
    );
  }

  static IACoordinate _parseCoordinate(dynamic coord) {
    if (coord is List && coord.length >= 2) {
      return IACoordinate(
        (coord[1] as num?)?.toDouble() ?? 0.0, // latitude
        (coord[0] as num?)?.toDouble() ?? 0.0, // longitude
      );
    }
    return const IACoordinate.zero();
  }

  @override
  String toString() => 'IAFloorplan(id: $id, name: $name, floor: $floor)';
}

/// Represents a location with positioning information
class IALocation extends IACoordinate {
  final IAPoint? pixel;
  final IAFloorplan? floorplan;
  final double accuracy;
  final double heading;
  final double altitude;
  final int floor;
  final double floorCertainty;
  final double velocity;
  final DateTime timestamp;

  const IALocation({
    required double latitude,
    required double longitude,
    this.pixel,
    this.floorplan,
    this.accuracy = 0,
    this.heading = 0,
    this.altitude = 0,
    this.floor = 0,
    this.floorCertainty = 0,
    this.velocity = 0,
    required this.timestamp,
  }) : super(latitude, longitude);

  factory IALocation.fromMap(Map<String, dynamic> map) {
    IAPoint? pixel;
    if (map.containsKey('pix_x') && map.containsKey('pix_y')) {
      final dx = (map['pix_x'] as num?)?.toDouble() ?? 0.0;
      final dy = (map['pix_y'] as num?)?.toDouble() ?? 0.0;
      pixel = IAPoint(dx, dy);
    }

    IAFloorplan? floorplan;
    if (map.containsKey('region') && 
        map['region'] is Map && 
        (map['region'] as Map).containsKey('floorPlan')) {
      try {
        floorplan = IAFloorplan.fromMap(
          (map['region'] as Map)['floorPlan'] as Map<String, dynamic>
        );
      } catch (e) {
        debugPrint('Error parsing floorplan from region: $e');
      }
    } else if (map.containsKey('floorPlan')) {
      try {
        floorplan = IAFloorplan.fromMap(map['floorPlan'] as Map<String, dynamic>);
      } catch (e) {
        debugPrint('Error parsing floorplan: $e');
      }
    }

    return IALocation(
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      pixel: pixel,
      floorplan: floorplan,
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0.0,
      heading: (map['heading'] as num?)?.toDouble() ?? 0.0,
      altitude: (map['altitude'] as num?)?.toDouble() ?? 0.0,
      floor: map['flr'] as int? ?? 0,
      floorCertainty: (map['floorCertainty'] as num?)?.toDouble() ?? 0.0,
      velocity: (map['velocity'] as num?)?.toDouble() ?? 0.0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch
      ),
    );
  }

  /// Creates a copy of this location with updated heading
  IALocation copyWithHeading(double newHeading) {
    return IALocation(
      latitude: latitude,
      longitude: longitude,
      pixel: pixel,
      floorplan: floorplan,
      accuracy: accuracy,
      heading: newHeading,
      altitude: altitude,
      floor: floor,
      floorCertainty: floorCertainty,
      velocity: velocity,
      timestamp: timestamp,
    );
  }

  @override
  String toString() => 'IALocation(lat: $latitude, lon: $longitude, floor: $floor, accuracy: $accuracy)';
}

/// Represents a geofence area
class IAGeofence {
  final String id;
  final String name;
  final int floor;
  final String? payload;
  final List<IACoordinate> coordinates;

  const IAGeofence({
    required this.id,
    required this.name,
    required this.floor,
    this.payload,
    required this.coordinates,
  });

  factory IAGeofence.fromMap(Map<String, dynamic> map) {
    final geometry = map['geometry'] as Map<String, dynamic>? ?? {};
    final coords = (geometry['coordinates'] as List?)?.first as List? ?? [];

    final coordinates = coords.map<IACoordinate>((coord) {
      if (coord is List && coord.length >= 2) {
        return IACoordinate(
          (coord[1] as num).toDouble(), // latitude
          (coord[0] as num).toDouble(), // longitude
        );
      }
      return const IACoordinate.zero();
    }).toList();

    final properties = map['properties'] as Map<String, dynamic>? ?? {};

    return IAGeofence(
      id: map['id'] as String? ?? '',
      name: properties['name'] as String? ?? '',
      floor: properties['floor'] as int? ?? 0,
      payload: properties['payload']?.toString(),
      coordinates: coordinates,
    );
  }

  @override
  String toString() => 'IAGeofence(id: $id, name: $name, floor: $floor)';
}

// ----------------- Wayfinding Models -----------------

/// Represents a point in a route
class IARoutePoint {
  final double latitude;
  final double longitude;
  final int floor;
  
  const IARoutePoint(this.latitude, this.longitude, this.floor);
  
  factory IARoutePoint.fromMap(Map<String, dynamic> map) {
    return IARoutePoint(
      (map['latitude'] as num?)?.toDouble() ?? 0.0,
      (map['longitude'] as num?)?.toDouble() ?? 0.0,
      map['floor'] as int? ?? 0,
    );
  }

  @override
  String toString() => 'IARoutePoint(lat: $latitude, lon: $longitude, floor: $floor)';
}

/// Represents a segment of a route
class IARouteLeg {
  final IARoutePoint begin;
  final IARoutePoint end;
  final double length;
  final double direction;
  final int edgeIndex;

  const IARouteLeg({
    required this.begin,
    required this.end,
    required this.length,
    required this.direction,
    required this.edgeIndex,
  });

  factory IARouteLeg.fromMap(Map<String, dynamic> map) {
    return IARouteLeg(
      begin: IARoutePoint.fromMap(map['begin'] as Map<String, dynamic>? ?? {}),
      end: IARoutePoint.fromMap(map['end'] as Map<String, dynamic>? ?? {}),
      length: (map['length'] as num?)?.toDouble() ?? 0.0,
      direction: (map['direction'] as num?)?.toDouble() ?? 0.0,
      edgeIndex: map['edgeIndex'] as int? ?? -1,
    );
  }

  @override
  String toString() => 'IARouteLeg(length: $length, direction: $direction)';
}

/// Represents a complete route with all its segments
class IARoute {
  final List<IARouteLeg> legs;
  final String error;
  
  const IARoute(this.legs, this.error);
  
  factory IARoute.fromMap(Map<String, dynamic> map) {
    final legsList = map['legs'] as List? ?? [];
    final legs = legsList
        .map((e) => IARouteLeg.fromMap(e as Map<String, dynamic>))
        .toList();
    return IARoute(legs, map['error'] as String? ?? '');
  }

  /// Returns true if the route has an error
  bool get hasError => error.isNotEmpty;

  /// Returns the total length of the route
  double get totalLength => legs.fold(0.0, (sum, leg) => sum + leg.length);

  @override
  String toString() => 'IARoute(legs: ${legs.length}, error: $error)';
}

/// Status of the IndoorAtlas service
enum IAStatus { 
  outOfService, 
  temporarilyUnavailable, 
  available, 
  limited 
}

// ----------------- Main IndoorAtlas class -----------------

/// Main class for IndoorAtlas functionality
class IndoorAtlas {
  static const MethodChannel _channel = MethodChannel('com.indooratlas.flutter');
  static bool debugEnabled = false;

  // Internal state
  static IAFloorplan? _currentFloorplan;
  static IALocation? _currentLocation;
  static String? _traceId;
  static final Set<IAListener> _listeners = <IAListener>{};
  static final Set<IAGeofence> _currentGeofences = <IAGeofence>{};
  static final Set<String> _triggeredGeofenceIds = <String>{};
  static IACoordinate? _currentDestination;

  /// Current destination for wayfinding
  static IACoordinate? get currentDestination => _currentDestination;

  /// Current location
  static IALocation? get location => _currentLocation;

  /// Current floorplan
  static IAFloorplan? get floorplan => _currentFloorplan;

  /// Current trace ID
  static String? get traceId => _traceId;

  /// Current geofences
  static List<IAGeofence> get geofences => _currentGeofences.toList();

  /// Currently triggered geofences
  static List<IAGeofence> get triggeredGeofences => 
      _currentGeofences.where((g) => _triggeredGeofenceIds.contains(g.id)).toList();

  // Initialize the method call handler
  static void _ensureHandler() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static Future<void> _handleMethodCall(MethodCall call) async {
    try {
      switch (call.method) {
        case 'onStatusChanged':
          final args = call.arguments as List;
          final statusIndex = args[0] as int;
          final status = IAStatus.values[statusIndex.clamp(0, IAStatus.values.length - 1)];
          for (final listener in _listeners) {
            listener.onStatus(status, '');
          }
          break;

        case 'onLocationChanged':
          final args = call.arguments as List;
          final map = args[0] as Map<String, dynamic>;
          final location = IALocation.fromMap(map);
          _currentLocation = location;
          _updateGeofenceState(location);
          for (final listener in _listeners) {
            listener.onLocation(location);
          }
          break;

        case 'onEnterRegion':
          final args = call.arguments as List;
          final map = args[0] as Map<String, dynamic>;
          if (map.containsKey('floorPlan')) {
            _currentFloorplan = IAFloorplan.fromMap(map['floorPlan'] as Map<String, dynamic>);
            for (final listener in _listeners) {
              listener.onFloorplan(true, _currentFloorplan!);
            }
          }
          break;

        case 'onExitRegion':
          final args = call.arguments as List;
          final map = args[0] as Map<String, dynamic>;
          if (map.containsKey('floorPlan')) {
            final floorplan = IAFloorplan.fromMap(map['floorPlan'] as Map<String, dynamic>);
            for (final listener in _listeners) {
              listener.onFloorplan(false, floorplan);
            }
            _currentFloorplan = null;
          }
          break;

        case 'onOrientationChanged':
          final args = call.arguments as List;
          final x = (args[1] as num).toDouble();
          final y = (args[2] as num).toDouble();
          final z = (args[3] as num).toDouble();
          final w = (args[4] as num).toDouble();
          for (final listener in _listeners) {
            listener.onOrientation(x, y, z, w);
          }
          break;

        case 'onHeadingChanged':
          final args = call.arguments as List;
          final heading = (args[1] as num).toDouble();
          for (final listener in _listeners) {
            listener.onHeading(heading);
          }
          break;

        case 'onGeofencesTriggered':
          final args = call.arguments as List;
          final geofenceMaps = (args[1] as List).cast<Map<String, dynamic>>();
          _currentGeofences.clear();
          for (final geofenceMap in geofenceMaps) {
            final geofence = IAGeofence.fromMap(geofenceMap);
            _currentGeofences.add(geofence);
          }
          for (final listener in _listeners) {
            listener.onGeofences(_currentGeofences.toList());
          }
          break;

        case 'onGeofenceEvent':
          final args = call.arguments as List;
          final geofenceId = args[0] as String;
          final eventType = args[1] as String;
          
          if (eventType == "ENTER") {
            _triggeredGeofenceIds.add(geofenceId);
          } else if (eventType == "EXIT") {
            _triggeredGeofenceIds.remove(geofenceId);
          }
          
          for (final listener in _listeners) {
            listener.onGeofenceEvent(geofenceId, eventType);
          }
          break;

        case 'onWayfindingUpdate':
          final args = call.arguments as List;
          final map = args[0] as Map<String, dynamic>;
          final route = IARoute.fromMap(map);
          for (final listener in _listeners) {
            listener.onWayfindingUpdate(route);
          }
          break;

        default:
          if (debugEnabled) {
            debugPrint('Unhandled method: ${call.method}');
          }
      }
    } catch (e, stackTrace) {
      if (debugEnabled) {
        debugPrint('Error handling method ${call.method}: $e\n$stackTrace');
      }
    }
  }

  /// Updates geofence state based on current location
  static void _updateGeofenceState(IALocation location) {
    if (_currentGeofences.isEmpty) return;

    final newTriggeredIds = <String>{};
    for (final geofence in _currentGeofences) {
      if (_isLocationInGeofence(location, geofence)) {
        newTriggeredIds.add(geofence.id);
      }
    }

    final previousTriggered = Set<String>.from(_triggeredGeofenceIds);
    _triggeredGeofenceIds
      ..clear()
      ..addAll(newTriggeredIds);

    for (final geofenceId in _currentGeofences.map((g) => g.id)) {
      final wasTriggered = previousTriggered.contains(geofenceId);
      final isNowTriggered = newTriggeredIds.contains(geofenceId);

      if (wasTriggered != isNowTriggered) {
        final eventType = isNowTriggered ? "ENTER" : "EXIT";
        for (final listener in _listeners) {
          listener.onGeofenceEvent(geofenceId, eventType);
        }
      }
    }
  }

  /// Checks if a location is inside a geofence
  static bool _isLocationInGeofence(IALocation location, IAGeofence geofence) {
    if (geofence.coordinates.isEmpty) return false;
    return _isPointInPolygon(
      IACoordinate(location.latitude, location.longitude), 
      geofence.coordinates
    );
  }

  /// Ray casting algorithm for point in polygon
  static bool _isPointInPolygon(IACoordinate point, List<IACoordinate> polygon) {
    if (polygon.length < 3) return false;

    bool inside = false;
    int j = polygon.length - 1;

    for (int i = 0; i < polygon.length; i++) {
      final xi = polygon[i].latitude;
      final yi = polygon[i].longitude;
      final xj = polygon[j].latitude;
      final yj = polygon[j].longitude;

      if (((xi > point.latitude) != (xj > point.latitude)) &&
          (point.longitude < (yj - yi) * (point.latitude - xi) / (xj - xi) + yi)) {
        inside = !inside;
      }
      j = i;
    }

    return inside;
  }

  // ----------------- Public API Methods -----------------

  /// Initialize IndoorAtlas with API key
  static Future<void> initialize(String pluginVersion, String apiKey, {String endpoint = ''}) async {
    _ensureHandler();
    await _channel.invokeMethod('initialize', [pluginVersion, apiKey, endpoint]);
  }

  /// Request location permissions
  static Future<void> requestPermissions() async {
    await _channel.invokeMethod('requestPermissions');
  }

  /// Start positioning
  static Future<void> startPositioning() async {
    await _channel.invokeMethod('startPositioning');
  }

  /// Stop positioning
  static Future<void> stopPositioning() async {
    await _channel.invokeMethod('stopPositioning');
  }

  /// Set output thresholds for location updates
  static Future<void> setOutputThresholds(double meters, double seconds) async {
    await _channel.invokeMethod('setOutputThresholds', [meters, seconds]);
  }

  /// Set positioning mode
  static Future<void> setPositioningMode(int mode) async {
    await _channel.invokeMethod('setPositioningMode', mode);
  }

  /// Lock positioning to indoors only
  static Future<void> lockIndoors(bool locked) async {
    await _channel.invokeMethod('lockIndoors', locked);
  }

  /// Lock positioning to a specific floor
  static Future<void> lockFloor(int floor) async {
    await _channel.invokeMethod('lockFloor', floor);
  }

  /// Unlock floor (allow automatic floor detection)
  static Future<void> unlockFloor() async {
    await _channel.invokeMethod('unlockFloor');
  }

  /// Set orientation and heading sensitivities
  static Future<void> setSensitivities(double orientationSensitivity, double headingSensitivity) async {
    await _channel.invokeMethod('setSensitivities', [orientationSensitivity, headingSensitivity]);
  }

  /// Get current trace ID
  static Future<String?> getTraceId() async {
    final result = await _channel.invokeMethod<String>('getTraceId');
    _traceId = result;
    return _traceId;
  }

  /// Request monitoring of specific geofences
  static Future<void> requestGeofences(List<String> geofenceIds) async {
    await _channel.invokeMethod('requestGeofences', geofenceIds);
  }

  /// Stop monitoring geofences
  static Future<void> removeGeofences() async {
    await _channel.invokeMethod('removeGeofences');
  }

  /// Get current geofences from the system
  static Future<List<IAGeofence>> getCurrentGeofences() async {
    final result = await _channel.invokeMethod('getCurrentGeofences');
    if (result is List) {
      final geofenceMaps = result.cast<Map<String, dynamic>>();
      return geofenceMaps.map((map) => IAGeofence.fromMap(map)).toList();
    }
    return [];
  }

  /// Check if a specific geofence is triggered
  static bool isGeofenceTriggered(String geofenceId) {
    return _triggeredGeofenceIds.contains(geofenceId);
  }

  /// Set location manually (for testing)
  static Future<void> setLocation(IACoordinate coord, {int floor = 0, double accuracy = 0}) async {
    await _channel.invokeMethod('setLocation', [coord.latitude, coord.longitude, floor, accuracy]);
  }

  // ----------------- Wayfinding Methods -----------------

  /// Start wayfinding to specified destination
  static Future<void> startWayfinding(double lat, double lon, {int floor = 0, int? mode}) async {
    _ensureHandler();
    _currentDestination = IACoordinate(lat, lon);
    
    final args = [lat, lon, floor];
    if (mode != null) args.add(mode);
    
    await _channel.invokeMethod('startWayfinding', args);

    // Notify listeners about new destination
    for (final listener in _listeners) {
      listener.onDestinationSet(_currentDestination);
    }
  }

  /// Stop wayfinding
  static Future<void> stopWayfinding() async {
    _currentDestination = null;
    await _channel.invokeMethod('stopWayfinding');

    for (final listener in _listeners) {
      listener.onDestinationSet(null);
    }
  }

  // ----------------- Listener Management -----------------

  /// Subscribe to IndoorAtlas events
  static void subscribe(IAListener listener) {
    _ensureHandler();
    if (_listeners.contains(listener)) return;
    
    _listeners.add(listener);

    // Send current state to new listener
    if (_currentFloorplan != null) {
      listener.onFloorplan(true, _currentFloorplan!);
    }
    if (_currentLocation != null) {
      listener.onLocation(_currentLocation!);
    }
    if (_currentGeofences.isNotEmpty) {
      listener.onGeofences(_currentGeofences.toList());
    }

    // Send current triggered geofences
    for (final geofenceId in _triggeredGeofenceIds) {
      listener.onGeofenceEvent(geofenceId, "ENTER");
    }

    // Send current destination
    listener.onDestinationSet(_currentDestination);
  }

  /// Unsubscribe from IndoorAtlas events
  static void unsubscribe(IAListener listener) {
    _listeners.remove(listener);
  }
}

// ----------------- Listener Classes -----------------

/// Abstract base class for IndoorAtlas event listeners
abstract class IAListener {
  final UniqueKey key = UniqueKey();
  final String name;
  
  IAListener(this.name);

  /// Called when service status changes
  void onStatus(IAStatus status, String message) {}

  /// Called when location is updated
  void onLocation(IALocation location) {}

  /// Called when entering or exiting a floorplan region
  void onFloorplan(bool enter, IAFloorplan floorplan) {}

  /// Called when device orientation changes
  void onOrientation(double x, double y, double z, double w) {}

  /// Called when heading changes
  void onHeading(double heading) {}

  /// Called when geofences are updated
  void onGeofences(List<IAGeofence> geofences) {}

  /// Called when a geofence event occurs
  void onGeofenceEvent(String geofenceId, String eventType) {}

  /// Called when wayfinding route is updated
  void onWayfindingUpdate(IARoute route) {}

  /// Called when destination is set or cleared
  void onDestinationSet(IACoordinate? destination) {}

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is IAListener && other.key == key;
  }

  @override
  int get hashCode => key.hashCode;
}

/// Callback-based listener implementation
class IACallbackListener extends IAListener {
  final void Function(IAStatus status, String message)? onStatusCallback;
  final void Function(IALocation location)? onLocationCallback;
  final void Function(bool enter, IAFloorplan floorplan)? onFloorplanCallback;
  final void Function(double x, double y, double z, double w)? onOrientationCallback;
  final void Function(double heading)? onHeadingCallback;
  final void Function(List<IAGeofence> geofences)? onGeofencesCallback;
  final void Function(String geofenceId, String eventType)? onGeofenceEventCallback;
  final void Function(IARoute route)? onWayfindingUpdateCallback;
  final void Function(IACoordinate? destination)? onDestinationSetCallback;

  IACallbackListener({
    required String name,
    this.onStatusCallback,
    this.onLocationCallback,
    this.onFloorplanCallback,
    this.onOrientationCallback,
    this.onHeadingCallback,
    this.onGeofencesCallback,
    this.onGeofenceEventCallback,
    this.onWayfindingUpdateCallback,
    this.onDestinationSetCallback,
  }) : super(name);

  @override
  void onStatus(IAStatus status, String message) => onStatusCallback?.call(status, message);

  @override
  void onLocation(IALocation location) => onLocationCallback?.call(location);

  @override
  void onFloorplan(bool enter, IAFloorplan floorplan) => onFloorplanCallback?.call(enter, floorplan);

  @override
  void onOrientation(double x, double y, double z, double w) => onOrientationCallback?.call(x, y, z, w);

  @override
  void onHeading(double heading) => onHeadingCallback?.call(heading);

  @override
  void onGeofences(List<IAGeofence> geofences) => onGeofencesCallback?.call(geofences);

  @override
  void onGeofenceEvent(String geofenceId, String eventType) => onGeofenceEventCallback?.call(geofenceId, eventType);

  @override
  void onWayfindingUpdate(IARoute route) => onWayfindingUpdateCallback?.call(route);

  @override
  void onDestinationSet(IACoordinate? destination) => onDestinationSetCallback?.call(destination);
}

/// Widget that automatically subscribes/unsubscribes to IndoorAtlas events
class IndoorAtlasListener extends StatefulWidget {
  final Widget child;
  final IACallbackListener listener;
  final bool enabled;

  IndoorAtlasListener({
    Key? key,
    required String name,
    this.enabled = true,
    this.child = const SizedBox.shrink(),
    void Function(IAStatus status, String message)? onStatus,
    void Function(IALocation location)? onLocation,
    void Function(bool enter, IAFloorplan floorplan)? onFloorplan,
    void Function(double x, double y, double z, double w)? onOrientation,
    void Function(double heading)? onHeading,
    void Function(List<IAGeofence> geofences)? onGeofences,
    void Function(String geofenceId, String eventType)? onGeofenceEvent,
    void Function(IARoute route)? onWayfindingUpdate,
    void Function(IACoordinate? destination)? onDestinationSet,
  })  : listener = IACallbackListener(
          name: name,
          onStatusCallback: onStatus,
          onLocationCallback: onLocation,
          onFloorplanCallback: onFloorplan,
          onOrientationCallback: onOrientation,
          onHeadingCallback: onHeading,
          onGeofencesCallback: onGeofences,
          onGeofenceEventCallback: onGeofenceEvent,
          onWayfindingUpdateCallback: onWayfindingUpdate,
          onDestinationSetCallback: onDestinationSet,
        ),
        super(key: key);

  @override
  State<IndoorAtlasListener> createState() => _IndoorAtlasListenerState();
}

class _IndoorAtlasListenerState extends State<IndoorAtlasListener> {
  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      IndoorAtlas.subscribe(widget.listener);
    }
  }

  @override
  void didUpdateWidget(covariant IndoorAtlasListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.enabled && !widget.enabled) {
      IndoorAtlas.unsubscribe(oldWidget.listener);
    } else if (!oldWidget.enabled && widget.enabled) {
      IndoorAtlas.subscribe(widget.listener);
    } else if (widget.enabled && oldWidget.listener != widget.listener) {
      IndoorAtlas.unsubscribe(oldWidget.listener);
      IndoorAtlas.subscribe(widget.listener);
    }
  }

  @override
  void dispose() {
    if (widget.enabled) {
      IndoorAtlas.unsubscribe(widget.listener);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}