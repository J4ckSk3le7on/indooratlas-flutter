import 'package:flutter/material.dart';
import 'package:indooratlas/indooratlas.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IndoorAtlas Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const IndoorAtlasExample(),
    );
  }
}

class IndoorAtlasExample extends StatefulWidget {
  const IndoorAtlasExample({Key? key}) : super(key: key);

  @override
  State<IndoorAtlasExample> createState() => _IndoorAtlasExampleState();
}

class _IndoorAtlasExampleState extends State<IndoorAtlasExample> {
  IALocation? _currentLocation;
  IAFloorplan? _currentFloorplan;
  List<IAGeofence> _geofences = [];
  List<IAGeofence> _triggeredGeofences = [];
  IARoute? _currentRoute;
  IACoordinate? _destination;
  String _status = 'Initializing...';
  bool _isPositioning = false;
  bool _isWayfinding = false;

  // Example destination coordinates (replace with your venue coordinates)
  static const double _destinationLat = 60.1696597;
  static const double _destinationLon = 24.932497;
  static const int _destinationFloor = 1;

  @override
  void initState() {
    super.initState();
    _initializeIndoorAtlas();
  }

  Future<void> _initializeIndoorAtlas() async {
    try {
      // Initialize with your API key
      await IndoorAtlas.initialize(
        '1.0.0', // Plugin version
        'YOUR_API_KEY_HERE', // Replace with your actual API key
      );

      // Request permissions
      await IndoorAtlas.requestPermissions();

      setState(() {
        _status = 'Initialized successfully';
      });
    } catch (e) {
      setState(() {
        _status = 'Initialization failed: $e';
      });
    }
  }

  void _startPositioning() async {
    try {
      await IndoorAtlas.startPositioning();
      setState(() {
        _isPositioning = true;
        _status = 'Positioning started';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to start positioning: $e';
      });
    }
  }

  void _stopPositioning() async {
    try {
      await IndoorAtlas.stopPositioning();
      setState(() {
        _isPositioning = false;
        _status = 'Positioning stopped';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to stop positioning: $e';
      });
    }
  }

  void _startWayfinding() async {
    try {
      await IndoorAtlas.startWayfinding(
        _destinationLat,
        _destinationLon,
        floor: _destinationFloor,
      );
      setState(() {
        _isWayfinding = true;
        _destination = const IACoordinate(_destinationLat, _destinationLon);
        _status = 'Wayfinding started to destination';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to start wayfinding: $e';
      });
    }
  }

  void _stopWayfinding() async {
    try {
      await IndoorAtlas.stopWayfinding();
      setState(() {
        _isWayfinding = false;
        _destination = null;
        _currentRoute = null;
        _status = 'Wayfinding stopped';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to stop wayfinding: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IndoorAtlas Example'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: IndoorAtlasListener(
        name: 'main_listener',
        onLocation: (location) {
          setState(() {
            _currentLocation = location;
          });
        },
        onFloorplan: (enter, floorplan) {
          setState(() {
            _currentFloorplan = enter ? floorplan : null;
          });
        },
        onGeofences: (geofences) {
          setState(() {
            _geofences = geofences;
          });
        },
        onGeofenceEvent: (geofenceId, eventType) {
          setState(() {
            _triggeredGeofences = IndoorAtlas.triggeredGeofences;
          });
        },
        onWayfindingUpdate: (route) {
          setState(() {
            _currentRoute = route;
          });
        },
        onDestinationSet: (destination) {
          setState(() {
            _destination = destination;
          });
        },
        onStatus: (status, message) {
          setState(() {
            _status = 'Status: ${status.name}';
          });
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(_status),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Control Buttons
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Controls',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isPositioning ? _stopPositioning : _startPositioning,
                              child: Text(_isPositioning ? 'Stop Positioning' : 'Start Positioning'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isPositioning 
                                  ? (_isWayfinding ? _stopWayfinding : _startWayfinding)
                                  : null,
                              child: Text(_isWayfinding ? 'Stop Wayfinding' : 'Start Wayfinding'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Location Card
              if (_currentLocation != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Location',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text('Latitude: ${_currentLocation!.latitude.toStringAsFixed(6)}'),
                        Text('Longitude: ${_currentLocation!.longitude.toStringAsFixed(6)}'),
                        Text('Floor: ${_currentLocation!.floor}'),
                        Text('Accuracy: ${_currentLocation!.accuracy.toStringAsFixed(2)}m'),
                        Text('Heading: ${_currentLocation!.heading.toStringAsFixed(1)}°'),
                        if (_currentLocation!.pixel != null) ...[
                          Text('Pixel X: ${_currentLocation!.pixel!.x.toStringAsFixed(1)}'),
                          Text('Pixel Y: ${_currentLocation!.pixel!.y.toStringAsFixed(1)}'),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Floorplan Card
              if (_currentFloorplan != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Floorplan',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text('Name: ${_currentFloorplan!.name}'),
                        Text('ID: ${_currentFloorplan!.id}'),
                        Text('Floor: ${_currentFloorplan!.floor}'),
                        Text('Size: ${_currentFloorplan!.bitmapWidth}x${_currentFloorplan!.bitmapHeight}'),
                        Text('Dimensions: ${_currentFloorplan!.widthMeters.toStringAsFixed(1)}m x ${_currentFloorplan!.heightMeters.toStringAsFixed(1)}m'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Wayfinding Card
              if (_destination != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Wayfinding',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text('Destination: ${_destination!.latitude.toStringAsFixed(6)}, ${_destination!.longitude.toStringAsFixed(6)}'),
                        if (_currentRoute != null) ...[
                          Text('Route legs: ${_currentRoute!.legs.length}'),
                          Text('Total length: ${_currentRoute!.totalLength.toStringAsFixed(2)}m'),
                          if (_currentRoute!.hasError)
                            Text('Error: ${_currentRoute!.error}', style: const TextStyle(color: Colors.red)),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Geofences Card
              if (_geofences.isNotEmpty) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Geofences (${_geofences.length})',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        ...._geofences.map((geofence) {
                          final isTriggered = _triggeredGeofences.any((g) => g.id == geofence.id);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Row(
                              children: [
                                Icon(
                                  isTriggered ? Icons.location_on : Icons.location_off,
                                  color: isTriggered ? Colors.green : Colors.grey,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${geofence.name} (Floor ${geofence.floor})',
                                    style: TextStyle(
                                      fontWeight: isTriggered ? FontWeight.bold : FontWeight.normal,
                                      color: isTriggered ? Colors.green : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}