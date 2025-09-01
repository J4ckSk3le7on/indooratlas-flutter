import 'package:flutter/material.dart';
import 'package:indooratlas/indooratlas.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IndoorAtlas Geofence Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: GeofenceDemoPage(),
    );
  }
}

class GeofenceDemoPage extends StatefulWidget {
  @override
  _GeofenceDemoPageState createState() => _GeofenceDemoPageState();
}

class _GeofenceDemoPageState extends State<GeofenceDemoPage> {
  bool _isInitialized = false;
  String _status = 'Initializing...';
  String _traceId = 'N/A';
  
  @override
  void initState() {
    super.initState();
    _initializeIndoorAtlas();
  }
  
  Future<void> _initializeIndoorAtlas() async {
    try {
      // Reemplaza con tu API key real
      await IndoorAtlas.initialize('1.0.0', 'YOUR_API_KEY_HERE');
      await IndoorAtlas.requestPermissions();
      
      // Configurar modo indoor exclusivo para mejor precisión
      await IndoorAtlas.lockIndoors(true);
      
      // Configurar sensibilidad de orientación para estabilizar el bearing
      // Valores recomendados: 5.0 grados para ambos parámetros
      await IndoorAtlas.setSensitivities(5.0, 5.0);
      
      setState(() {
        _isInitialized = true;
        _status = 'Initialized successfully (Indoor mode)';
      });
      
      // Obtener Trace ID
      final traceId = await IndoorAtlas.getTraceId();
      if (traceId != null) {
        setState(() {
          _traceId = traceId;
        });
      }
      
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('IndoorAtlas Geofence Demo'),
        actions: [
          IconButton(
            icon: Icon(_isInitialized ? Icons.play_arrow : Icons.stop),
            onPressed: _isInitialized ? _togglePositioning : null,
          ),
        ],
      ),
      body: _isInitialized 
        ? IndoorAtlasListener(
            name: 'GeofenceDemo',
            onStatus: (status, message) {
              setState(() {
                _status = 'Status: ${status.name} - $message';
              });
            },
            onLocation: (location) {
              // La ubicación se maneja automáticamente para actualizar geocercas
            },
            onGeofences: (geofences) {
              // Las geocercas se actualizan automáticamente
            },
            onGeofenceEvent: (geofenceId, eventType) {
              // Mostrar notificación de cambio de estado
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Geofence $geofenceId: $eventType'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            onFloorplan: (enter, floorplan) {
              setState(() {
                _status = enter 
                  ? 'Entered floorplan: ${floorplan.name}'
                  : 'Exited floorplan: ${floorplan.name}';
              });
            },
            onHeading: (heading) {
              // Usar heading en lugar de bearing para mejor estabilidad
              // heading: 0 = Norte, 90 = Este, 180 = Sur, 270 = Oeste
              setState(() {
                _status = 'Heading: ${heading.toStringAsFixed(1)}° (Indoor mode)';
              });
            },
            child: _buildMainContent(),
          )
        : _buildInitializationContent(),
    );
  }
  
  Widget _buildInitializationContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text(_status),
          if (_status.startsWith('Error:'))
            ElevatedButton(
              onPressed: _initializeIndoorAtlas,
              child: Text('Retry'),
            ),
        ],
      ),
    );
  }
  
  Widget _buildMainContent() {
    return Column(
      children: [
        // Status bar
        Container(
          padding: EdgeInsets.all(16),
          color: Colors.grey[200],
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _status,
                  style: TextStyle(fontSize: 14),
                ),
              ),
              Text('Trace: $_traceId', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        
        // Geofence visualization
        Expanded(
          child: GeofenceVisualizationWidget(),
        ),
        
        // Control buttons
        Container(
          padding: EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: _startPositioning,
                child: Text('Start'),
              ),
              ElevatedButton(
                onPressed: _stopPositioning,
                child: Text('Stop'),
              ),
              ElevatedButton(
                onPressed: _getCurrentGeofences,
                child: Text('Refresh'),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  void _togglePositioning() {
    if (IndoorAtlas.location != null) {
      _stopPositioning();
    } else {
      _startPositioning();
    }
  }
  
  void _startPositioning() {
    IndoorAtlas.startPositioning();
    setState(() {
      _status = 'Positioning started';
    });
  }
  
  void _stopPositioning() {
    IndoorAtlas.stopPositioning();
    setState(() {
      _status = 'Positioning stopped';
    });
  }
  
  void _getCurrentGeofences() {
    final geofences = IndoorAtlas.geofences;
    final triggered = IndoorAtlas.triggeredGeofences;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Total: ${geofences.length}, Active: ${triggered.length}'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

class GeofenceVisualizationWidget extends StatefulWidget {
  @override
  _GeofenceVisualizationWidgetState createState() => _GeofenceVisualizationWidgetState();
}

class _GeofenceVisualizationWidgetState extends State<GeofenceVisualizationWidget> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Current location info
        Container(
          padding: EdgeInsets.all(16),
          child: _buildLocationInfo(),
        ),
        
        // Geofence list
        Expanded(
          child: _buildGeofenceList(),
        ),
      ],
    );
  }
  
  Widget _buildLocationInfo() {
    final location = IndoorAtlas.location;
    final floorplan = IndoorAtlas.floorplan;
    
    if (location == null) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No location data available'),
        ),
      );
    }
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Location (Indoor Mode)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Lat: ${location.latitude.toStringAsFixed(6)}'),
            Text('Lng: ${location.longitude.toStringAsFixed(6)}'),
            Text('Floor: ${location.floor}'),
            Text('Accuracy: ${location.accuracy.toStringAsFixed(2)}m'),
            Text('Heading: ${location.heading.toStringAsFixed(1)}° (stable direction)'),
            if (floorplan != null) ...[
              SizedBox(height: 8),
              Text('Floorplan: ${floorplan.name}'),
            ],
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Indoor-only mode enabled for better accuracy',
                style: TextStyle(
                  color: Colors.green[800],
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildGeofenceList() {
    final geofences = IndoorAtlas.geofences;
    
    if (geofences.isEmpty) {
      return Center(
        child: Text('No geofences available'),
      );
    }
    
    return ListView.builder(
      itemCount: geofences.length,
      itemBuilder: (context, index) {
        final geofence = geofences[index];
        final isActive = IndoorAtlas.isGeofenceTriggered(geofence.id);
        
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? Colors.green : Colors.grey,
                border: Border.all(color: Colors.black, width: 1),
              ),
            ),
            title: Text(
              geofence.name,
              style: TextStyle(
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? Colors.green : Colors.black,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ID: ${geofence.id}'),
                Text('Floor: ${geofence.floor}'),
                if (geofence.payload != null)
                  Text('Payload: ${geofence.payload}'),
                Text(
                  'Status: ${isActive ? "ACTIVE" : "Inactive"}',
                  style: TextStyle(
                    color: isActive ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            trailing: Icon(
              isActive ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isActive ? Colors.green : Colors.grey,
            ),
          ),
        );
      },
    );
  }
}
