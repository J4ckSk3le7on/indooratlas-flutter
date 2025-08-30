# IndoorAtlas Flutter Plugin

IndoorAtlas SDK for flutter/dart, easily develop cross-platform applications

This project is still under development

Easily integratable UI and map widgets will come later

## Getting Started

Add this to your `pubspec.yaml`
```
indooratlas:
  git:
      url: https://github.com/IndoorAtlas/indooratlas-flutter.git
      ref: develop
      path: indooratlas-flutter-plugin
```

In your `android/app/build.gradle` change:
`flutter.compileSdkVersion` to `31`
`flutter.minSdkVersion` to `21`
`flutter.targetSdkVersion` to `30`

This project is a starting point for a Flutter
[plug-in package](https://flutter.dev/developing-packages/),
a specialized package that includes platform-specific implementation code for
Android and/or iOS.

## Usage

### Basic Setup

```dart
import 'package:indooratlas/indooratlas.dart';

void main() async {
  // Initialize IndoorAtlas
  await IndoorAtlas.initialize('1.0.0', 'YOUR_API_KEY');
  await IndoorAtlas.requestPermissions();
  await IndoorAtlas.startPositioning();
}
```

### Listening to Location and Geofence Events

```dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: IndoorAtlasListener(
        name: 'MyApp',
        onLocation: (location) {
          print('Location: ${location.latitude}, ${location.longitude}');
          print('Floor: ${location.floor}');
        },
        onGeofences: (geofences) {
          print('User is in ${geofences.length} geofence(s):');
          for (final geofence in geofences) {
            print('- ${geofence.name} (ID: ${geofence.id})');
            print('  Floor: ${geofence.floor}');
            print('  Payload: ${geofence.payload}');
          }
        },
        onFloorplan: (enter, floorplan) {
          if (enter) {
            print('Entered floorplan: ${floorplan.name}');
          } else {
            print('Exited floorplan: ${floorplan.name}');
          }
        },
        child: Scaffold(
          appBar: AppBar(title: Text('IndoorAtlas Demo')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Current Location:'),
                Text('${IndoorAtlas.location?.latitude ?? 'N/A'}, ${IndoorAtlas.location?.longitude ?? 'N/A'}'),
                Text('Floor: ${IndoorAtlas.location?.floor ?? 'N/A'}'),
                SizedBox(height: 20),
                Text('Current Geofences:'),
                Text('${IndoorAtlas.geofences.length} active geofence(s)'),
                for (final geofence in IndoorAtlas.geofences)
                  Text('- ${geofence.name}'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

### Getting Current Geofences

```dart
// Obtener las geofences actuales donde está el usuario
List<IAGeofence> currentGeofences = IndoorAtlas.geofences;

// O también usando el método específico
List<IAGeofence> venueGeofences = IndoorAtlas.getVenueGeofences();

// Verificar si el usuario está en una geofence específica
bool isInGeofence(String geofenceId) {
  return IndoorAtlas.geofences.any((g) => g.id == geofenceId);
}

// Nota: Las geofences se obtienen automáticamente desde la región actual
// cuando el usuario entra en un venue. Los métodos requestGeofences y removeGeofences
// están disponibles para compatibilidad futura con la API de IndoorAtlas.

// Solicitar monitoreo de geofences específicas (futuro)
// await IndoorAtlas.requestGeofences(['geofence_id_1', 'geofence_id_2']);

// Detener monitoreo de geofences (futuro)
// await IndoorAtlas.removeGeofences();
```

For help getting started with Flutter, view our
[online documentation](https://flutter.dev/docs), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

