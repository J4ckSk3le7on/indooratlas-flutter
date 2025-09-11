# IndoorAtlas Flutter Plugin

A Flutter plugin for IndoorAtlas indoor positioning and wayfinding SDK. This plugin provides comprehensive indoor location services including positioning, geofencing, and wayfinding capabilities.

## Features

- **Indoor Positioning**: High-accuracy indoor location tracking
- **Wayfinding**: Turn-by-turn navigation inside buildings
- **Geofencing**: Monitor entry/exit events for defined areas
- **Floorplan Integration**: Automatic floorplan detection and coordinate conversion
- **Orientation & Heading**: Device orientation and compass heading tracking
- **Floor Detection**: Automatic floor level detection

## Installation

Add this plugin to your `pubspec.yaml`:

```yaml
dependencies:
  indooratlas:
    path: path/to/indooratlas-flutter-plugin
```

## Setup

### Android Setup

1. **Add permissions** to your `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
```

2. **Update minimum SDK version** in `android/app/build.gradle`:

```gradle
android {
    defaultConfig {
        minSdkVersion 24
    }
}
```

### Get Your API Key

1. Sign up at [IndoorAtlas Developer Portal](https://app.indooratlas.com/)
2. Create a new application
3. Copy your API key from the application settings

## Usage

### Basic Setup

```dart
import 'package:indooratlas/indooratlas.dart';

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _initializeIndoorAtlas();
  }

  Future<void> _initializeIndoorAtlas() async {
    // Initialize with your API key
    await IndoorAtlas.initialize(
      '1.0.0', // Plugin version
      'YOUR_API_KEY_HERE', // Your IndoorAtlas API key
    );

    // Request permissions
    await IndoorAtlas.requestPermissions();

    // Start positioning
    await IndoorAtlas.startPositioning();
  }
}
```

### Listening to Location Updates

Use the `IndoorAtlasListener` widget to automatically manage subscriptions:

```dart
IndoorAtlasListener(
  name: 'location_listener',
  onLocation: (IALocation location) {
    print('Location: ${location.latitude}, ${location.longitude}');
    print('Floor: ${location.floor}, Accuracy: ${location.accuracy}m');
  },
  onFloorplan: (bool enter, IAFloorplan floorplan) {
    if (enter) {
      print('Entered floorplan: ${floorplan.name}');
    } else {
      print('Exited floorplan: ${floorplan.name}');
    }
  },
  child: YourWidget(),
)
```

### Wayfinding

Start navigation to a specific destination:

```dart
// Start wayfinding to coordinates
await IndoorAtlas.startWayfinding(
  60.1696597, // latitude
  24.932497,  // longitude
  floor: 1,   // floor level
);

// Listen to route updates
IndoorAtlasListener(
  name: 'wayfinding_listener',
  onWayfindingUpdate: (IARoute route) {
    print('Route has ${route.legs.length} segments');
    print('Total distance: ${route.totalLength}m');
    
    if (route.hasError) {
      print('Route error: ${route.error}');
    }
  },
  child: YourWidget(),
)

// Stop wayfinding
await IndoorAtlas.stopWayfinding();
```

### Geofencing

Monitor geofence events:

```dart
IndoorAtlasListener(
  name: 'geofence_listener',
  onGeofences: (List<IAGeofence> geofences) {
    print('Available geofences: ${geofences.length}');
  },
  onGeofenceEvent: (String geofenceId, String eventType) {
    print('Geofence $geofenceId: $eventType');
    if (eventType == 'ENTER') {
      print('Entered geofence area');
    } else if (eventType == 'EXIT') {
      print('Exited geofence area');
    }
  },
  child: YourWidget(),
)
```

### Configuration Options

```dart
// Set positioning mode
await IndoorAtlas.setPositioningMode(0); // 0: High accuracy, 1: Low power, 2: Cart mode

// Set output thresholds
await IndoorAtlas.setOutputThresholds(1.0, 1.0); // 1m distance, 1s time

// Lock to indoor positioning only
await IndoorAtlas.lockIndoors(true);

// Lock to specific floor
await IndoorAtlas.lockFloor(2);

// Set orientation and heading sensitivities
await IndoorAtlas.setSensitivities(5.0, 5.0); // degrees
```

## API Reference

### Classes

#### `IALocation`
Represents a location update with positioning information.

Properties:
- `double latitude, longitude` - Geographic coordinates
- `IAPoint? pixel` - Pixel coordinates on floorplan (if available)
- `IAFloorplan? floorplan` - Current floorplan information
- `double accuracy` - Location accuracy in meters
- `double heading` - Device heading in degrees
- `int floor` - Floor level
- `DateTime timestamp` - Timestamp of the location update

#### `IAFloorplan`
Represents a building floorplan with coordinate transformation capabilities.

Properties:
- `String id, name` - Floorplan identification
- `String url` - Floorplan image URL
- `int floor` - Floor level
- `double bearing` - Floorplan rotation
- `int bitmapWidth, bitmapHeight` - Image dimensions
- `double widthMeters, heightMeters` - Physical dimensions
- `IACoordinate center, topLeft, topRight, bottomLeft, bottomRight` - Corner coordinates

#### `IARoute`
Represents a wayfinding route with navigation segments.

Properties:
- `List<IARouteLeg> legs` - Route segments
- `String error` - Error message (if any)
- `bool hasError` - Whether route has errors
- `double totalLength` - Total route distance

#### `IAGeofence`
Represents a geofenced area for monitoring.

Properties:
- `String id, name` - Geofence identification
- `int floor` - Floor level
- `String? payload` - Optional metadata
- `List<IACoordinate> coordinates` - Boundary coordinates

### Event Listeners

#### `IAListener`
Abstract base class for event handling. Override methods to handle specific events:

- `onLocation(IALocation location)` - Location updates
- `onFloorplan(bool enter, IAFloorplan floorplan)` - Floorplan entry/exit
- `onGeofences(List<IAGeofence> geofences)` - Available geofences
- `onGeofenceEvent(String id, String type)` - Geofence enter/exit events
- `onWayfindingUpdate(IARoute route)` - Wayfinding route updates
- `onStatus(IAStatus status, String message)` - Service status changes
- `onHeading(double heading)` - Compass heading changes
- `onOrientation(double x, double y, double z, double w)` - Device orientation

## Requirements

- **Flutter**: 3.16.0 or higher
- **Android**: API level 24 (Android 7.0) or higher
- **Kotlin**: 1.9.22 or higher
- **IndoorAtlas SDK**: 3.7.1

## Troubleshooting

### Common Issues

1. **Location not updating**
   - Ensure all required permissions are granted
   - Check that you're in a mapped venue
   - Verify your API key is correct

2. **Wayfinding not working**
   - Make sure positioning is active before starting wayfinding
   - Verify destination coordinates are within the venue
   - Check that wayfinding graphs are available for your venue

3. **Compilation errors**
   - Ensure minimum SDK version is set to 24
   - Check that all required permissions are added to AndroidManifest.xml
   - Verify Kotlin version compatibility

### Debug Mode

Enable debug logging to troubleshoot issues:

```dart
IndoorAtlas.debugEnabled = true;
```

## Support

For technical support and documentation:
- [IndoorAtlas Developer Portal](https://app.indooratlas.com/)
- [IndoorAtlas Documentation](https://docs.indooratlas.com/)
- [IndoorAtlas Support](https://indooratlas.freshdesk.com/)

## License

This plugin is licensed under the same terms as the IndoorAtlas SDK. Please refer to the IndoorAtlas license agreement for details.