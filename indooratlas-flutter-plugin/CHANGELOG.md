# Changelog

## [1.0.0] - 2025-01-XX

### ✨ Major Updates & Modernization

#### 🔧 Framework & Dependencies
- **Updated Flutter compatibility** to 3.16.0+ with SDK constraints `>=3.0.0 <4.0.0`
- **Upgraded Kotlin** to version 1.9.22 for better performance and compatibility
- **Updated IndoorAtlas SDK** to version 3.7.1 (latest stable)
- **Enhanced Android configuration** with compile/target SDK 35 and minimum SDK 24
- **Improved Gradle configuration** with better dependency management

#### 🏗️ Architecture Improvements
- **Completely rewritten Dart API** with modern Flutter best practices
- **Enhanced type safety** with proper null safety throughout
- **Improved error handling** with comprehensive exception catching
- **Better memory management** with proper resource cleanup
- **Thread-safe operations** with proper main thread marshaling

#### 🧭 Wayfinding Enhancements
- **Robust wayfinding implementation** supporting both listener and PendingIntent approaches
- **Cross-SDK compatibility** using reflection for different IndoorAtlas SDK versions
- **Enhanced route handling** with comprehensive IARoute parsing
- **Better error reporting** for wayfinding failures
- **Automatic fallback mechanisms** when preferred wayfinding method unavailable

#### 📍 Location & Positioning
- **Improved location accuracy** with better filtering and validation
- **Enhanced geofence handling** with reliable enter/exit detection
- **Better floorplan integration** with coordinate transformation support
- **Optimized sensor handling** for orientation and heading updates
- **Configurable thresholds** for location update frequency

#### 🛡️ Permissions & Security
- **Modern permission handling** for Android 12+ (API 31+)
- **Bluetooth permissions** for Android 12+ compatibility
- **Proper permission request flow** with user-friendly callbacks
- **Enhanced security** with better API key handling

#### 🎯 Developer Experience
- **Comprehensive documentation** with usage examples and API reference
- **Modern example app** demonstrating all plugin features
- **Better debugging support** with optional debug logging
- **Improved error messages** with actionable troubleshooting steps
- **Type-safe API** with proper model classes and enums

### 🔄 API Changes

#### New Features
- `IARoute` class with comprehensive route information
- `IACallbackListener` for flexible event handling
- `IndoorAtlasListener` widget for automatic subscription management
- Enhanced `IALocation` with pixel coordinates and floorplan data
- Improved `IAGeofence` with polygon coordinate support
- Better `IAFloorplan` with coordinate transformation capabilities

#### Enhanced Methods
- `startWayfinding()` with mode parameter support
- `setSensitivities()` for orientation and heading configuration
- `lockIndoors()` and `lockFloor()` for positioning control
- Improved permission handling with `requestPermissions()`

#### Breaking Changes
- Minimum Flutter version increased to 3.16.0
- Minimum Android SDK increased to 24
- Some method signatures updated for better type safety
- Event callback structure modernized

### 🐛 Bug Fixes
- Fixed memory leaks in native code
- Resolved thread safety issues
- Improved wayfinding reliability
- Better handling of SDK initialization failures
- Fixed geofence event triggering accuracy
- Resolved coordinate transformation issues

### 📚 Documentation
- **Complete README** with setup and usage instructions
- **Development guide** with build and testing information
- **Comprehensive API documentation** with examples
- **Troubleshooting guide** for common issues
- **Architecture documentation** explaining plugin structure

### 🧪 Testing & Quality
- Enhanced error handling throughout the codebase
- Better logging for debugging and troubleshooting
- Improved code organization and maintainability
- Modern Kotlin and Dart coding standards
- Comprehensive null safety implementation

---

## Migration Guide from Previous Versions

### Required Changes

1. **Update minimum versions**:
   - Flutter: 3.16.0+
   - Android SDK: 24+
   - Kotlin: 1.9.22+

2. **Update permissions** in `AndroidManifest.xml`:
   ```xml
   <uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
   <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
   ```

3. **Update listener usage**:
   ```dart
   // Old way
   IndoorAtlas.subscribe(myListener);
   
   // New way (recommended)
   IndoorAtlasListener(
     name: 'my_listener',
     onLocation: (location) => handleLocation(location),
     child: MyWidget(),
   )
   ```

4. **Update wayfinding calls**:
   ```dart
   // Enhanced with optional mode parameter
   await IndoorAtlas.startWayfinding(lat, lon, floor: 1, mode: 1);
   ```

### Benefits of Upgrading

- ✅ Better performance and reliability
- ✅ Modern Flutter and Android compatibility
- ✅ Enhanced wayfinding capabilities
- ✅ Improved debugging and error handling
- ✅ Better developer experience
- ✅ Future-proof architecture

---

*For detailed upgrade instructions and troubleshooting, see [DEVELOPMENT.md](DEVELOPMENT.md)*