// lib/indoor_atlas_bridge.dart
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

// ----------------- Models -----------------
class IACoordinate {
  final double latitude, longitude;
  const IACoordinate(this.latitude, this.longitude);
  const IACoordinate.zero() : latitude = 0, longitude = 0;
}

class IAPoint {
  final double x, y;
  const IAPoint(this.x, this.y);
  const IAPoint.zero() : x = 0, y = 0;
}

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

  IAFloorplan({
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

  factory IAFloorplan.fromMap(Map map) {
    return IAFloorplan(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      url: map['url'] ?? '',
      floor: map['floorLevel'] ?? 0,
      bearing: (map['bearing'] ?? 0).toDouble(),
      bitmapWidth: (map['bitmapWidth'] ?? 0),
      bitmapHeight: (map['bitmapHeight'] ?? 0),
      widthMeters: (map['widthMeters'] ?? 0).toDouble(),
      heightMeters: (map['heightMeters'] ?? 0).toDouble(),
      metersToPixels: (map['metersToPixels'] ?? 0).toDouble(),
      pixelsToMeters: (map['pixelsToMeters'] ?? 0).toDouble(),
      bottomLeft: IACoordinate((map['bottomLeft'][1] ?? 0).toDouble(), (map['bottomLeft'][0] ?? 0).toDouble()),
      bottomRight: IACoordinate((map['bottomRight'][1] ?? 0).toDouble(), (map['bottomRight'][0] ?? 0).toDouble()),
      center: IACoordinate((map['center'][1] ?? 0).toDouble(), (map['center'][0] ?? 0).toDouble()),
      topLeft: IACoordinate((map['topLeft'][1] ?? 0).toDouble(), (map['topLeft'][0] ?? 0).toDouble()),
      topRight: IACoordinate((map['topRight'][1] ?? 0).toDouble(), (map['topRight'][0] ?? 0).toDouble()),
    );
  }
}

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

  IALocation({
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

  factory IALocation.fromMap(Map map) {
    IAPoint? p;
    if (map.containsKey('pix_x') && map.containsKey('pix_y')) {
      final dx = (map['pix_x'] as num).toDouble();
      final dy = (map['pix_y'] as num).toDouble();
      p = IAPoint(dx, dy);
    }

    IAFloorplan? fp;
    if (map.containsKey('region') && (map['region'] as Map).containsKey('floorPlan')) {
      try {
        fp = IAFloorplan.fromMap((map['region'] as Map)['floorPlan']);
      } catch (_) {}
    } else if (map.containsKey('floorPlan')) {
      fp = IAFloorplan.fromMap(map['floorPlan']);
    }

    return IALocation(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      pixel: p,
      floorplan: fp,
      accuracy: (map['accuracy'] ?? 0).toDouble(),
      heading: (map['heading'] ?? 0).toDouble(),
      altitude: (map['altitude'] ?? 0).toDouble(),
      floor: (map['flr'] ?? 0),
      floorCertainty: (map['floorCertainty'] ?? 0).toDouble(),
      velocity: (map['velocity'] ?? 0).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch((map['timestamp'] ?? DateTime.now().millisecondsSinceEpoch)),
    );
  }

  /// helper to create a copy with updated heading
  IALocation copyWithHeading(double h) {
    return IALocation(
      latitude: latitude,
      longitude: longitude,
      pixel: pixel,
      floorplan: floorplan,
      accuracy: accuracy,
      heading: h,
      altitude: altitude,
      floor: floor,
      floorCertainty: floorCertainty,
      velocity: velocity,
      timestamp: timestamp,
    );
  }
}

class IAGeofence {
  final String id;
  final String name;
  final int floor;
  final String? payload;
  final List<IACoordinate> coordinates;

  IAGeofence({
    required this.id,
    required this.name,
    required this.floor,
    this.payload,
    required this.coordinates,
  });

  factory IAGeofence.fromMap(Map map) {
    final geometry = map['geometry'] as Map;
    final coords = (geometry['coordinates'] as List).first as List;
    
    final coordinates = coords.map((coord) {
      return IACoordinate(
        (coord[1] as num).toDouble(), // latitud
        (coord[0] as num).toDouble(), // longitud
      );
    }).toList();

    return IAGeofence(
      id: map['id'] ?? '',
      name: (map['properties'] as Map)['name'] ?? '',
      floor: (map['properties'] as Map)['floor'] ?? 0,
      payload: (map['properties'] as Map)['payload'],
      coordinates: coordinates,
    );
  }
}

// Minimal status enum
enum IAStatus { outOfService, temporarilyUnavailable, available, limited }

// ----------------- MethodChannel bridge -----------------
class IndoorAtlas {
  static const MethodChannel _ch = MethodChannel('com.indooratlas.flutter');
  static bool debugEnabled = false;

  // internal state
  static IAFloorplan? _currentFloorplan;
  static IALocation? _currentLocation;
  static String? _traceId;
  static final Set<IAListener> _listeners = Set.identity();
  static final Set<IAGeofence> _currentGeofences = Set.identity();

  // initialize channel handler
  static void _ensureHandler() {
    _ch.setMethodCallHandler((call) async {
      try {
        switch (call.method) {
          case 'onStatusChanged':
            final int code = (call.arguments as List).first as int;
            for (var l in _listeners) l.onStatus(IAStatus.values[code], '');
            break;
          case 'onLocationChanged':
            final Map map = (call.arguments as List).first as Map;
            final loc = IALocation.fromMap(map);
            _currentLocation = loc;
            for (var l in _listeners) l.onLocation(loc);
            break;
          case 'onEnterRegion':
            final Map map = (call.arguments as List).first as Map;
            // if contains floorPlan, notify floorplan enter
            if (map.containsKey('floorPlan')) {
              _currentFloorplan = IAFloorplan.fromMap(map['floorPlan']);
              for (var l in _listeners) l.onFloorplan(true, _currentFloorplan!);
            }
            break;
          case 'onExitRegion':
            final Map map = (call.arguments as List).first as Map;
            if (map.containsKey('floorPlan')) {
              final fp = IAFloorplan.fromMap(map['floorPlan']);
              for (var l in _listeners) l.onFloorplan(false, fp);
              _currentFloorplan = null;
            }
            break;
          case 'onOrientationChanged':
            final args = call.arguments as List;
            // timestamp, x,y,z,w
            for (var l in _listeners) l.onOrientation(args[1], args[2], args[3], args[4]);
            break;
          case 'onHeadingChanged':
            final args = call.arguments as List;
            final heading = (args[1] as num).toDouble();
            for (var l in _listeners) l.onHeading(heading);
            break;
          case 'onGeofencesTriggered':
            final args = call.arguments as List;
            // final timestamp = (args[0] as num).toInt(); // Timestamp disponible si se necesita
            final geofenceMaps = (args[1] as List).cast<Map>();
            
            // Actualizar las geofences actuales
            _currentGeofences.clear();
            for (final geofenceMap in geofenceMaps) {
              final geofence = IAGeofence.fromMap(geofenceMap);
              _currentGeofences.add(geofence);
            }
            
            // Notificar a todos los listeners
            for (var l in _listeners) l.onGeofences(_currentGeofences.toList());
            break;
          default:
            if (debugEnabled) debugPrint('Unhandled method ${call.method}');
        }
      } catch (e, st) {
        if (debugEnabled) debugPrint('Error handling method ${call.method}: $e\n$st');
      }
    });
  }

  // ----------------- Native commands -----------------
  static Future<void> initialize(String pluginVersion, String apiKey, {String endpoint = ''}) async {
    _ensureHandler();
    await _ch.invokeMethod('initialize', [pluginVersion, apiKey, endpoint]);
  }

  static Future<void> requestPermissions() async {
    await _ch.invokeMethod('requestPermissions');
  }

  static Future<void> startPositioning() async {
    await _ch.invokeMethod('startPositioning');
  }

  static Future<void> stopPositioning() async {
    await _ch.invokeMethod('stopPositioning');
  }

  static Future<void> setOutputThresholds(double meters, double seconds) async {
    await _ch.invokeMethod('setOutputThresholds', [meters, seconds]);
  }

  static Future<void> setPositioningMode(int idx) async {
    await _ch.invokeMethod('setPositioningMode', idx);
  }

  static Future<void> lockIndoors(bool locked) async {
    await _ch.invokeMethod('lockIndoors', locked);
  }

  static Future<void> lockFloor(int floor) async {
    await _ch.invokeMethod('lockFloor', floor);
  }

  static Future<void> unlockFloor() async {
    await _ch.invokeMethod('unlockFloor');
  }

  static Future<void> setSensitivities(double orientationSensitivity, double headingSensitivity) async {
    await _ch.invokeMethod('setSensitivities', [orientationSensitivity, headingSensitivity]);
  }

  static Future<String?> getTraceId() async {
    final r = await _ch.invokeMethod('getTraceId');
    _traceId = r as String?;
    return _traceId;
  }

  /// Obtiene las geofences del venue actual desde la ubicación
  static List<IAGeofence> getVenueGeofences() {
    if (_currentLocation?.floorplan == null) return [];
    
    // Las geofences del venue se obtienen desde la región actual
    // Esto se maneja automáticamente cuando el usuario entra en una región
    return _currentGeofences.toList();
  }

  // setLocation: allow manual override (optional)
  static Future<void> setLocation(IACoordinate coord, {int floor = 0, double accuracy = 0}) async {
    await _ch.invokeMethod('setLocation', [coord.latitude, coord.longitude, floor, accuracy]);
  }

  // getters
  static IALocation? get location => _currentLocation;
  static IAFloorplan? get floorplan => _currentFloorplan;
  static String? get traceId => _traceId;
  static List<IAGeofence> get geofences => _currentGeofences.toList();

  // ----------------- Listener management -----------------
  static void subscribe(IAListener listener) {
    _ensureHandler();
    if (_listeners.contains(listener)) return;
    _listeners.add(listener);

    // send current state
    if (_currentFloorplan != null) listener.onFloorplan(true, _currentFloorplan!);
    if (_currentLocation != null) listener.onLocation(_currentLocation!);
    if (_currentGeofences.isNotEmpty) listener.onGeofences(_currentGeofences.toList());

    // ensure native positioning is running when first listener subscribes:
    if (_listeners.length == 1) {
      // startPositioning should be called by app logic; here we do not auto-start
      // but you can uncomment next line to auto start.
      // startPositioning();
    }
  }

  static void unsubscribe(IAListener listener) {
    if (!_listeners.contains(listener)) return;
    _listeners.remove(listener);
    // optionally stop native service when no listeners
    if (_listeners.isEmpty) {
      // stopPositioning();
    }
  }
}

// ----------------- Listener classes for convenience -----------------
abstract class IAListener {
  final UniqueKey key = UniqueKey();
  final String name;
  IAListener(this.name);
  void onStatus(IAStatus status, String message) {}
  void onLocation(IALocation location) {}
  void onFloorplan(bool enter, IAFloorplan floorplan) {}
  void onOrientation(double x, double y, double z, double w) {}
  void onHeading(double heading) {}
  void onGeofences(List<IAGeofence> geofences) {}
}

typedef IAOnStatusCb = void Function(IAStatus status, String message);
typedef ValueLocationSetter = void Function(IALocation loc);
typedef IAOnFloorplanCb = void Function(bool enter, IAFloorplan floorplan);
typedef IAOnOrientationCb = void Function(double x, double y, double z, double w);
typedef ValueHeadingSetter = void Function(double heading);
typedef IAOnGeofencesCb = void Function(List<IAGeofence> geofences);

class IACallbackListener extends IAListener {
  final IAOnStatusCb? onStatusCb;
  final ValueLocationSetter? onLocationCb;
  final IAOnFloorplanCb? onFloorplanCb;
  final IAOnOrientationCb? onOrientationCb;
  final ValueHeadingSetter? onHeadingCb;
  final IAOnGeofencesCb? onGeofencesCb;

  IACallbackListener({
    required String name,
    this.onStatusCb,
    this.onLocationCb,
    this.onFloorplanCb,
    this.onOrientationCb,
    this.onHeadingCb,
    this.onGeofencesCb,
  }) : super(name);

  @override
  void onStatus(IAStatus status, String message) => onStatusCb?.call(status, message);
  @override
  void onLocation(IALocation location) => onLocationCb?.call(location);
  @override
  void onFloorplan(bool enter, IAFloorplan floorplan) => onFloorplanCb?.call(enter, floorplan);
  @override
  void onOrientation(double x, double y, double z, double w) => onOrientationCb?.call(x, y, z, w);
  @override
  void onHeading(double heading) => onHeadingCb?.call(heading);
  @override
  void onGeofences(List<IAGeofence> geofences) => onGeofencesCb?.call(geofences);
}

// Widget that auto-subscribes
class IndoorAtlasListener extends StatefulWidget {
  final Widget child;
  final IACallbackListener listener;
  final bool enabled;

  IndoorAtlasListener({
    Key? key,
    required String name,
    this.enabled = true,
    this.child = const SizedBox.shrink(),
    IAOnStatusCb? onStatus,
    ValueLocationSetter? onLocation,
    IAOnFloorplanCb? onFloorplan,
    IAOnOrientationCb? onOrientation,
    ValueHeadingSetter? onHeading,
    IAOnGeofencesCb? onGeofences,
  })  : listener = IACallbackListener(
          name: name,
          onStatusCb: onStatus,
          onLocationCb: onLocation,
          onFloorplanCb: onFloorplan,
          onOrientationCb: onOrientation,
          onHeadingCb: onHeading,
          onGeofencesCb: onGeofences,
        ),
        super(key: key);

  @override
  State<IndoorAtlasListener> createState() => _IndoorAtlasListenerState();
}

class _IndoorAtlasListenerState extends State<IndoorAtlasListener> {
  IAListener? _old;

  void _enable(IAListener? old) {
    if (widget.enabled) {
      if (old != null) {
        IndoorAtlas.unsubscribe(old);
      }
      IndoorAtlas.subscribe(widget.listener);
    } else if (old != null) {
      IndoorAtlas.unsubscribe(old);
    }
  }

  @override
  void initState() {
    super.initState();
    _enable(null);
  }

  @override
  void didUpdateWidget(covariant IndoorAtlasListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    _enable(oldWidget.listener);
  }

  @override
  void dispose() {
    IndoorAtlas.unsubscribe(widget.listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
