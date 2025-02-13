# ReelAI - TikTok-Style Video App

A modern TikTok-style video application built with Flutter, featuring AI-powered video processing and social features.

## 🛠 Prerequisites

Before you begin, ensure you have the following installed:

- **Flutter SDK**: Version 3.19.6
  - Dart SDK: 3.2.3
  - Use FVM (Flutter Version Management) for version control
  ```bash
  fvm install 3.19.6
  fvm use 3.19.6
  ```

- **Java**: OpenJDK 17.0.14
  - Make sure JAVA_HOME is properly set
  - Ensure Java version matches exactly to avoid Gradle conflicts

- **Android SDK**:
  - Compile SDK: 34
  - Min SDK: 21
  - Target SDK: 34
  - Build Tools: 34.0.0
  - Platform Tools: Latest version
  - Command Line Tools: Latest version

- **Android NDK**: 
  - Version: 25.1.8937393 (exact version required)
  - Install through Android Studio SDK Manager
  - Set NDK_HOME environment variable

- **Gradle**:
  - Gradle version: 8.2
  - Android Gradle Plugin: 8.2.1
  - Ensure gradle-wrapper.properties matches these versions

## 🚀 Getting Started

1. **Clone the Repository**
   ```bash
   git clone [your-repo-url]
   cd ReelAI
   ```

2. **Install Flutter Dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup**
   - Place your `google-services.json` in `android/app/`
   - Enable required Firebase services:
     - Authentication
     - Cloud Functions
     - Storage
     - Firestore
     - App Check
     - Remote Config

4. **Environment Configuration**
   - Create necessary environment files (if not present)
   - Configure API keys for external services (OpenAI, etc.)

## 📱 Building the App

### Android
```bash
# Debug build
flutter build apk --debug

# Release build
flutter build apk --release
```

## 📦 Key Dependencies

### Firebase Integration
- firebase_core: ^2.27.1
- firebase_auth: ^4.17.9
- cloud_functions: ^4.6.9
- firebase_storage: ^11.6.10
- cloud_firestore: ^4.15.9

### Media Handling
- camera: ^0.10.5+5
- media_kit: ^1.1.10
- media_kit_video: ^1.2.4
- video_compress: ^3.1.2

### AI and Processing
- dart_openai: ^5.1.0
- path_provider: ^2.1.2

### UI and Navigation
- go_router: ^13.0.0
- provider: ^6.1.1
- perfect_freehand: ^2.3.1

## 🏗 Project Structure

```
ReelAI/
├── android/                 # Android-specific configuration
├── ios/                    # iOS-specific configuration
├── lib/                    # Main Dart source code
├── assets/                 # Static assets
│   ├── images/
│   └── icons/
└── test/                   # Test files
```

## 🔧 Android Configuration

The app is configured with the following specifications in `android/app/build.gradle`:

- Package Name: `com.reelai.reelai`
- Min SDK: 21
- Target SDK: 34
- NDK Version: 25.1.8937393
- Supported ABIs: armeabi-v7a, arm64-v8a, x86_64

## 🚨 Common Issues & Solutions

1. **Gradle Cache Issues**
   - Solution: Clean Gradle cache completely
   ```bash
   # On macOS/Linux
   rm -rf ~/.gradle/caches/
   # Then clean project
   cd android
   ./gradlew clean
   ```

2. **Missing MainActivity**
   - Ensure MainActivity.kt is in the correct package path:
   ```
   android/app/src/main/kotlin/com/reelai/reelai/MainActivity.kt
   ```
   - Verify package name in MainActivity.kt matches exactly:
   ```kotlin
   package com.reelai.reelai
   ```

3. **Build Failures**
   - Clean project and rebuild:
   ```bash
   flutter clean
   flutter pub get
   cd android
   ./gradlew clean
   cd ..
   flutter build apk
   ```

4. **Transcoder Issues**
   - If you encounter jetified-transcoder metadata issues:
   ```bash
   cd android
   ./gradlew cleanBuildCache
   cd ..
   flutter clean
   flutter pub get
   ```

5. **SDK Location Issues**
   - Create/update `local.properties` in the android folder:
   ```properties
   sdk.dir=/path/to/your/Android/sdk
   flutter.sdk=/path/to/your/flutter/sdk
   ```
   - Ensure paths have no spaces and use correct format for your OS

6. **Flutter SDK Not Found**
   - Make sure flutter is in your PATH
   - Verify flutter doctor shows no issues:
   ```bash
   flutter doctor -v
   ```
   - Check that Android Studio has Flutter plugin installed

## 📝 Additional Notes

- The app uses Material Design 3
- Supports video compression and processing
- Includes drawing functionality
- Integrated with OpenAI for AI features

## 🔐 Security

- API keys should be stored securely
- Firebase configuration files should be kept private
- Follow security best practices for handling user data

## 📄 License

[Your License Information Here]

## 👥 Contributing

[Your Contributing Guidelines Here]
