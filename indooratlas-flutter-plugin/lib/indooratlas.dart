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
      : accuracy = map['accuracy'],
        heading = map['heading'],
        altitude = map['altitude'],
        floor = map['flr'],
        floorCertainty = map['floorCertainty'],
        velocity = map['velocity'],
        timestamp = DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
        floorplan = map.containsKey('region')
            ? _Region.fromMap(map['region']).floorplan
            : null,
        pixel = (map.containsKey('pix_x') && map.containsKey('pix_y'))
            ? IAPoint(map['pix_x'], map['pix_y'])
            : null,
        super(map['latitude'], map['longitude']);
}

enum IAStatus {
  outOfService,
  temporarilyUnavailable,
  available,
  limited,
}

class IAGeofence {
  final String id;
  final String name;
  final int floor;
  late final List<IACoordinate> coordinates;
  final String payload;

  IAGeofence.fromGeoJson(Map map)
      : id = map['id'],
        name = map['properties']['name'] ?? '',
        floor = map['properties']['floor'] ?? 0,
        payload = map['properties']['payload'] ?? '' {
    List<IACoordinate> coords = [];
    if (map['geometry'] != null &&
        map['geometry']['coordinates'] != null &&
        map['geometry']['coordinates'][0] is List) {
      for (var coord in map['geometry']['coordinates'][0]) {
        coords.add(IACoordinate(coord[1], coord[0]));
      }
    }
    this.coordinates = coords;
  }
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

  Future<IAPoint> pointFromCoordinate(IACoordinate coord) async {
    // TODO: native side not implemented
    throw ('not implemented');
  }

  Future<IACoordinate> coordinateFromPoint(IAPoint point) async {
    // TODO: native side not implemented
    throw ('not implemented');
  }
}

class IAVenue {
  final String id;
  final String name;
  late final List<IAFloorplan> floorplans;
  late final List<IAGeofence> geofences;

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
    floorplan =
        map.containsKey('floorPlan') ? IAFloorplan.fromMap(map['floorPlan']) : null;
    venue = map.containsKey('venue') ? IAVenue.fromMap(map['venue']) : null;
  }
}

enum IAPositioningMode {
  highAccuracy,
  lowPower,
}

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

abstract class IAListener {
  final UniqueKey key = UniqueKey();
  void onStatus(IAStatus status, String message);
  void onLocation(IALocation location);
  void onVenue(bool enter, IAVenue venue);
  void onFloorplan(bool enter, IAFloorplan floorplan);
  void onGeofence(bool enter, IAGeofence geofence);
  void onOrientation(double x, double y, double z, double w);
  void onHeading(double heading);
}

class IndoorAtlas {
  static const MethodChannel _ch = MethodChannel('com.indooratlas.flutter');

  static bool _initialized = false;
  static IAConfiguration? _currentConfig;
  static String? _traceId;
  static final Set<IAListener> _listeners = Set.identity();

  static IAVenue? _currentVenue;
  static IAFloorplan? _currentFloorplan;
  static IALocation? _currentLocation;

  static IAConfiguration? get configuration => _currentConfig;
  static String? get traceId => _traceId;
  static IAVenue? get venue => _currentVenue;
  static IAFloorplan? get floorplan => _currentFloorplan;
  static IALocation? get location => _currentLocation;

  static Future<T?> _invoke<T>(String method, [dynamic arguments]) {
    if (!_initialized && method != 'initialize') {
      throw ('IndoorAtlas SDK not initialized. Call IndoorAtlas.configure() first.');
    }
    return _ch.invokeMethod<T>(method, arguments);
  }

  static void _setupMethodCallHandler() {
    _ch.setMethodCallHandler((call) async {
      try {
        switch (call.method) {
          case 'onStatusChanged':
            final status = IAStatus.values[call.arguments['status']];
            final message = call.arguments['message'] as String;
            for (var l in _listeners) {l.onStatus(status, message);}
            break;
          case 'onLocationChanged':
            final loc = IALocation.fromMap(call.arguments);
            _currentLocation = loc;
            for (var l in _listeners) {l.onLocation(loc);}
            break;
          case 'onEnterRegion':
            _dispatchRegionEvent(true, _Region.fromMap(call.arguments));
            break;
          case 'onExitRegion':
            _dispatchRegionEvent(false, _Region.fromMap(call.arguments));
            break;
          case 'onGeofenceEvent':
            final geofence = IAGeofence.fromGeoJson(call.arguments['geofence']);
            final enter = call.arguments['type'] == 'enter';
            for (var l in _listeners) {l.onGeofence(enter, geofence);}
            break;
          case 'onOrientationChanged':
            final args = call.arguments;
            for (var l in _listeners) {l.onOrientation(args['x'], args['y'], args['z'], args['w']);}
            break;
          case 'onHeadingChanged':
            final args = call.arguments;
            for (var l in _listeners) {l.onHeading(args['heading']);}
            break;
          default:
            throw MissingPluginException('Method ${call.method} not implemented.');
        }
      } catch (e) {
        print('IndoorAtlas Flutter Error: $e');
      }
    });
  }

  static void _dispatchRegionEvent(bool enter, _Region region) {
    if (region.venue != null) {
      _currentVenue = enter ? region.venue : null;
      for (var l in _listeners) {l.onVenue(enter, region.venue!);}
    }
    if (region.floorplan != null) {
      _currentFloorplan = enter ? region.floorplan : null;
      for (var l in _listeners) {l.onFloorplan(enter, region.floorplan!);}
    }
  }
  
  static void _resetState() {
    if (_currentFloorplan != null) {
      for (var l in _listeners) {l.onFloorplan(false, _currentFloorplan!);}
      _currentFloorplan = null;
    }
    if (_currentVenue != null) {
      for (var l in _listeners) {l.onVenue(false, _currentVenue!);}
      _currentVenue = null;
    }
    _currentLocation = null;
    _traceId = null;
  }

  static Future<void> configure(IAConfiguration config) async {
    if (!_initialized) {
      await _invoke('initialize', {
        'apiKey': config.apiKey,
        'apiSecret': config.apiSecret,
      });
      _setupMethodCallHandler();
      _initialized = true;
    }

    _currentConfig = config;
    _resetState();

    if (_listeners.isEmpty) {
      await _invoke('stopPositioning');
    } else {
      await _invoke('startPositioning');
      await _invoke('lockIndoors', [config.indoorLock]);
      if (config.floorLock != null) {
        await _invoke('lockFloor', [config.floorLock!]);
      } else {
        await _invoke('unlockFloor');
      }
    }
     _traceId = await _invoke<String>('getTraceId');
  }

  static void subscribe(IAListener listener) {
    if (_listeners.add(listener)) {
      if (_currentVenue != null) listener.onVenue(true, _currentVenue!);
      if (_currentFloorplan != null) listener.onFloorplan(true, _currentFloorplan!);
      if (_currentLocation != null) listener.onLocation(_currentLocation!);

      if (_listeners.length == 1 && _currentConfig != null) {
        configure(_currentConfig!);
      }
    }
  }

  static void unsubscribe(IAListener listener) {
    if (_listeners.remove(listener)) {
      if (_listeners.isEmpty) {
        _invoke('stopPositioning');
        _resetState();
      }
    }
  }
}

typedef IAOnStatusCb = void Function(IAStatus status, String message);
typedef IAOnVenueCb = void Function(bool enter, IAVenue venue);
typedef IAOnFloorplanCb = void Function(bool enter, IAFloorplan floorplan);
typedef IAOnGeofenceCb = void Function(bool enter, IAGeofence geofence);
typedef IAOnOrientationCb = void Function(double x, double y, double z, double w);

class IACallbackListener extends IAListener {
  final IAOnStatusCb? onStatusCb;
  final ValueSetter<IALocation>? onLocationCb;
  final IAOnVenueCb? onVenueCb;
  final IAOnFloorplanCb? onFloorplanCb;
  final IAOnGeofenceCb? onGeofenceCb;
  final IAOnOrientationCb? onOrientationCb;
  final ValueSetter<double>? onHeadingCb;

  IACallbackListener({
    this.onStatusCb,
    this.onLocationCb,
    this.onVenueCb,
    this.onFloorplanCb,
    this.onGeofenceCb,
    this.onOrientationCb,
    this.onHeadingCb,
  });

  @override void onStatus(IAStatus status, String message) => onStatusCb?.call(status, message);
  @override void onLocation(IALocation position) => onLocationCb?.call(position);
  @override void onVenue(bool enter, IAVenue venue) => onVenueCb?.call(enter, venue);
  @override void onFloorplan(bool enter, IAFloorplan floorplan) => onFloorplanCb?.call(enter, floorplan);
  @override void onGeofence(bool enter, IAGeofence geofence) => onGeofenceCb?.call(enter, geofence);
  @override void onOrientation(double x, double y, double z, double w) => onOrientationCb?.call(x, y, z, w);
  @override void onHeading(double heading) => onHeadingCb?.call(heading);
}

class IndoorAtlasListener extends StatefulWidget {
  final Widget child;
  final IACallbackListener listener;
  final bool enabled;

  IndoorAtlasListener({
    Key? key,
    this.enabled = true,
    this.child = const SizedBox.shrink(),
    IAOnStatusCb? onStatus,
    ValueSetter<IALocation>? onLocation,
    IAOnVenueCb? onVenue,
    IAOnFloorplanCb? onFloorplan,
    IAOnGeofenceCb? onGeofence,
    IAOnOrientationCb? onOrientation,
    ValueSetter<double>? onHeading,
  })  : listener = IACallbackListener(
          onStatusCb: onStatus,
          onLocationCb: onLocation,
          onVenueCb: onVenue,
          onFloorplanCb: onFloorplan,
          onGeofenceCb: onGeofence,
          onOrientationCb: onOrientation,
          onHeadingCb: onHeading,
        ),
        super(key: key);

  @override
  State<StatefulWidget> createState() => _IndoorAtlasListenerState();
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
  void didUpdateWidget(IndoorAtlasListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled || widget.listener != oldWidget.listener) {
      if (oldWidget.enabled) IndoorAtlas.unsubscribe(oldWidget.listener);
      if (widget.enabled) IndoorAtlas.subscribe(widget.listener);
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
  Widget build(BuildContext context) {
    return widget.child;
  }
}