import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

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

class IALocation extends IACoordinate {
  late final IAPoint? pixel;
  late final IAFloorplan? floorplan;
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
    this.accuracy = 0,
    this.heading = 0,
    this.altitude = 0,
    this.floor = 0,
    this.floorCertainty = 0,
    this.velocity = 0,
    required this.timestamp,
  })  : pixel = null,
        floorplan = null,
        super(latitude, longitude);
  IALocation.fromCoordinate(
    IACoordinate coordinate, {
    this.accuracy = 0,
    this.heading = 0,
    this.altitude = 0,
    this.floor = 0,
    this.floorCertainty = 0,
    this.velocity = 0,
    required this.timestamp,
  })  : pixel = null,
        floorplan = null,
        super(coordinate.latitude, coordinate.longitude);
  IALocation.fromMap(Map map)
      : accuracy = map['accuracy'],
        heading = map['heading'],
        altitude = map['altitude'],
        floor = map['flr'],
        floorCertainty = map['floorCertainty'],
        velocity = map['velocity'],
        timestamp = DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
        super(map['latitude'], map['longitude']) {
    if (map.containsKey('region')) {
      this.floorplan = _Region.fromMap(map['region']).floorplan;
    }
    if (map.containsKey('pix_x') && map.containsKey('pix_y')) {
      this.pixel = IAPoint(map['pix_x'], map['pix_y']);
    }
  }
}

enum IAStatus {
  outOfService,
  temporarilyUnavailable,
  available,
  limited,
}

class IARoutingPoint {
  final IACoordinate coordinate;
  final int floor;
  const IARoutingPoint(this.coordinate, this.floor);
  IARoutingPoint.fromMap(Map map)
      : coordinate = IACoordinate(map['latitude'], map['longitude']),
        floor = map['floor'];
}

class IARoutingLeg {
  final IARoutingPoint begin, end;
  final double direction;
  final double length;
  final int edgeIndex;
  const IARoutingLeg(
    this.begin,
    this.end,
    this.direction,
    this.length,
    this.edgeIndex,
  );
  IARoutingLeg.fromMap(Map map)
      : begin = IARoutingPoint.fromMap(map['begin']),
        end = IARoutingPoint.fromMap(map['end']),
        direction = map['direction'],
        length = map['length'],
        edgeIndex = map['edgeIndex'];
}

class IARoute {
  late final List<IARoutingLeg> legs;
  final String error;
  IARoute(this.legs, this.error);
  IARoute.empty()
      : legs = [],
        error = '';
  IARoute.fromMap(Map map) : error = map['error'] {
    List<IARoutingLeg> legs = [];
    for (var leg in map['legs']) {
      legs.add(IARoutingLeg.fromMap(leg));
    }
    this.legs = legs;
  }
}

class IAGeofence {
  final String id;
  final String name;
  final int floor;
  late final List<IACoordinate> coordinates;
  final String payload;
  IAGeofence({
    required this.id,
    this.name = '',
    this.floor = 0,
    required this.coordinates,
    this.payload = '',
  });
  IAGeofence.fromGeoJson(Map map)
      : id = map['id'],
        name = map['properties']['name'],
        floor = map['properties']['floor'],
        payload = map['properties']['payload'] {
    List<IACoordinate> coords = [];
    for (var coord in map['geometry']['coordinates'][0]) {
      coords.add(IACoordinate(coord[1], coord[0]));
    }
    this.coordinates = coords;
  }
  // TODO: toGeoJson
}

class IAPOI {
  final String id;
  final String name;
  final int floor;
  final IACoordinate coordinate;
  final String payload;
  IAPOI.fromGeoJson(Map map)
      : id = map['id'],
        name = map['properties']['name'],
        floor = map['properties']['floor'],
        coordinate = IACoordinate(map['geometry']['coordinates'][1],
            map['geometry']['coordinates'][0]),
        payload = map['properties']['payload'];
  // TODO: toGeoJson
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
  IAFloorplan.fromMap(Map map)
      : id = map['id'],
        name = map['name'],
        url = map['url'],
        floor = map['floorLevel'],
        bearing = map['bearing'],
        bitmapWidth = map['bitmapWidth'],
        bitmapHeight = map['bitmapHeight'],
        widthMeters = map['widthMeters'],
        heightMeters = map['heightMeters'],
        metersToPixels = map['metersToPixels'],
        pixelsToMeters = map['pixelsToMeters'],
        bottomLeft = IACoordinate(map['bottomLeft'][1], map['bottomLeft'][0]),
        bottomRight =
            IACoordinate(map['bottomRight'][1], map['bottomRight'][0]),
        center = IACoordinate(map['center'][1], map['center'][0]),
        topLeft = IACoordinate(map['topLeft'][1], map['topLeft'][0]),
        topRight = IACoordinate(map['topRight'][1], map['topRight'][0]);

  Future<IAPoint> pointFromCoordinate(IACoordinate coord) async {
    // TODO: native side not implemented
    throw ('not implemented');
    final r = await IndoorAtlas._nativeInitialized<List<double>>(
        'pointFromCoordinate', [this.id, coord.latitude, coord.longitude]);
    return IAPoint(r![0], r[1]);
  }

  Future<IACoordinate> coordinateFromPoint(IAPoint point) async {
    // TODO: native side not implemented
    throw ('not implemented');
    final r = await IndoorAtlas._nativeInitialized<List<double>>(
        'coordinateFromPoint', [this.id, point.x, point.y]);
    return IACoordinate(r![0], r[1]);
  }
}

class IAVenue {
  final String id;
  final String name;
  late final List<IAFloorplan> floorplans;
  late final List<IAGeofence> geofences;
  late final List<IAPOI> pois;
  IAVenue.fromMap(Map map)
      : id = map['id'],
        name = map['name'] {
    List<IAFloorplan> plans = [];
    if (map.containsKey('floorPlans')) {
      for (var plan in map['floorPlans']) {
        plans.add(IAFloorplan.fromMap(plan));
      }
    }
    this.floorplans = plans;
    List<IAGeofence> fences = [];
    if (map.containsKey('geofences')) {
      for (var fence in map['geofences']) {
        fences.add(IAGeofence.fromGeoJson(fence));
      }
    }
    this.geofences = fences;
    List<IAPOI> pois = [];
    if (map.containsKey('pois')) {
      for (var poi in map['pois']) {
        pois.add(IAPOI.fromGeoJson(poi));
      }
    }
    this.pois = pois;
  }
}

class _Region {
  final String id;
  final int type;
  final DateTime timestamp;
  late final IAFloorplan? floorplan;
  late final IAVenue? venue;
  _Region.fromMap(Map map)
      : id = map['regionId'],
        type = map['regionType'],
        timestamp = DateTime.fromMillisecondsSinceEpoch(map['timestamp']) {
    if (map.containsKey('floorPlan')) {
      this.floorplan = IAFloorplan.fromMap(map['floorPlan']);
    } else {
      this.floorplan = null;
    }
    if (map.containsKey('venue')) {
      this.venue = IAVenue.fromMap(map['venue']);
    } else {
      this.venue = null;
    }
  }
}

enum IAPositioningMode {
  highAccuracy,
  lowPower,
  cart,
}

// All these options are global and affect every listener
class IAConfiguration {
  final String apiKey;
  final String endpoint;
  final double minChangeMeters;
  final double minIntervalSeconds;
  final IAPositioningMode positioningMode;
  final int? floorLock;
  final bool indoorLock;
  const IAConfiguration({
    required this.apiKey,
    this.endpoint = '',
    this.minChangeMeters = 0.7,
    this.minIntervalSeconds = 2,
    this.positioningMode = IAPositioningMode.highAccuracy,
    this.floorLock = null,
    this.indoorLock = true,
  });

  IAConfiguration copyWithEx({
    String? apiKey,
    String? endpoint,
    double? minChangeMeters,
    double? minIntervalSeconds,
    IAPositioningMode? positioningMode,
    int? floorLock, // this is always applied
    bool? indoorLock,
  }) =>
      IAConfiguration(
        apiKey: apiKey ?? this.apiKey,
        endpoint: endpoint ?? this.endpoint,
        minChangeMeters: minChangeMeters ?? this.minChangeMeters,
        minIntervalSeconds: minIntervalSeconds ?? this.minIntervalSeconds,
        positioningMode: positioningMode ?? this.positioningMode,
        floorLock: floorLock,
        indoorLock: indoorLock ?? this.indoorLock,
      );

  IAConfiguration copyWith({
    String? apiKey,
    String? endpoint,
    double? minChangeMeters,
    double? minIntervalSeconds,
    IAPositioningMode? positioningMode,
    bool? indoorLock,
  }) =>
      this.copyWithEx(
        apiKey: apiKey,
        endpoint: endpoint,
        minChangeMeters: minChangeMeters,
        minIntervalSeconds: minIntervalSeconds,
        positioningMode: positioningMode,
        floorLock: this.floorLock,
        indoorLock: indoorLock,
      );

  IAConfiguration copyFloorLocked(int? floorLock) =>
      this.copyWithEx(floorLock: floorLock);
}

class IAWayfindingRequest {
  final IACoordinate destination;
  final int floor;
  const IAWayfindingRequest({required this.destination, required this.floor});
}

abstract class IAListener {
  final UniqueKey key; // make sure every instance is unique
  final String name;
  // TODO: add IAWayfindingRequest
  // TODO: add IAGeofence array (for dynamic geofences)
  IAListener(this.name) : key = UniqueKey();
  void onStatus(IAStatus status, String message);
  void onLocation(IALocation location);
  void onVenue(bool enter, IAVenue venue);
  void onFloorplan(bool enter, IAFloorplan floorplan);
  void onWayfindingRoute(IARoute route, IAWayfindingRequest? request);
  void onOrientation(double x, double y, double z, double w);
  void onHeading(double heading);
}

class IndoorAtlas {
  static const MethodChannel _ch =
      const MethodChannel('com.indooratlas.flutter');

  static Future<T?> _native<T>(String method, [dynamic arguments]) {
    return _ch.invokeMethod<T>(method, arguments);
  }

  // Debug print toggle
  static bool debugEnabled = false;

  // Has the SDK be initialized?
  static bool _initialized = false;

  // Has permissions been requested?
  static bool _permissions = false;

  // Currently applied configuration
  static IAConfiguration _opts = IAConfiguration(apiKey: '');

  // Given configuration to configure
  // this is usually same as _opts, but may be briefly out of sync when new
  // configuration is given, as applying configuration can take few seconds we
  // hide this latency by returning always _givenOpts in static configuration
  // getter
  static IAConfiguration _givenOpts = IAConfiguration(apiKey: '');

  // Latest trace id is cached here
  static String? _traceId;

  // Listeners subscribed for IA callbacks
  static var _listeners = Set<IAListener>.identity();

  // TODO: Get rid of global wayfinding and use requestWayfindingRoute instead
  //       This allows us to move this to IAListener, and get rid of some state
  static IAWayfindingRequest? _wayfinding;

  // Stored current state
  // We send the current state to any new listener
  static IAVenue? _currentVenue;
  static IAFloorplan? _currentFloorplan;
  static IALocation? _currentLocation;
  static IARoute? _currentRoute;

  static void _debug(String msg) {
    if (debugEnabled) print('IndoorAtlas DEBUG: ${msg}');
  }

  static void _warning(String msg) {
    print('IndoorAtlas WARNING: ${msg}');
  }

  static void _error(String msg) {
    print('IndoorAtlas ERROR: ${msg}');
    _listeners.forEach((l) => l.onStatus(IAStatus.outOfService, msg));
  }

  static Future<T?> _nativeInitialized<T>(String method, [dynamic arguments]) {
    if (!_initialized) {
      throw ('state inconsistency detected: indooratlas was not initialized before native call');
    }
    return _ch.invokeMethod<T>(method, arguments);
  }

  static Future<void> _onStatusChanged(int status) {
    // TODO: add informal messages?
    _listeners.forEach((l) => l.onStatus(IAStatus.values[status], ''));
    return Future.value();
  }

  static Future<void> _onLocationChanged(Map location) {
    final loc = IALocation.fromMap(location);
    _currentLocation = loc;
    _listeners.forEach((l) => l.onLocation(loc));
    return Future.value();
  }

  static void _dispatchRegionEvent(bool enter, _Region region) {
    if (region.venue != null) {
      _currentVenue = (enter ? region.venue : null);
      _listeners.forEach((l) => l.onVenue(enter, region.venue!));
    }
    if (region.floorplan != null) {
      _currentFloorplan = (enter ? region.floorplan : null);
      _listeners.forEach((l) => l.onFloorplan(enter, region.floorplan!));
    }
  }

  static Future<void> _onEnterRegion(Map region) {
    _dispatchRegionEvent(true, _Region.fromMap(region));
    return Future.value();
  }

  static Future<void> _onExitRegion(Map region) {
    _dispatchRegionEvent(false, _Region.fromMap(region));
    return Future.value();
  }

  static Future<void> _onOrientationChanged(
      int timestamp, double x, double y, double z, double w) {
    _listeners.forEach((l) => l.onOrientation(x, y, z, w));
    return Future.value();
  }

  static Future<void> _onHeadingChanged(int timestamp, double heading) {
    _listeners.forEach((l) => l.onHeading(heading));
    return Future.value();
  }

  static Future<void> _onWayfindingUpdate(Map route) {
    // should not happen, but check anyway
    if (_wayfinding != null) {
      final r = IARoute.fromMap(route);
      _currentRoute = r;
      _listeners.forEach((l) => l.onWayfindingRoute(r, _wayfinding));
    }
    return Future.value();
  }

  static Future<void> _onPermissionsGranted(bool granted) {
    if (!_permissions && granted && _initialized) {
      // reinitialize
      _initialized = false;
      _applyOptions(_opts);
    }
    _permissions = granted;
    return Future.value();
  }

  static void _resetState() {
    if (_currentFloorplan != null) {
      _listeners.forEach((l) => l.onFloorplan(false, _currentFloorplan!));
      _currentFloorplan = null;
    }
    if (_currentVenue != null) {
      _listeners.forEach((l) => l.onVenue(false, _currentVenue!));
      _currentVenue = null;
    }
    _currentLocation = null;
  }

  static void _resetWayfinding() {
    if (_currentRoute != null) {
      _listeners.forEach((l) => l.onWayfindingRoute(IARoute.empty(), null));
      _currentRoute = null;
    }
  }

  static void _applyOptions(IAConfiguration opts) {
    if (!_initialized || opts.apiKey != _opts.apiKey) {
      if (opts.apiKey.length != 36) {
        _error('apiKey is not valid');
        return;
      }
      // dart:mirrors can't be used in flutter, so we can't do reflection here
      // https://docs.flutter.dev/resources/faq#does-flutter-come-with-a-reflection--mirrors-system
      _ch.setMethodCallHandler((call) {
        print('method call: ${call}');
        _nativeInitialized<String?>('getTraceId').then((v) => _traceId = v);
        try {
          switch (call.method) {
            case 'onStatusChanged':
              return Function.apply(_onStatusChanged, call.arguments);
            case 'onLocationChanged':
              return Function.apply(_onLocationChanged, call.arguments);
            case 'onEnterRegion':
              return Function.apply(_onEnterRegion, call.arguments);
            case 'onExitRegion':
              return Function.apply(_onExitRegion, call.arguments);
            case 'onOrientationChanged':
              return Function.apply(_onOrientationChanged, call.arguments);
            case 'onHeadingChanged':
              return Function.apply(_onHeadingChanged, call.arguments);
            case 'onWayfindingUpdate':
              return Function.apply(_onWayfindingUpdate, call.arguments);
            case 'onPermissionsGranted':
              return Function.apply(_onPermissionsGranted, call.arguments);
          }
        } catch (err, stack) {
          _error('$err\n$stack');
        }
        return throw MissingPluginException('notImplemented');
      });
      if (opts.apiKey != _opts.apiKey) _debug('apiKey changed');
      if (opts.endpoint != _opts.endpoint) _debug('endpoint changed');
      _resetState();
      _resetWayfinding();
      _traceId = null;
      _native('initialize', ['0.0.1', opts.apiKey, opts.endpoint]);
      _debug('init done');
      _initialized = true;
    }

    if (_listeners.isEmpty) {
      _debug('stopping positioning');
      _nativeInitialized('stopPositioning');
      _resetState();
    } else {
      _debug('starting positioning');
      if (opts.minChangeMeters != _opts.minChangeMeters)
        _debug('minChangeMeters changed');
      if (opts.minIntervalSeconds != _opts.minIntervalSeconds)
        _debug('minIntervalSeconds changed');
      _nativeInitialized('setOutputThresholds',
          [opts.minChangeMeters, opts.minIntervalSeconds]);
      if (opts.positioningMode != _opts.positioningMode)
        _debug('positioningMode changed');
      _nativeInitialized('setPositioningMode', [opts.positioningMode.index]);
      _nativeInitialized('startPositioning');
      if (opts.indoorLock != _opts.indoorLock) _debug('indoorLock changed');
      _nativeInitialized('lockIndoors', [opts.indoorLock]);
      if (opts.floorLock != _opts.floorLock) _debug('floorLock changed');
      if (opts.floorLock != null) {
        _nativeInitialized('lockFloor', [opts.floorLock!]);
      } else {
        _nativeInitialized('unlockFloor');
      }
    }

    if (_wayfinding == null) {
      _debug('stopping wayfinding');
      _nativeInitialized('stopWayfinding');
      _resetWayfinding();
    } else {
      _debug('starting wayfinding');
      _nativeInitialized('startWayfinding', [
        _wayfinding!.destination.latitude,
        _wayfinding!.destination.longitude,
        _wayfinding!.floor
      ]);
    }

    _opts = opts;
  }

  static void configure(IAConfiguration options) {
    _givenOpts = options;
    _applyOptions(options);
  }

  static IAConfiguration get configuration => _givenOpts;
  static String? get traceId => _traceId;
  static IAVenue? get venue => _currentVenue;
  static IAFloorplan? get floorplan => _currentFloorplan;
  static IALocation? get location => _currentLocation;

  static void setLocation(IACoordinate coordinate) {
    IALocation pos;
    if (coordinate is IALocation) {
      pos = coordinate;
    } else {
      pos = IALocation.fromCoordinate(coordinate, timestamp: DateTime.now());
    }
    _nativeInitialized(
        'setLocation', [pos.latitude, pos.longitude, pos.floor, pos.accuracy]);
  }

  static void subscribe(IAListener listener) {
    if (_listeners.contains(listener)) return;
    _listeners.add(listener);

    // send current state
    if (_currentVenue != null) {
      listener.onVenue(true, _currentVenue!);
    }
    if (_currentFloorplan != null) {
      listener.onFloorplan(true, _currentFloorplan!);
    }
    if (_currentLocation != null) {
      listener.onLocation(_currentLocation!);
    }
    if (_wayfinding != null && _currentRoute != null) {
      listener.onWayfindingRoute(_currentRoute!, _wayfinding!);
    }

    _applyOptions(_opts);
  }

  static void unsubscribe(IAListener listener) {
    if (!_listeners.contains(listener)) return;
    _listeners.remove(listener);
    _applyOptions(_opts);
  }

  static void resubscribe(IAListener old, IAListener listener) {
    _listeners.remove(old);
    _listeners.add(listener);
  }

  // TODO: Get rid of the global wayfinding and use requestWayfindingRoute instead
  //       IAWayfindingRequest will be a IAListener member
  //       This way we get rid of some global state

  static void startWayfindingTo(IAWayfindingRequest request) {
    if (_wayfinding == request) return;
    _wayfinding = request;
    _applyOptions(_opts);
  }

  static void stopWayfindingTo(IAWayfindingRequest request) {
    if (_wayfinding == request) stopWayfinding();
  }

  static void stopWayfinding() {
    _wayfinding = null;
    _applyOptions(_opts);
  }
}

// ---- flutter widgets below ----

class _IndoorAtlasListenerState extends State<IndoorAtlasListener> {
  void _enable(IAListener? old) {
    if (widget.enabled) {
      if (old != null) {
        IndoorAtlas.resubscribe(old, widget.listener);
      } else {
        IndoorAtlas.subscribe(widget.listener);
      }
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
  void didUpdateWidget(IndoorAtlasListener old) {
    super.didUpdateWidget(old);
    _enable(old.listener);
  }

  @override
  void dispose() {
    IndoorAtlas.unsubscribe(widget.listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

typedef IAOnStatusCb = void Function(IAStatus status, String message);
typedef IAOnVenueCb = void Function(bool enter, IAVenue venue);
typedef IAOnFloorplanCb = void Function(bool enter, IAFloorplan floorplan);
typedef IAOnWayfindingRouteCb = void Function(
    IARoute route, IAWayfindingRequest? request);
typedef IAOnOrientationCb = void Function(
    double x, double y, double z, double w);

class IACallbackListener extends IAListener {
  final IAOnStatusCb? onStatusCb;
  final ValueSetter<IALocation>? onLocationCb;
  final IAOnVenueCb? onVenueCb;
  final IAOnFloorplanCb? onFloorplanCb;
  final IAOnWayfindingRouteCb? onWayfindingRouteCb;
  final IAOnOrientationCb? onOrientationCb;
  final ValueSetter<double>? onHeadingCb;
  IACallbackListener({
    required String name,
    required this.onStatusCb,
    required this.onLocationCb,
    required this.onVenueCb,
    required this.onFloorplanCb,
    required this.onWayfindingRouteCb,
    required this.onOrientationCb,
    required this.onHeadingCb,
  }) : super(name);

  @override
  void onStatus(IAStatus status, String message) {
    onStatusCb?.call(status, message);
  }

  @override
  void onLocation(IALocation position) {
    onLocationCb?.call(position);
  }

  @override
  void onVenue(bool enter, IAVenue venue) {
    onVenueCb?.call(enter, venue);
  }

  @override
  void onFloorplan(bool enter, IAFloorplan floorplan) {
    onFloorplanCb?.call(enter, floorplan);
  }

  @override
  void onWayfindingRoute(IARoute route, IAWayfindingRequest? request) {
    onWayfindingRouteCb?.call(route, request);
  }

  @override
  void onOrientation(double x, double y, double z, double w) {
    onOrientationCb?.call(x, y, z, w);
  }

  @override
  void onHeading(double heading) {
    onHeadingCb?.call(heading);
  }
}

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
    ValueSetter<IALocation>? onLocation,
    IAOnVenueCb? onVenue,
    IAOnFloorplanCb? onFloorplan,
    IAOnWayfindingRouteCb? onWayfindingRoute,
    IAOnOrientationCb? onOrientation,
    ValueSetter<double>? onHeading,
  })  : listener = IACallbackListener(
          name: name,
          onStatusCb: onStatus,
          onLocationCb: onLocation,
          onVenueCb: onVenue,
          onFloorplanCb: onFloorplan,
          onWayfindingRouteCb: onWayfindingRoute,
          onOrientationCb: onOrientation,
          onHeadingCb: onHeading,
        ),
        super(key: key);
  @override
  State<StatefulWidget> createState() => _IndoorAtlasListenerState();
}
