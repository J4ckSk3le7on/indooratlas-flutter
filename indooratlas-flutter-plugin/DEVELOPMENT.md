# Development Guide

## Prerequisites

To build and test this plugin, you'll need:

1. **Flutter SDK** (3.16.0 or higher)
2. **Android SDK** (API level 24 or higher)
3. **Kotlin** (1.9.22 or higher)
4. **IndoorAtlas Developer Account** with API key

## Setup for Development

### 1. Flutter Environment

```bash
flutter doctor
flutter --version
```

### 2. Android SDK Setup

Create `android/local.properties` file with your Android SDK path:

```properties
sdk.dir=/path/to/your/android/sdk
```

### 3. API Key Configuration

Replace `YOUR_API_KEY_HERE` in the example app with your actual IndoorAtlas API key.

## Building the Plugin

### Dart Code Analysis

```bash
flutter analyze
```

### Android Code Compilation

```bash
cd android
./gradlew compileDebugKotlin
```

### Running the Example

```bash
cd example
flutter pub get
flutter run
```

## Testing

### Unit Tests

```bash
flutter test
```

### Integration Tests

To test the plugin with a real IndoorAtlas venue:

1. Ensure you have a mapped venue in your IndoorAtlas account
2. Update the example coordinates in `example/lib/main.dart`
3. Run the example app on a physical device
4. Test positioning, geofencing, and wayfinding features

## Key Implementation Details

### Wayfinding Compatibility

The plugin supports both listener-based and PendingIntent-based wayfinding APIs through reflection, ensuring compatibility across different IndoorAtlas SDK versions.

### Thread Safety

All IndoorAtlas SDK calls are properly marshaled to the main thread using `Handler(Looper.getMainLooper())`.

### Error Handling

Comprehensive error handling is implemented throughout the plugin with proper exception catching and logging.

### Memory Management

Proper cleanup is implemented in the `detach()` method to prevent memory leaks.

## Architecture

```
┌─────────────────┐
│   Flutter App   │
└─────────────────┘
         │
         ▼
┌─────────────────┐
│ indooratlas.dart│ ◄─── Dart API Layer
└─────────────────┘
         │
         ▼ (MethodChannel)
┌─────────────────┐
│ IAFlutterPlugin │ ◄─── Plugin Entry Point
└─────────────────┘
         │
         ▼
┌─────────────────┐
│ IAFlutterEngine │ ◄─── Core Implementation
└─────────────────┘
         │
         ▼
┌─────────────────┐
│ IndoorAtlas SDK │ ◄─── Native SDK
└─────────────────┘
```

## Troubleshooting

### Common Build Issues

1. **Gradle sync failed**: Ensure Android SDK is properly installed and `local.properties` is configured
2. **Kotlin compilation errors**: Check that Kotlin version in `build.gradle` matches your environment
3. **IndoorAtlas SDK not found**: Verify the SDK dependency version in `build.gradle`

### Runtime Issues

1. **Location not updating**: Check permissions and API key validity
2. **Wayfinding not working**: Ensure venue has wayfinding graphs enabled
3. **Crashes on startup**: Check logcat for IndoorAtlas initialization errors

## Contributing

1. Follow Kotlin coding conventions for Android code
2. Follow Dart style guide for Flutter code
3. Add comprehensive error handling for new features
4. Update documentation and examples for API changes
5. Test on both physical devices and emulators where possible