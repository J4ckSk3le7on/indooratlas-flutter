// lib/indooratlas.dart
// Public API for the IndoorAtlas plugin
// Provides models, MethodChannel commands and EventChannel streams.

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// CHANNEL NAMES
const MethodChannel _methodChannel = MethodChannel('com.indooratlas.flutter');
const EventChannel _statusChannel = EventChannel('com.indooratlas.flutter/events/status');
const EventChannel _locationChannel = EventChannel('com.indooratlas.flutter/events/location');
const EventChannel _regionChannel = EventChannel('com.indooratlas.flutter/events/region');
const EventChannel _geofenceChannel = EventChannel('com.indooratlas.flutter/events/geofence');
const EventChannel _orientationChannel = EventChannel('com.indooratlas.flutter/events/orientation');
const EventChannel _headingChannel = EventChannel('com.indooratlas.flutter/events/heading');

/// ================= MODELS =================

class IACoordinate {
  final double latitude;
  final double longitude;
  const IACoordinate(this.latitude, this.longitude);
}

class IAPoint {
  final double x;
  final double y;
  const IAPoint(this.x, this.y);
}

class IAFloorplan {
  final String id;
  final String name;
  final String url;
  final int floorLevel;
  final double bearing;
  final int bitmapWidth;
  final int bitmapHeight;
  final double metersToPixels;
  final IACoordinate center;

  IAFloorplan({
    required this.id,
    required this.name,
    required this.url,
    required this.floorLevel,
    required this.bearing,
    required this.bitmapWidth,
    required this.bitmapHeight,
    required this.metersToPixels,
    required this.center,
  });

  factory IAFloorplan.fromMap(Map m) {
    return IAFloorplan(
      id: m['id'] ?? '',
      name: m['name'] ?? '',
      url: m['url'] ?? '',
      floorLevel: (m['floorLevel'] ?? m['floor']) is int ? (m['floorLevel'] ?? m['floor']) as int : (m['floorLevel'] ?? m['floor']).toInt(),
      bearing: (m['bearing'] ?? 0).toDouble(),
      bitmapWidth: (m['bitmapWidth'] ?? 0).toInt(),
      bitmapHeight: (m['bitmapHeight'] ?? 0).toInt(),
      metersToPixels: (m['metersToPixels'] ?? 0).toDouble(),
      center: IACoordinate(
        (m['center'] is List && (m['center'] as List).length >= 2) ? (m['center'][1] ?? 0).toDouble() : 0.0,
        (m['center'] is List && (m['center'] as List).length >= 2) ? (m['center'][0] ?? 0).toDouble() : 0.0,
      ),
    );
  }
}

class IAGeofence {
  final String id;
  final String name;
  final int floor;
  final List<IACoordinate> coordinates;
  final String payload;

  IAGeofence({
    required this.id,
    required this.name,
    required this.floor,
    required this.coordinates,
    required this.payload,
  });

  factory IAGeofence.fromGeoJson(Map m) {
    final props = m['properties'] ?? {};
    final geometry = m['geometry'] ?? {};
    final coords = <IACoordinate>[];
    try {
      final outer = geometry['coordinates'] ?? [];
      if (outer is List && outer.isNotEmpty) {
        final ring = outer[0];
        if (ring is List) {
          for (final c in ring) {
            if (c is List && c.length >= 2) {
              coords.add(IACoordinate((c[1] ?? 0).toDouble(), (c[0] ?? 0).toDouble()));
            }
          }
        }
      }
    } catch (_) {}
    return IAGeofence(
      id: m['id'] ?? '',
      name: props['name'] ?? '',
      floor: props['floor'] ?? 0,
      coordinates: coords,
      payload: props['payload']?.toString() ?? '',
    );
  }
}

class IAVenue {
  final String id;
  final String name;
  final List<IAFloorplan> floorplans;
  final List<IAGeofence> geofences;

  IAVenue({
    required this.id,
    required this.name,
    required this.floorplans,
    required this.geofences,
  });

  factory IAVenue.fromMap(Map m) {
    final fps = <IAFloorplan>[];
    final gfs = <IAGeofence>[];
    if (m['floorPlans'] is List) {
      for (final p in m['floorPlans']) {
        if (p is Map) fps.add(IAFloorplan.fromMap(Map<String, dynamic>.from(p)));
      }
    }
    if (m['geofences'] is List) {
      for (final g in m['geofences']) {
        if (g is Map) gfs.add(IAGeofence.fromGeoJson(Map<String, dynamic>.from(g)));
      }
    }
    return IAVenue(
      id: m['id'] ?? '',
      name: m['name'] ?? '',
      floorplans: fps,
      geofences: gfs,
    );
  }
}

class _Region {
  final String id;
  final int type;
  final DateTime timestamp;
  final IAFloorplan? floorplan;
  final IAVenue? venue;

  _Region({
    required this.id,
    required this.type,
    required this.timestamp,
    this.floorplan,
    this.venue,
  });

  factory _Region.fromMap(Map m) {
    return _Region(
      id: m['regionId'] ?? '',
      type: (m['regionType'] ?? 0) as int,
      timestamp: DateTime.fromMillisecondsSinceEpoch((m['timestamp'] ?? 0) as int),
      floorplan: m['floorPlan'] != null ? IAFloorplan.fromMap(Map<String, dynamic>.from(m['floorPlan'])) : null,
      venue: m['venue'] != null ? IAVenue.fromMap(Map<String, dynamic>.from(m['venue'])) : null,
    );
  }
}

class IALocation {
  final double latitude;
  final double longitude;
  final double accuracy;
  final double heading;
  final double altitude;
  final int floor;
  final double floorCertainty;
  final double velocity;
  final DateTime timestamp;
  final IAPoint? pixel;
  final IAFloorplan? floorplan;

  IALocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.heading,
    required this.altitude,
    required this.floor,
    required this.floorCertainty,
    required this.velocity,
    required this.timestamp,
    this.pixel,
    this.floorplan,
  });

  factory IALocation.fromMap(Map m) {
    final pixel = (m.containsKey('pix_x') && m.containsKey('pix_y'))
        ? IAPoint((m['pix_x'] ?? 0).toDouble(), (m['pix_y'] ?? 0).toDouble())
        : null;
    final floorplan = (m['region'] != null && m['region']['floorPlan'] != null)
        ? IAFloorplan.fromMap(Map<String, dynamic>.from(m['region']['floorPlan']))
        : null;

    return IALocation(
      latitude: (m['latitude'] ?? 0).toDouble(),
      longitude: (m['longitude'] ?? 0).toDouble(),
      accuracy: (m['accuracy'] ?? 0).toDouble(),
      heading: (m['heading'] ?? 0).toDouble(),
      altitude: (m['altitude'] ?? 0).toDouble(),
      floor: (m['flr'] ?? 0).toInt(),
      floorCertainty: (m['floorCertainty'] ?? 0).toDouble(),
      velocity: (m['velocity'] ?? 0).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch((m['timestamp'] ?? 0) as int),
      pixel: pixel,
      floorplan: floorplan,
    );
  }
}

/// Status enum
enum IAStatus { outOfService, temporarilyUnavailable, available, limited }

/// Configuration
enum IAPositioningMode { highAccuracy, lowPower }

class IAConfiguration {
  final String apiKey;
  final String apiSecret;
  final IAPositioningMode positioningMode;
  final int? floorLock;
  final bool indoorLock;

  const IAConfiguration({
    required this.apiKey,
    required this.apiSecret,
    this.positioningMode = IAPositioningMode.highAccuracy,
    this.floorLock,
    this.indoorLock = true,
  });
}

/// ================== Events & API ==================

class IndoorAtlas {
  static bool _initialized = false;
  static IAConfiguration? _currentConfig;
  static String? _traceIdCache;

  // Streams
  static Stream<({IAStatus status, String message})> get statusStream =>
      _statusChannel.receiveBroadcastStream().map((dynamic e) {
        final m = Map<String, dynamic>.from(e as Map);
        final status = IAStatus.values[(m['status'] ?? 0) as int];
        final message = (m['message'] ?? '') as String;
        return (status: status, message: message);
      });

  static Stream<IALocation> get locationStream =>
      _locationChannel.receiveBroadcastStream().map((dynamic e) => IALocation.fromMap(Map<String, dynamic>.from(e as Map)));

  static Stream<({bool enter, _Region region})> get regionStream =>
      _regionChannel.receiveBroadcastStream().map((dynamic e) {
        final m = Map<String, dynamic>.from(e as Map);
        return (
          enter: (m['enter'] ?? false) as bool,
          region: _Region.fromMap(Map<String, dynamic>.from(m['region'] ?? {}))
        );
      });

  static Stream<({bool enter, IAGeofence geofence})> get geofenceStream =>
      _geofenceChannel.receiveBroadcastStream().map((dynamic e) {
        final m = Map<String, dynamic>.from(e as Map);
        final isEnter = (m['type'] ?? '') == 'enter';
        return (enter: isEnter, geofence: IAGeofence.fromGeoJson(Map<String, dynamic>.from(m['geofence'] ?? {})));
      });

  static Stream<({double x, double y, double z, double w, int timestamp})> get orientationStream =>
      _orientationChannel.receiveBroadcastStream().map((dynamic e) {
        final m = Map<String, dynamic>.from(e as Map);
        return (
          x: (m['x'] ?? 0).toDouble(),
          y: (m['y'] ?? 0).toDouble(),
          z: (m['z'] ?? 0).toDouble(),
          w: (m['w'] ?? 0).toDouble(),
          timestamp: (m['timestamp'] ?? 0) as int
        );
      });

  static Stream<({double heading, int timestamp})> get headingStream =>
      _headingChannel.receiveBroadcastStream().map((dynamic e) {
        final m = Map<String, dynamic>.from(e as Map);
        return (heading: (m['heading'] ?? 0).toDouble(), timestamp: (m['timestamp'] ?? 0) as int);
      });

  // API control methods
  static Future<void> configure(IAConfiguration config) async {
    // initialize only once (Method 'initialize' on native side)
    if (!_initialized) {
      await _methodChannel.invokeMethod('initialize', {'apiKey': config.apiKey, 'apiSecret': config.apiSecret});
      _initialized = true;
    }
    _currentConfig = config;

    // start/lock according to current config
    await _methodChannel.invokeMethod('startPositioning');
    await _methodChannel.invokeMethod('lockIndoors', [config.indoorLock]);
    if (config.floorLock != null) {
      await _methodChannel.invokeMethod('lockFloor', [config.floorLock]);
    } else {
      await _methodChannel.invokeMethod('unlockFloor');
    }

    _traceIdCache = await _methodChannel.invokeMethod<String>('getTraceId');
  }

  static Future<void> startPositioning() async {
    _ensureInit();
    await _methodChannel.invokeMethod('startPositioning');
  }

  static Future<void> stopPositioning() async {
    _ensureInit();
    await _methodChannel.invokeMethod('stopPositioning');
  }

  static Future<void> lockIndoors(bool locked) async {
    _ensureInit();
    await _methodChannel.invokeMethod('lockIndoors', [locked]);
  }

  static Future<void> lockFloor(int floor) async {
    _ensureInit();
    await _methodChannel.invokeMethod('lockFloor', [floor]);
  }

  static Future<void> unlockFloor() async {
    _ensureInit();
    await _methodChannel.invokeMethod('unlockFloor');
  }

  static Future<String?> get traceId async {
    _ensureInit();
    _traceIdCache ??= await _methodChannel.invokeMethod<String>('getTraceId');
    return _traceIdCache;
  }

  static void _ensureInit() {
    if (!_initialized) {
      throw StateError('IndoorAtlas SDK not initialized. Call IndoorAtlas.configure() first.');
    }
  }
}

/// ================= Widget helper (optional) =================
typedef IAOnStatusCb = void Function(IAStatus status, String message);
typedef IAOnVenueCb = void Function(bool enter, IAVenue venue);
typedef IAOnFloorplanCb = void Function(bool enter, IAFloorplan floorplan);
typedef IAOnGeofenceCb = void Function(bool enter, IAGeofence geofence);
typedef IAOnOrientationCb = void Function(double x, double y, double z, double w);

class IndoorAtlasListener extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final IAOnStatusCb? onStatus;
  final ValueSetter<IALocation>? onLocation;
  final IAOnVenueCb? onVenue;
  final IAOnFloorplanCb? onFloorplan;
  final IAOnGeofenceCb? onGeofence;
  final IAOnOrientationCb? onOrientation;
  final ValueSetter<double>? onHeading;

  const IndoorAtlasListener({
    Key? key,
    this.enabled = true,
    this.child = const SizedBox.shrink(),
    this.onStatus,
    this.onLocation,
    this.onVenue,
    this.onFloorplan,
    this.onGeofence,
    this.onOrientation,
    this.onHeading,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _IndoorAtlasListenerState();
}

class _IndoorAtlasListenerState extends State<IndoorAtlasListener> {
  StreamSubscription? _sStatus, _sLoc, _sRegion, _sFence, _sOrient, _sHeading;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _subscribe();
  }

  @override
  void didUpdateWidget(covariant IndoorAtlasListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      if (oldWidget.enabled) _unsubscribe();
      if (widget.enabled) _subscribe();
    }
  }

  void _subscribe() {
    _sStatus = IndoorAtlas.statusStream.listen((e) => widget.onStatus?.call(e.status, e.message));
    _sLoc = IndoorAtlas.locationStream.listen((loc) => widget.onLocation?.call(loc));
    _sRegion = IndoorAtlas.regionStream.listen((r) {
      if (r.region.venue != null) widget.onVenue?.call(r.enter, r.region.venue!);
      if (r.region.floorplan != null) widget.onFloorplan?.call(r.enter, r.region.floorplan!);
    });
    _sFence = IndoorAtlas.geofenceStream.listen((g) => widget.onGeofence?.call(g.enter, g.geofence));
    _sOrient = IndoorAtlas.orientationStream.listen((o) => widget.onOrientation?.call(o.x, o.y, o.z, o.w));
    _sHeading = IndoorAtlas.headingStream.listen((h) => widget.onHeading?.call(h.heading));
  }

  void _unsubscribe() {
    _sStatus?.cancel(); _sStatus = null;
    _sLoc?.cancel(); _sLoc = null;
    _sRegion?.cancel(); _sRegion = null;
    _sFence?.cancel(); _sFence = null;
    _sOrient?.cancel(); _sOrient = null;
    _sHeading?.cancel(); _sHeading = null;
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
