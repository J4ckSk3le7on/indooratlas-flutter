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
      floor: (map['floorLevel'] ?? 0) as int,
      bearing: ((map['bearing'] ?? 0) as num).toDouble(),
      bitmapWidth: (map['bitmapWidth'] ?? 0) as int,
      bitmapHeight: (map['bitmapHeight'] ?? 0) as int,
      widthMeters: ((map['widthMeters'] ?? 0) as num).toDouble(),
      heightMeters: ((map['heightMeters'] ?? 0) as num).toDouble(),
      metersToPixels: ((map['metersToPixels'] ?? 0) as num).toDouble(),
      pixelsToMeters: ((map['pixelsToMeters'] ?? 0) as num).toDouble(),
      bottomLeft: IACoordinate(((map['bottomLeft'][1] ?? 0) as num).toDouble(),
          ((map['bottomLeft'][0] ?? 0) as num).toDouble()),
      bottomRight: IACoordinate(((map['bottomRight'][1] ?? 0) as num).toDouble(),
          ((map['bottomRight'][0] ?? 0) as num).toDouble()),
      center: IACoordinate(((map['center'][1] ?? 0) as num).toDouble(),
          ((map['center'][0] ?? 0) as num).toDouble()),
      topLeft: IACoordinate(((map['topLeft'][1] ?? 0) as num).toDouble(),
          ((map['topLeft'][0] ?? 0) as num).toDouble()),
      topRight: IACoordinate(((map['topRight'][1] ?? 0) as num).toDouble(),
          ((map['topRight'][0] ?? 0) as num).toDouble()),
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
        fp = IAFloorplan.fromMap((map['region'] as Map)['floorPlan'] as Map);
      } catch (_) {}
    } else if (map.containsKey('floorPlan')) {
      try {
        fp = IAFloorplan.fromMap(map['floorPlan'] as Map);
      } catch (_) {}
    }

    return IALocation(
      latitude: ((map['latitude'] ?? 0) as num).toDouble(),
      longitude: ((map['longitude'] ?? 0) as num).toDouble(),
      pixel: p,
      floorplan: fp,
      accuracy: ((map['accuracy'] ?? 0) as num).toDouble(),
      heading: ((map['heading'] ?? 0) as num).toDouble(),
      altitude: ((map['altitude'] ?? 0) as num).toDouble(),
      floor: (map['flr'] ?? 0) as int,
      floorCertainty: ((map['floorCertainty'] ?? 0) as num).toDouble(),
      velocity: ((map['velocity'] ?? 0) as num).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch((map['timestamp'] ?? DateTime.now().millisecondsSinceEpoch) as int),
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
        ((coord[1] as num)).toDouble(), // latitud
        ((coord[0] as num)).toDouble(), // longitud
      );
    }).toList();

    return IAGeofence(
      id: map['id'] ?? '',
      name: ((map['properties'] as Map)['name']) ?? '',
      floor: ((map['properties'] as Map)['floor']) ?? 0,
      payload: (map['properties'] as Map)['payload']?.toString(),
      coordinates: coordinates,
    );
  }
}

// ----------------- IARoute Models -----------------
class IARoutePoint {
  final double latitude;
  final double longitude;
  final int floor;
  IARoutePoint(this.latitude, this.longitude, this.floor);
  factory IARoutePoint.fromMap(Map m) {
    return IARoutePoint(
      ((m['latitude'] ?? 0) as num).toDouble(),
      ((m['longitude'] ?? 0) as num).toDouble(),
      (m['floor'] ?? 0) as int,
    );
  }
}

class IARouteLeg {
  final IARoutePoint begin;
  final IARoutePoint end;
  final double length;
  final double direction;
  final int edgeIndex;

  IARouteLeg({
    required this.begin,
    required this.end,
    required this.length,
    required this.direction,
    required this.edgeIndex,
  });

  factory IARouteLeg.fromMap(Map m) {
    return IARouteLeg(
      begin: IARoutePoint.fromMap(m['begin'] as Map),
      end: IARoutePoint.fromMap(m['end'] as Map),
      length: ((m['length'] ?? 0) as num).toDouble(),
      direction: ((m['direction'] ?? 0) as num).toDouble(),
      edgeIndex: (m['edgeIndex'] ?? -1) as int,
    );
  }
}

class IARoute {
  final List<IARouteLeg> legs;
  final String error;
  IARoute(this.legs, this.error);
  factory IARoute.fromMap(Map m) {
    final legsList = (m['legs'] as List?) ?? [];
    final legs = legsList.map((e) => IARouteLeg.fromMap(e as Map)).toList();
    return IARoute(legs, (m['error'] ?? '') as String);
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

  // Nuevo: Estado de geocercas activadas para tracking visual
  static final Set<String> _triggeredGeofenceIds = Set.identity();

  // Nuevo: destino actual (para marcar en UI)
  static IACoordinate? _currentDestination;

  /// getter público
  static IACoordinate? get currentDestination => _currentDestination;

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

            // Actualizar estado de geofence
            _updateGeofenceState(loc);

            for (var l in _listeners) l.onLocation(loc);
            break;
          case 'onEnterRegion':
            final Map map = (call.arguments as List).first as Map;
            if (map.containsKey('floorPlan')) {
              _currentFloorplan = IAFloorplan.fromMap(map['floorPlan'] as Map);
              for (var l in _listeners) l.onFloorplan(true, _currentFloorplan!);
            }
            break;
          case 'onExitRegion':
            final Map map = (call.arguments as List).first as Map;
            if (map.containsKey('floorPlan')) {
              final fp = IAFloorplan.fromMap(map['floorPlan'] as Map);
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
          case 'onGeofenceEvent':
            final args = call.arguments as List;
            final geofenceId = args[0] as String;
            final eventType = args[1] as String; // "ENTER" o "EXIT"

            if (eventType == "ENTER") {
              _triggeredGeofenceIds.add(geofenceId);
            } else if (eventType == "EXIT") {
              _triggeredGeofenceIds.remove(geofenceId);
            }

            for (var l in _listeners) l.onGeofenceEvent(geofenceId, eventType);
            break;
          case 'onWayfindingUpdate':
            // recibe un Map con la estructura de IARoute2Map desde native
            final Map map = (call.arguments as List).first as Map;
            final route = IARoute.fromMap(map);

            // Llamamos al método del listener (implementación concreta lo manejará)
            for (var l in _listeners) {
              try {
                l.onWayfindingUpdate(route);
              } catch (_) {}
            }
            break;
          default:
            if (debugEnabled) debugPrint('Unhandled method ${call.method}');
        }
      } catch (e, st) {
        if (debugEnabled) debugPrint('Error handling method ${call.method}: $e\n$st');
      }
    });
  }

  /// Actualiza el estado de las geocercas basado en la ubicación actual
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
        for (var l in _listeners) l.onGeofenceEvent(geofenceId, eventType);
      }
    }
  }

  /// Verifica si una ubicación está dentro de una geocerca
  static bool _isLocationInGeofence(IALocation location, IAGeofence geofence) {
    if (geofence.coordinates.isEmpty) return false;

    final pointLat = location.latitude;
    final pointLon = location.longitude;
    return _isPointInPolygon(IACoordinate(pointLat, pointLon), geofence.coordinates);
  }

  /// Algoritmo de punto en polígono usando ray casting
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

  /// Bloquea el posicionamiento solo para interiores (desactiva detección outdoor-indoor)
  static Future<void> lockIndoors(bool locked) async {
    await _ch.invokeMethod('lockIndoors', locked);
  }

  /// Bloquea el posicionamiento a un piso específico
  static Future<void> lockFloor(int floor) async {
    await _ch.invokeMethod('lockFloor', floor);
  }

  /// Desbloquea el piso (permite cambio automático de piso)
  static Future<void> unlockFloor() async {
    await _ch.invokeMethod('unlockFloor');
  }

  /// Configura la sensibilidad de orientación y heading para estabilizar el bearing
  /// headingSensitivity: sensibilidad para cambios de heading (grados)
  /// orientationSensitivity: sensibilidad para cambios de orientación 3D (grados)
  static Future<void> setSensitivities(double orientationSensitivity, double headingSensitivity) async {
    await _ch.invokeMethod('setSensitivities', [orientationSensitivity, headingSensitivity]);
  }

  static Future<String?> getTraceId() async {
    final r = await _ch.invokeMethod('getTraceId');
    _traceId = r as String?;
    return _traceId;
  }

  /// Solicita monitoreo de geofences específicas
  static Future<void> requestGeofences(List<String> geofenceIds) async {
    await _ch.invokeMethod('requestGeofences', geofenceIds);
  }

  /// Detiene el monitoreo de geofences
  static Future<void> removeGeofences() async {
    await _ch.invokeMethod('removeGeofences');
  }

  /// Obtiene las geofences actuales desde el sistema
  static Future<List<IAGeofence>> getCurrentGeofences() async {
    final result = await _ch.invokeMethod('getCurrentGeofences');
    if (result is List) {
      final geofenceMaps = result.cast<Map>();
      return geofenceMaps.map((map) => IAGeofence.fromMap(map)).toList();
    }
    return [];
  }

  /// Obtiene las geofences del venue actual desde la ubicación
  static List<IAGeofence> getVenueGeofences() {
    if (_currentLocation?.floorplan == null) return [];

    return _currentGeofences.toList();
  }

  /// Obtiene las geocercas que están actualmente activadas
  static List<IAGeofence> getTriggeredGeofences() {
    return _currentGeofences.where((g) => _triggeredGeofenceIds.contains(g.id)).toList();
  }

  /// Verifica si una geocerca específica está activada
  static bool isGeofenceTriggered(String geofenceId) {
    return _triggeredGeofenceIds.contains(geofenceId);
  }

  // setLocation: allow manual override (optional)
  static Future<void> setLocation(IACoordinate coord, {int floor = 0, double accuracy = 0}) async {
    await _ch.invokeMethod('setLocation', [coord.latitude, coord.longitude, floor, accuracy]);
  }

  // ----------------- WAYFINDING -----------------

  /// Lanza wayfinding hacia la coordenada dada y guarda destino localmente
  /// mode: optional int — ejemplo: 1 = EXCLUDE_INACCESSIBLE, 2 = EXCLUDE_ACCESSIBLE_ONLY
  static Future<void> startWayfinding(double lat, double lon, {int floor = 0, int? mode}) async {
    _ensureHandler();
    _currentDestination = IACoordinate(lat, lon);
    final args = [lat, lon, floor, if (mode != null) mode];
    await _ch.invokeMethod('startWayfinding', args);

    // Notificar a los listeners que hay un destino nuevo
    for (var l in _listeners) {
      try {
        l.onDestinationSet(_currentDestination);
      } catch (_) {}
    }
  }

  /// Detiene wayfinding y limpia destino local
  static Future<void> stopWayfinding() async {
    _currentDestination = null;
    await _ch.invokeMethod('stopWayfinding');

    for (var l in _listeners) {
      try {
        l.onDestinationSet(_currentDestination);
      } catch (_) {}
    }
  }

  // getters
  static IALocation? get location => _currentLocation;
  static IAFloorplan? get floorplan => _currentFloorplan;
  static String? get traceId => _traceId;
  static List<IAGeofence> get geofences => _currentGeofences.toList();
  static List<IAGeofence> get triggeredGeofences => getTriggeredGeofences();

  // ----------------- Listener management -----------------
  static void subscribe(IAListener listener) {
    _ensureHandler();
    if (_listeners.contains(listener)) return;
    _listeners.add(listener);

    // send current state
    if (_currentFloorplan != null) listener.onFloorplan(true, _currentFloorplan!);
    if (_currentLocation != null) listener.onLocation(_currentLocation!);
    if (_currentGeofences.isNotEmpty) listener.onGeofences(_currentGeofences.toList());

    // Enviar estado actual de geocercas activadas
    if (_triggeredGeofenceIds.isNotEmpty) {
      for (final geofenceId in _triggeredGeofenceIds) {
        listener.onGeofenceEvent(geofenceId, "ENTER");
      }
    }

    // Enviar destino actual (si existe) usando el método del listener
    listener.onDestinationSet(_currentDestination);

    // ensure native positioning is running when first listener subscribes:
    if (_listeners.length == 1) {
      // startPositioning should be called by app logic; here we do not auto-start
    }
  }

  static void unsubscribe(IAListener listener) {
    if (!_listeners.contains(listener)) return;
    _listeners.remove(listener);
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
  void onGeofenceEvent(String geofenceId, String eventType) {}
  // opcional: onWayfindingUpdate (implementable por listeners)
  void onWayfindingUpdate(IARoute route) {}
  // opcional: cuando se establece o se limpia el destino
  void onDestinationSet(IACoordinate? destination) {}
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
  final void Function(String geofenceId, String eventType)? onGeofenceEventCb;

  // Renombrados: campos que guardan callbacks para evitar colisión con métodos
  final void Function(IARoute route)? onWayfindingUpdateCb;
  final void Function(IACoordinate? destination)? onDestinationSetCb;

  IACallbackListener({
    required String name,
    this.onStatusCb,
    this.onLocationCb,
    this.onFloorplanCb,
    this.onOrientationCb,
    this.onHeadingCb,
    this.onGeofencesCb,
    this.onGeofenceEventCb,
    void Function(IARoute route)? onWayfindingUpdate,
    void Function(IACoordinate? destination)? onDestinationSet,
  })  : onWayfindingUpdateCb = onWayfindingUpdate,
        onDestinationSetCb = onDestinationSet,
        super(name);

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
  @override
  void onGeofenceEvent(String geofenceId, String eventType) => onGeofenceEventCb?.call(geofenceId, eventType);

  // implementaciones que delegan a los campos renombrados
  @override
  void onWayfindingUpdate(IARoute route) => onWayfindingUpdateCb?.call(route);
  @override
  void onDestinationSet(IACoordinate? destination) => onDestinationSetCb?.call(destination);
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
    void Function(String geofenceId, String eventType)? onGeofenceEvent,
    void Function(IARoute route)? onWayfindingUpdate,
    void Function(IACoordinate? destination)? onDestinationSet,
  })  : listener = IACallbackListener(
          name: name,
          onStatusCb: onStatus,
          onLocationCb: onLocation,
          onFloorplanCb: onFloorplan,
          onOrientationCb: onOrientation,
          onHeadingCb: onHeading,
          onGeofencesCb: onGeofences,
          onGeofenceEventCb: onGeofenceEvent,
          onWayfindingUpdate: onWayfindingUpdate,
          onDestinationSet: onDestinationSet,
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
