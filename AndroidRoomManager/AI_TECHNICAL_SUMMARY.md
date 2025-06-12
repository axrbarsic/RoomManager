# Room Manager Android - Technical Summary for AI

## Project Status: PRODUCTION READY

### Core Architecture:
- **Kotlin + Jetpack Compose** - UI
- **Firebase Firestore** - Real-time sync with iOS
- **MVVM Pattern** - RoomViewModel + PreferencesManager
- **Auto-authentication** - hardcoded axrbarsic@gmail.com (no Google Sign-In)

### Key Features:
- **Real-time room status sync** with iOS app
- **Visual parity** with iOS (exact colors, 3D effects, gradients)
- **Dual cell styles**: Flat (default) + Classic 3D
- **Responsive design** - adapts to all screen sizes
- **Full localization** - 5 languages (ru/en/uk/es/ht) with auto-detection
- **Persistent settings** - all preferences saved

### Critical Files:
- `MainActivity.kt` - Main UI with responsive design
- `RoomCell.kt` - iOS-identical cell rendering (flat/3D styles)  
- `RoomViewModel.kt` - Business logic + Firebase sync
- `FirebaseManager.kt` - Auto-login + real-time listeners
- `LocaleHelper.kt` - Language auto-detection + switching
- `ResponsiveUtils.kt` - Adaptive sizing functions

### Auto-Login Configuration:
```kotlin
// FirebaseManager.kt
private const val HARDCODED_USER_ID = "38Pv7JGnFnT8IpVncfGVkYuPzLp2"
private const val HARDCODED_USER_EMAIL = "axrbarsic@gmail.com"
```

### Localization:
- **Auto-detects system language** on first launch
- **5 languages**: ru (default), en, uk, es, ht
- **Files**: `values/strings.xml`, `values-{lang}/strings.xml`
- **Language switching**: Settings → Language card

### Build Commands:
```bash
./gradlew assembleDebug        # Compile
./gradlew installDebug         # Install on device  
```

### Firebase Schema:
```
rooms/{roomId}:
- number: string
- color: enum (NONE/RED/GREEN/PURPLE/BLUE/WHITE)  
- isMarked: boolean
- isDeepCleaned: boolean
- availableTime: string
- {color}Timestamp: Timestamp
```

### Compilation: SUCCESSFUL ✅
### Dependencies: All configured ✅  
### iOS Sync: Active ✅ 