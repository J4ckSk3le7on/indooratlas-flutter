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
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<IAGeofence> _currentGeofences = [];
  IALocation? _currentLocation;
  String _status = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _initializeIndoorAtlas();
  }

  Future<void> _initializeIndoorAtlas() async {
    try {
      setState(() => _status = 'Initializing IndoorAtlas...');
      
      // Reemplaza 'YOUR_API_KEY' con tu API key real
      await IndoorAtlas.initialize('1.0.0', 'YOUR_API_KEY');
      
      setState(() => _status = 'Requesting permissions...');
      await IndoorAtlas.requestPermissions();
      
      setState(() => _status = 'Starting positioning...');
      await IndoorAtlas.startPositioning();
      
      setState(() => _status = 'Ready - Waiting for location updates');
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('IndoorAtlas Geofence Demo'),
      ),
      body: IndoorAtlasListener(
        name: 'DemoApp',
        onLocation: (location) {
          setState(() {
            _currentLocation = location;
          });
        },
        onGeofences: (geofences) {
          setState(() {
            _currentGeofences = geofences;
          });
          print('Geofences updated: ${geofences.length} active geofence(s)');
          for (final geofence in geofences) {
            print('- ${geofence.name} (ID: ${geofence.id}, Floor: ${geofence.floor})');
          }
        },
        onFloorplan: (enter, floorplan) {
          print('Floorplan ${enter ? 'entered' : 'exited'}: ${floorplan.name}');
        },
        onStatus: (status, message) {
          setState(() {
            _status = 'Status: ${status.name}';
          });
        },
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      SizedBox(height: 8),
                      Text(_status),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Location',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      SizedBox(height: 8),
                      if (_currentLocation != null) ...[
                        Text('Latitude: ${_currentLocation!.latitude.toStringAsFixed(6)}'),
                        Text('Longitude: ${_currentLocation!.longitude.toStringAsFixed(6)}'),
                        Text('Floor: ${_currentLocation!.floor}'),
                        Text('Accuracy: ${_currentLocation!.accuracy.toStringAsFixed(2)}m'),
                        Text('Heading: ${_currentLocation!.heading.toStringAsFixed(1)}°'),
                      ] else
                        Text('No location data available'),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Geofences (${_currentGeofences.length})',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      SizedBox(height: 8),
                      if (_currentGeofences.isNotEmpty) ...[
                        for (final geofence in _currentGeofences) ...[
                          Container(
                            padding: EdgeInsets.all(8),
                            margin: EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(
                                alpha: 0.1
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  geofence.name,
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text('ID: ${geofence.id}'),
                                Text('Floor: ${geofence.floor}'),
                                if (geofence.payload != null)
                                  Text('Payload: ${geofence.payload}'),
                                Text('Coordinates: ${geofence.coordinates.length} points'),
                              ],
                            ),
                          ),
                        ],
                      ] else
                        Text('No active geofences'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    IndoorAtlas.stopPositioning();
    super.dispose();
  }
}
