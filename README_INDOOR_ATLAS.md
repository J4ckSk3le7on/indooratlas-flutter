# IndoorAtlas Flutter Plugin - Implementación Actualizada

## Cambios Realizados

### 1. **Compatibilidad con SDK 3.x**
- Actualizado el código Kotlin para usar las APIs más recientes de IndoorAtlas
- Eliminada la implementación con reflexión que causaba problemas
- Implementación directa de todas las interfaces necesarias

### 2. **Wayfinding Mejorado**
- Implementación correcta usando `IAWayfindingListener`
- Soporte para modos de routing:
  - `IAWayfindingMode.DEFAULT` (0)
  - `IAWayfindingMode.EXCLUDE_INACCESSIBLE` (1)
  - `IAWayfindingMode.EXCLUDE_ACCESSIBLE_ONLY` (2)
- Manejo adecuado de actualizaciones de ruta

### 3. **Geofences Automáticas**
- El SDK ahora maneja las geofences automáticamente
- Implementación de `IAGeofenceListener` para recibir eventos
- Eventos ENTER/EXIT correctamente procesados

### 4. **Mejoras en el Código Dart**
- Añadidas constantes para modos de wayfinding
- Mejor manejo de estado interno
- Callbacks más robustos

## Ejemplo de Uso

```dart
import 'package:flutter/material.dart';
import 'indoor_atlas.dart';

class IndoorNavigationScreen extends StatefulWidget {
  @override
  _IndoorNavigationScreenState createState() => _IndoorNavigationScreenState();
}

class _IndoorNavigationScreenState extends State<IndoorNavigationScreen> {
  IALocation? _currentLocation;
  IAFloorplan? _currentFloorplan;
  IARoute? _currentRoute;
  List<IAGeofence> _geofences = [];
  
  @override
  void initState() {
    super.initState();
    _initializeIndoorAtlas();
  }
  
  Future<void> _initializeIndoorAtlas() async {
    // Inicializar con tu API key
    await IndoorAtlas.initialize(
      '1.0.0',
      'YOUR_API_KEY_HERE',
    );
    
    // Solicitar permisos
    await IndoorAtlas.requestPermissions();
    
    // Configurar sensibilidad (opcional)
    await IndoorAtlas.setSensitivities(5.0, 5.0);
    
    // Iniciar posicionamiento
    await IndoorAtlas.startPositioning();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Indoor Navigation'),
      ),
      body: IndoorAtlasListener(
        name: 'main_listener',
        onLocation: (location) {
          setState(() {
            _currentLocation = location;
          });
          print('Location: ${location.latitude}, ${location.longitude}');
        },
        onFloorplan: (enter, floorplan) {
          setState(() {
            if (enter) {
              _currentFloorplan = floorplan;
              print('Entered floorplan: ${floorplan.name}');
            } else {
              _currentFloorplan = null;
              print('Exited floorplan');
            }
          });
        },
        onGeofences: (geofences) {
          setState(() {
            _geofences = geofences;
          });
        },
        onGeofenceEvent: (geofenceId, eventType) {
          print('Geofence $geofenceId: $eventType');
          // Mostrar notificación o realizar acción
        },
        onWayfindingUpdate: (route) {
          setState(() {
            _currentRoute = route;
          });
          if (route.legs.isNotEmpty) {
            print('Route updated: ${route.legs.length} legs');
          }
        },
        child: Column(
          children: [
            // Información de ubicación
            if (_currentLocation != null)
              Card(
                child: ListTile(
                  title: Text('Current Location'),
                  subtitle: Text(
                    'Lat: ${_currentLocation!.latitude.toStringAsFixed(6)}\n'
                    'Lon: ${_currentLocation!.longitude.toStringAsFixed(6)}\n'
                    'Floor: ${_currentLocation!.floor}\n'
                    'Accuracy: ${_currentLocation!.accuracy.toStringAsFixed(1)}m',
                  ),
                ),
              ),
            
            // Información del floorplan
            if (_currentFloorplan != null)
              Card(
                child: ListTile(
                  title: Text('Current Floorplan'),
                  subtitle: Text(
                    'Name: ${_currentFloorplan!.name}\n'
                    'Floor: ${_currentFloorplan!.floor}',
                  ),
                ),
              ),
            
            // Información de la ruta
            if (_currentRoute != null && _currentRoute!.legs.isNotEmpty)
              Card(
                child: ListTile(
                  title: Text('Active Route'),
                  subtitle: Text(
                    'Legs: ${_currentRoute!.legs.length}\n'
                    'Next turn: ${_currentRoute!.legs.first.direction.toStringAsFixed(0)}°\n'
                    'Distance: ${_currentRoute!.legs.first.length.toStringAsFixed(1)}m',
                  ),
                ),
              ),
            
            // Botones de control
            Padding(
              padding: EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: _startWayfinding,
                    child: Text('Start Wayfinding'),
                  ),
                  ElevatedButton(
                    onPressed: _stopWayfinding,
                    child: Text('Stop Wayfinding'),
                  ),
                ],
              ),
            ),
            
            // Lista de geofences
            if (_geofences.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _geofences.length,
                  itemBuilder: (context, index) {
                    final geofence = _geofences[index];
                    final isTriggered = IndoorAtlas.isGeofenceTriggered(geofence.id);
                    return ListTile(
                      title: Text(geofence.name),
                      subtitle: Text('Floor: ${geofence.floor}'),
                      trailing: Icon(
                        Icons.location_on,
                        color: isTriggered ? Colors.green : Colors.grey,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  void _startWayfinding() async {
    // Ejemplo: navegar a una coordenada específica
    await IndoorAtlas.startWayfinding(
      60.1699, // latitud destino
      24.9384, // longitud destino
      floor: 2, // piso destino
      mode: IAWayfindingMode.EXCLUDE_INACCESSIBLE, // excluir rutas inaccesibles
    );
  }
  
  void _stopWayfinding() async {
    await IndoorAtlas.stopWayfinding();
    setState(() {
      _currentRoute = null;
    });
  }
  
  @override
  void dispose() {
    IndoorAtlas.stopPositioning();
    super.dispose();
  }
}
```

## Configuración del Proyecto

### Android

1. En `android/app/build.gradle`, asegúrate de tener:

```gradle
android {
    compileSdkVersion 34
    
    defaultConfig {
        minSdkVersion 24
        targetSdkVersion 34
    }
}

dependencies {
    implementation 'com.indooratlas.android:indooratlas-android-sdk:3.6.9' // o la última versión
}
```

2. En `android/app/src/main/AndroidManifest.xml`, añade los permisos:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.INTERNET" />
```

### Flutter

En `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
```

## Características Implementadas

1. **Posicionamiento Indoor**
   - Localización en tiempo real
   - Detección automática de pisos
   - Orientación y heading

2. **Floorplans**
   - Carga automática al entrar en un venue
   - Conversión de coordenadas a píxeles

3. **Wayfinding**
   - Cálculo de rutas con diferentes modos
   - Actualizaciones en tiempo real
   - Soporte para rutas multi-piso

4. **Geofences**
   - Detección automática de geofences del venue
   - Eventos ENTER/EXIT
   - Estado de activación persistente

5. **Controles Avanzados**
   - Lock de piso
   - Lock indoor/outdoor
   - Ajuste de sensibilidad
   - Umbrales de actualización

## Notas Importantes

1. **API Key**: Necesitas una API key válida de IndoorAtlas
2. **Permisos**: La app debe solicitar permisos de ubicación en runtime
3. **Venue Setup**: El venue debe estar configurado correctamente en el portal de IndoorAtlas
4. **Floorplans**: Los floorplans deben estar alineados correctamente para navegación precisa

## Solución de Problemas

### Wayfinding no funciona
- Verifica que el venue tenga un grafo de navegación configurado
- Asegúrate de que las coordenadas de destino sean accesibles
- Revisa los logs para errores de ruta

### Geofences no se detectan
- Verifica que las geofences estén configuradas en el venue
- Asegúrate de que el posicionamiento esté activo
- Comprueba que estés dentro del área del venue

### Posicionamiento impreciso
- Calibra los sensores del dispositivo
- Asegúrate de tener buena señal WiFi/BLE
- Ajusta las sensibilidades si es necesario