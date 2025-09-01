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
        onGeofenceEvent: (geofenceId, eventType) {
          print('Geofence $geofenceId: $eventType');
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
                Text('${IndoorAtlas.geofences.length} total geofence(s)'),
                Text('${IndoorAtlas.triggeredGeofences.length} active geofence(s)'),
                for (final geofence in IndoorAtlas.triggeredGeofences)
                  Text('- ${geofence.name} (ACTIVE)', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                for (final geofence in IndoorAtlas.geofences.where((g) => !IndoorAtlas.isGeofenceTriggered(g.id)))
                  Text('- ${geofence.name} (inactive)', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

### Real-time Geofence Visualization

Para implementar visualización en tiempo real de las geocercas (como en el ejemplo de IndoorAtlas), puedes usar un `StatefulWidget` que se actualice automáticamente:

```dart
class GeofenceMapWidget extends StatefulWidget {
  @override
  _GeofenceMapWidgetState createState() => _GeofenceMapWidgetState();
}

class _GeofenceMapWidgetState extends State<GeofenceMapWidget> {
  final List<Map<String, dynamic>> _geofenceCircles = [];
  
  @override
  void initState() {
    super.initState();
    // Suscribirse a eventos de IndoorAtlas
    IndoorAtlas.subscribe(_listener);
  }
  
  @override
  void dispose() {
    IndoorAtlas.unsubscribe(_listener);
    super.dispose();
  }
  
  final IAListener _listener = IACallbackListener(
    name: 'GeofenceMap',
    onLocation: (location) {
      // Actualizar visualización cuando cambia la ubicación
      _updateGeofenceVisualization();
    },
    onGeofences: (geofences) {
      // Actualizar lista de geocercas disponibles
      _updateGeofenceList(geofences);
    },
    onGeofenceEvent: (geofenceId, eventType) {
      // Actualizar estado visual de geocercas específicas
      _updateGeofenceState(geofenceId, eventType);
    },
  );
  
  void _updateGeofenceVisualization() {
    if (mounted) {
      setState(() {
        // Recalcular qué geocercas están activas
        // y actualizar colores/estilos visuales
      });
    }
  }
  
  void _updateGeofenceList(List<IAGeofence> geofences) {
    if (mounted) {
      setState(() {
        // Actualizar lista de geocercas disponibles
      });
    }
  }
  
  void _updateGeofenceState(String geofenceId, String eventType) {
    if (mounted) {
      setState(() {
        // Cambiar color/estilo de geocerca específica
        // basado en si está activa (ENTER) o inactiva (EXIT)
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Mapa o visualización de geocercas
        Container(
          height: 300,
          child: CustomPaint(
            painter: GeofencePainter(
              geofences: IndoorAtlas.geofences,
              triggeredGeofences: IndoorAtlas.triggeredGeofences,
              currentLocation: IndoorAtlas.location,
            ),
          ),
        ),
        
        // Lista de geocercas con estado
        Expanded(
          child: ListView.builder(
            itemCount: IndoorAtlas.geofences.length,
            itemBuilder: (context, index) {
              final geofence = IndoorAtlas.geofences[index];
              final isActive = IndoorAtlas.isGeofenceTriggered(geofence.id);
              
              return ListTile(
                title: Text(geofence.name),
                subtitle: Text('Floor: ${geofence.floor}'),
                trailing: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive ? Colors.green : Colors.grey,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// CustomPainter para dibujar geocercas
class GeofencePainter extends CustomPainter {
  final List<IAGeofence> geofences;
  final List<IAGeofence> triggeredGeofences;
  final IALocation? currentLocation;
  
  GeofencePainter({
    required this.geofences,
    required this.triggeredGeofences,
    this.currentLocation,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Implementar dibujo de geocercas
    // - Verde para geocercas activas
    // - Gris para geocercas inactivas
    // - Punto azul para ubicación actual
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
```

### Getting Current Geofences

```dart
// Obtener las geocercas actuales donde está el usuario
List<IAGeofence> currentGeofences = IndoorAtlas.geofences;

// Obtener solo las geocercas que están activamente activadas
List<IAGeofence> activeGeofences = IndoorAtlas.triggeredGeofences;

// Verificar si el usuario está en una geocerca específica
bool isInGeofence(String geofenceId) {
  return IndoorAtlas.isGeofenceTriggered(geofenceId);
}

// Obtener geocercas del venue actual
List<IAGeofence> venueGeofences = IndoorAtlas.getVenueGeofences();

// Nota: Las geocercas se obtienen automáticamente desde la región actual
// cuando el usuario entra en un venue. Los métodos requestGeofences y removeGeofences
// están disponibles para compatibilidad futura con la API de IndoorAtlas.

// Solicitar monitoreo de geocercas específicas (futuro)
// await IndoorAtlas.requestGeofences(['geofence_id_1', 'geofence_id_2']);

// Detener monitoreo de geocercas (futuro)
// await IndoorAtlas.removeGeofences();
```

### Key Features for Real-time Updates

1. **Automatic State Management**: El sistema mantiene automáticamente el estado de qué geocercas están activas
2. **Real-time Events**: Recibes eventos `onGeofenceEvent` cada vez que cambia el estado de una geocerca
3. **Location-based Updates**: Las geocercas se verifican automáticamente cada vez que cambia la ubicación
4. **Visual State Tracking**: Puedes usar `IndoorAtlas.isGeofenceTriggered()` para determinar el estado visual de cada geocerca

### Indoor-Only Mode Configuration

Para mejorar la precisión de las geocercas y estabilizar el bearing, puedes configurar el modo indoor exclusivo:

```dart
// Después de inicializar IndoorAtlas
await IndoorAtlas.initialize('1.0.0', 'YOUR_API_KEY');

// Configurar modo indoor exclusivo (como en la app de mapa de IndoorAtlas)
await IndoorAtlas.lockIndoors(true);

// Configurar sensibilidad de orientación para estabilizar el bearing
// Valores recomendados: 5.0 grados para ambos parámetros
await IndoorAtlas.setSensitivities(5.0, 5.0);

// Opcional: Bloquear a un piso específico si es necesario
// await IndoorAtlas.lockFloor(1);

// Iniciar posicionamiento
IndoorAtlas.startPositioning();
```

### Bearing vs Heading

**Para la mayoría de casos, usa HEADING en lugar de BEARING:**

- **Heading**: Reacciona rápidamente al movimiento del dispositivo, ideal para rotar mapas y mostrar dirección
- **Bearing**: Indica la dirección de caminata, reacciona lentamente y puede ser inestable

```dart
IndoorAtlasListener(
  name: 'MyApp',
  onHeading: (heading) {
    // Usar heading para rotación de mapa y dirección del usuario
    // heading: 0 = Norte, 90 = Este, 180 = Sur, 270 = Oeste
    _rotateMap(heading);
  },
  onLocation: (location) {
    // location.bearing puede ser inestable, mejor usar heading
    print('Bearing: ${location.bearing}'); // Menos estable
  },
  child: YourWidget(),
)
```

### Optimización de Rendimiento

1. **Modo Indoor Exclusivo**: `lockIndoors(true)` mejora la precisión en interiores
2. **Sensibilidad Configurada**: `setSensitivities(5.0, 5.0)` estabiliza el bearing
3. **Monitoreo de Regiones**: Las geocercas se cargan automáticamente al entrar en un venue
4. **Eventos Eficientes**: Solo se disparan eventos cuando cambia el estado real

For help getting started with Flutter, view our
[online documentation](https://flutter.dev/docs), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

