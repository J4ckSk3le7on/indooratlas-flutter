// ignore_for_file: avoid_print

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// ===============================
/// Modelos básicos
/// ===============================
class IACoordinate {
  final double latitude, longitude;
  const IACoordinate(this.latitude, this.longitude);
  const IACoordinate.zero()
      : latitude = 0,
        longitude = 0;
}

class IAPoint {
  final double x, y;
  const IAPoint(this.x, this.y);
  const IAPoint.zero()
      : x = 0,
        y = 0;
}

class IAFloorplan {
  final String id;
  final String name;
  final String url;
  final int floor;
  final double bearing;
  final int bitmapWidth;
  final int bitmapHeight;
  final double metersToPixels;
  final IACoordinate center;

  IAFloorplan.fromMap(Map map)
      : id = map['id'],
        name = map['name'],
        url = map['url'],
        floor = map['floorLevel'],
        bearing = map['bearing'],
        bitmapWidth = map['bitmapWidth'],
        bitmapHeight = map['bitmapHeight'],
        metersToPixels = map['metersToPixels'],
        center = IACoordinate(map['center'][1], map['center'][0]);

  // Placeholders: requeriría exponer métodos nativos adicionales
  Future<IAPoint> pointFromCoordinate(IACoordinate coord) async =>
      throw ('not implemented');
  Future<IACoordinate> coordinateFromPoint(IAPoint point) async =>
      throw ('not implemented');
}

class IAGeofence {
  final String id;
  final String name;
  final int floor;
  final List<IACoordinate> coordinates;
  final String payload;

  IAGeofence.fromGeoJson(Map map)
      : id = map['id'],
        name = map['properties']?['name'] ?? '',
        floor = map['properties']?['floor'] ?? 0,
        payload = map['properties']?['payload'] ?? '',
        coordinates = (() {
          final out = <IACoordinate>[];
          final coords = map['geometry']?['coordinates'];
          if (coords is List && coords.isNotEmpty && coords[0] is List) {
            for (var c in (coords[0] as List)) {
              if (c is List && c.length >= 2) {
                out.add(IACoordinate(c[1] * 1.0, c[0] * 1.0));
              }
            }
          }
          return out;
        })();
}

class IAVenue {
  final String id;
  final String name;
  final List<IAFloorplan> floorplans;
  final List<IAGeofence> geofences;

  IAVenue.fromMap(Map map)
      : id = map['id'],
        name = map['name'],
        floorplans = (() {
          final out = <IAFloorplan>[];
          if (map.containsKey('floorPlans')) {
            for (var plan in (map['floorPlans'] as List)) {
              out.add(IAFloorplan.fromMap(Map<String, dynamic>.from(plan)));
            }
          }
          return out;
        })(),
        geofences = (() {
          final out = <IAGeofence>[];
          if (map.containsKey('geofences')) {
            for (var fence in (map['geofences'] as List)) {
              out.add(IAGeofence.fromGeoJson(Map<String, dynamic>.from(fence)));
            }
          }
          return out;
        })();
}

class _Region {
  final String id;
  final int type;
  final DateTime timestamp;
  final IAFloorplan? floorplan;
  final IAVenue? venue;

  _Region.fromMap(Map map)
      : id = map['regionId'],
        type = map['regionType'],
        timestamp = DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
        floorplan = map.containsKey('floorPlan')
            ? IAFloorplan.fromMap(Map<String, dynamic>.from(map['floorPlan']))
            : null,
        venue = map.containsKey('venue')
            ? IAVenue.fromMap(Map<String, dynamic>.from(map['venue']))
            : null;
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

  IALocation.fromMap(Map map)
      : accuracy = (map['accuracy'] ?? 0).toDouble(),
        heading = (map['heading'] ?? 0).toDouble(),
        altitude = (map['altitude'] ?? 0).toDouble(),
        floor = (map['flr'] ?? 0).toInt(),
        floorCertainty = (map['floorCertainty'] ?? 0).toDouble(),
        velocity = (map['velocity'] ?? 0).toDouble(),
        timestamp = DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
        floorplan = map.containsKey('region')
            ? _Region.fromMap(Map<String, dynamic>.from(map['region'])).floorplan
            : null,
        pixel = (map.containsKey('pix_x') && map.containsKey('pix_y'))
            ? IAPoint((map['pix_x'] ?? 0).toDouble(), (map['pix_y'] ?? 0).toDouble())
            : null,
        super((map['latitude'] ?? 0).toDouble(), (map['longitude'] ?? 0).toDouble());
}

enum IAStatus { outOfService, temporarilyUnavailable, available, limited }

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

  IAConfiguration copyWith({
    String? apiKey,
    String? apiSecret,
    IAPositioningMode? positioningMode,
    int? floorLock,
    bool? indoorLock,
  }) =>
      IAConfiguration(
        apiKey: apiKey ?? this.apiKey,
        apiSecret: apiSecret ?? this.apiSecret,
        positioningMode: positioningMode ?? this.positioningMode,
        floorLock: floorLock ?? this.floorLock,
        indoorLock: indoorLock ?? this.indoorLock,
      );
}

/// ===============================
/// Canal nativo (Method + Event)
/// ===============================
class IndoorAtlas {
  // MethodChannel para comandos
  static const MethodChannel _mc = MethodChannel('com.indooratlas.flutter');

  // EventChannels para streams
  static const EventChannel _ecStatus =
      EventChannel('com.indooratlas.flutter/events/status');
  static const EventChannel _ecLocation =
      EventChannel('com.indooratlas.flutter/events/location');
  static const EventChannel _ecRegion =
      EventChannel('com.indooratlas.flutter/events/region');
  static const EventChannel _ecGeofence =
      EventChannel('com.indooratlas.flutter/events/geofence');
  static const EventChannel _ecOrientation =
      EventChannel('com.indooratlas.flutter/events/orientation');
  static const EventChannel _ecHeading =
      EventChannel('com.indooratlas.flutter/events/heading');

  static bool _initialized = false;
  static IAConfiguration? _currentConfig;

  static String? _traceIdCache;

  // ==========================
  // Streams públicos (broadcast)
  // ==========================
  static Stream<({IAStatus status, String message})> get statusStream =>
      _ecStatus.receiveBroadcastStream().map((dynamic e) {
        final m = Map<String, dynamic>.from(e as Map);
        final status = IAStatus.values[(m['status'] ?? 0).toInt()];
        final message = (m['message'] ?? '') as String;
        return (status: status, message: message);
      });

  static Stream<IALocation> get locationStream =>
      _ecLocation.receiveBroadcastStream().map((dynamic e) {
        return IALocation.fromMap(Map<String, dynamic>.from(e as Map));
      });

  /// Emite: { enter: bool, region: Map }
  static Stream<({bool enter, _Region region})> get regionStream =>
      _ecRegion.receiveBroadcastStream().map((dynamic e) {
        final m = Map<String, dynamic>.from(e as Map);
        return (
          enter: (m['enter'] ?? false) as bool,
          region: _Region.fromMap(Map<String, dynamic>.from(m['region'] ?? {}))
        );
      });

  /// Emite: { type: 'enter'|'exit', geofence: GeoJSON }
  static Stream<({bool enter, IAGeofence geofence})> get geofenceStream =>
      _ecGeofence.receiveBroadcastStream().map((dynamic e) {
        final m = Map<String, dynamic>.from(e as Map);
        final isEnter = (m['type'] ?? '') == 'enter';
        return (enter: isEnter, geofence: IAGeofence.fromGeoJson(m['geofence']));
      });

  /// Emite cuaternión (x,y,z,w) + timestamp
  static Stream<({double x, double y, double z, double w, int timestamp})>
      get orientationStream =>
          _ecOrientation.receiveBroadcastStream().map((dynamic e) {
            final m = Map<String, dynamic>.from(e as Map);
            return (
              x: (m['x'] ?? 0).toDouble(),
              y: (m['y'] ?? 0).toDouble(),
              z: (m['z'] ?? 0).toDouble(),
              w: (m['w'] ?? 0).toDouble(),
              timestamp: (m['timestamp'] ?? 0).toInt(),
            );
          });

  static Stream<({double heading, int timestamp})> get headingStream =>
      _ecHeading.receiveBroadcastStream().map((dynamic e) {
        final m = Map<String, dynamic>.from(e as Map);
        return (
          heading: (m['heading'] ?? 0).toDouble(),
          timestamp: (m['timestamp'] ?? 0).toInt()
        );
      });

  // ==========================
  // API de control
  // ==========================
  static Future<void> configure(IAConfiguration config) async {
    if (!_initialized) {
      await _mc.invokeMethod('initialize', {
        'apiKey': config.apiKey,
        'apiSecret': config.apiSecret,
      });
      _initialized = true;
    }
    _currentConfig = config;

    // Aplica locks y arranca posicionamiento (siempre, para simplificar)
    await _mc.invokeMethod('startPositioning');
    await _mc.invokeMethod('lockIndoors', [config.indoorLock]);
    if (config.floorLock != null) {
      await _mc.invokeMethod('lockFloor', [config.floorLock]);
    } else {
      await _mc.invokeMethod('unlockFloor');
    }
    _traceIdCache = await _mc.invokeMethod<String>('getTraceId');
  }

  static Future<void> start() async {
    _assertInitialized();
    await _mc.invokeMethod('startPositioning');
  }

  static Future<void> stop() async {
    _assertInitialized();
    await _mc.invokeMethod('stopPositioning');
  }

  static Future<void> lockIndoors(bool locked) async {
    _assertInitialized();
    await _mc.invokeMethod('lockIndoors', [locked]);
  }

  static Future<void> lockFloor(int floor) async {
    _assertInitialized();
    await _mc.invokeMethod('lockFloor', [floor]);
  }

  static Future<void> unlockFloor() async {
    _assertInitialized();
    await _mc.invokeMethod('unlockFloor');
  }

  static Future<String?> get traceId async {
    _assertInitialized();
    _traceIdCache ??= await _mc.invokeMethod<String>('getTraceId');
    return _traceIdCache;
  }

  static IAConfiguration? get configuration => _currentConfig;

  static void _assertInitialized() {
    if (!_initialized) {
      throw StateError(
          'IndoorAtlas SDK not initialized. Call IndoorAtlas.configure() first.');
    }
  }
}

/// ===============================
/// Widget helper opcional (callbacks)
/// ===============================
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
  StreamSubscription? _subStatus, _subLoc, _subRegion, _subFence, _subOrient, _subHeading;

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
    _subStatus = IndoorAtlas.statusStream.listen((e) {
      widget.onStatus?.call(e.status, e.message);
    });

    _subLoc = IndoorAtlas.locationStream.listen((loc) {
      widget.onLocation?.call(loc);
    });

    _subRegion = IndoorAtlas.regionStream.listen((e) {
      if (e.region.venue != null) {
        widget.onVenue?.call(e.enter, e.region.venue!);
      }
      if (e.region.floorplan != null) {
        widget.onFloorplan?.call(e.enter, e.region.floorplan!);
      }
    });

    _subFence = IndoorAtlas.geofenceStream.listen((e) {
      widget.onGeofence?.call(e.enter, e.geofence);
    });

    _subOrient = IndoorAtlas.orientationStream.listen((o) {
      widget.onOrientation?.call(o.x, o.y, o.z, o.w);
    });

    _subHeading = IndoorAtlas.headingStream.listen((h) {
      widget.onHeading?.call(h.heading);
    });
  }

  void _unsubscribe() {
    _subStatus?.cancel(); _subStatus = null;
    _subLoc?.cancel(); _subLoc = null;
    _subRegion?.cancel(); _subRegion = null;
    _subFence?.cancel(); _subFence = null;
    _subOrient?.cancel(); _subOrient = null;
    _subHeading?.cancel(); _subHeading = null;
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// ===============================
/// Ejemplo de uso
/// ===============================
///
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await IndoorAtlas.configure(const IAConfiguration(
///     apiKey: 'TU_API_KEY',
///     apiSecret: 'TU_API_SECRET',
///     indoorLock: true,
///     floorLock: null,
///   ));
///
///   IndoorAtlas.locationStream.listen((loc) {
///     print('IA Location: ${loc.latitude}, ${loc.longitude}, flr=${loc.floor}');
///   });
///
///   runApp(MyApp());
/// }
///
/// class MyApp extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return IndoorAtlasListener(
///       onStatus: (s, m) => print('Status: $s $m'),
///       onHeading: (h) => print('Heading: $h'),
///       onGeofence: (enter, g) => print('Geofence ${enter ? 'enter' : 'exit'}: ${g.name}'),
///       child: const SizedBox.shrink(),
///     );
///   }
/// }
