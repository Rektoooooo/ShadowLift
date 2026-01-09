# 🏋️ ShadowLift

**ShadowLift** is a production-ready iOS fitness tracking app built with 100% native Apple technologies. This sophisticated, performance-optimized workout logging and planning app delivers a complete training experience with AI-powered insights, HealthKit integration, and advanced analytics—all with zero external dependencies.

> **🚀 Currently in TestFlight Beta** - Real users, real workouts, real results.

<img src="images/Hero image.png" alt="Hero section website">

## 📸 Screenshots

<div align="center">
  <img src="images/MainView.png" width="200" alt="Today's Workout">
  <img src="images/Calendar.png" width="200" alt="Workout Calendar">
  <img src="images/Graph.png" width="200" alt="Muscle Progress Graph">
  <img src="images/AISummary.png" width="200" alt="AI Workout Summary">
</div>

## 🌟 Core Features

### 💪 Workout Tracking
- **Custom Workout Splits** – Create unlimited workout routines (Push/Pull/Legs, Upper/Lower, etc.)
- **Exercise Tracking** – Detailed set/rep/weight logging with automatic progression tracking
- **10 Muscle Groups** – Chest, Back, Biceps, Triceps, Shoulders, Quads, Hamstrings, Calves, Glutes, Abs
- **Multiple Set Types** – Warm-up, Failure, Rest-Pause, Drop Sets, Bodyweight
- **Auto Day Progression** – Automatically advances through your split based on calendar
- **Workout Timer** – Automatic workout duration tracking

  <img src="images/MainView.png" width="300" alt="Today's Workout">

### 📅 Calendar & History
- **Workout Calendar** – Visual history with date-based workout retrieval
- **Complete History** – Access all past workouts with detailed logs
- **Progress Tracking** – See your training patterns and consistency over time

  <img src="images/Calendar.png" width="300" alt="Calendar">

### ⚡ Performance & Sync
- **Offline First** – Full functionality without internet connection
- **CloudKit Sync** – Cross-device sync with intelligent network monitoring
- **Performance Optimized** – No "gym lag" - tested under real gym conditions (60+ min sessions)
- **5-Second Timeout** – CloudKit operations never block UI

### 🏥 HealthKit Integration
- **Bidirectional Weight Sync** – Read and write body weight to Apple Health
- **BMI Tracking** – Auto-calculated with visual gauge display
- **Height Tracking** – Syncs with HealthKit
- **Workout Export** – Writes workout sessions to Apple Health
- **Weight Charts** – Historical weight visualization

  <img src="images/BMI.png" width="300" alt="BMI Tracking">

## 🔒 Premium Features (€2.99/month or €29.99/year)

### 🤖 AI Workout Summaries (iOS 26+)
- **On-Device AI Analysis** – Uses Apple's FoundationModels (100% private)
- **Performance Trends** – Strength progress and volume analysis
- **Muscle Balance Detection** – Identifies training imbalances
- **Personalized Recommendations** – AI-driven workout suggestions

  <img src="images/AISummary.png" width="300" alt="AI Summary">

### 🎯 Personal Record (PR) Tracking
- **Automatic PR Detection** – Tracks 1RM, 5RM, 10RM, and total volume PRs
- **Historical Comparison** – See how you stack up against previous workouts
- **PR Notifications** – Get notified when you hit a new personal record

### 📸 Progress Photos
- **Photo Timeline** – Track visual progress with pose guidance
- **Before/After Comparisons** – Swipe to compare photos
- **Body Part Categorization** – Front, Back, Side, Full Body, Custom
- **CloudKit Sync** – Photos sync across all your devices

### 📚 Pre-Built Templates
- **Push/Pull/Legs (PPL)** – Classic 6-day split
- **PHAT** – Power Hypertrophy Adaptive Training
- **Upper/Lower Split** – 4-day training program
- **Arnold Split** – Classic bodybuilding routine
- **Full Body** – 3-day full body routine

### 📈 Advanced Streak Analytics
- **Current Streak Tracking** – Days in a row with workouts
- **Longest Streak Record** – Track your personal best
- **Rest Day Logic** – Configurable rest days per week (streak-safe)
- **Weekly Pattern Charts** – Visualize training consistency
- **Streak Predictions** – See projected milestones

  <img src="images/Graph.png" width="300" alt="Profile with Muscle Analytics">

### 🎨 Custom Appearance
- **5 Accent Colors** – Blue, Green, Purple, Pink, Orange
- **Matching App Icons** – Themed icons for each color
- **Dark Mode Support** – Beautiful in light and dark themes

  <img src="images/Settings.png" width="300" alt="Settings">

## 🎁 Free Features

- ✅ Unlimited Workouts
- ✅ Custom Splits
- ✅ Exercise Tracking
- ✅ Calendar History
- ✅ HealthKit Integration
- ✅ CloudKit Sync
- ✅ BMI Calculator
- ✅ Muscle Group Charts
- ✅ Import/Export Splits (`.shadowliftsplit` files)

## 🏗️ Technical Architecture

### Tech Stack
- **Language:** Swift 5.9+
- **Framework:** 100% SwiftUI (no UIKit)
- **Storage:** SwiftData for persistent data
- **Authentication:** Apple Sign In
- **AI:** FoundationModels (iOS 26+, on-device)
- **Health:** HealthKit
- **Sync:** CloudKit with intelligent network monitoring
- **Photos:** PhotosUI, PhotoKit, AVFoundation
- **Architecture:** MVVM + ObservableObject
- **Target:** iOS 26.0+

### Zero External Dependencies
- ❌ No CocoaPods
- ❌ No Swift Package Manager packages
- ✅ Pure Apple frameworks only

### Core Data Models

#### Exercise Model
```swift
@Model class Exercise: ObservableObject, Codable {
    @Attribute(.unique) var id: UUID
    var name: String
    var sets: [Set]?                    // Nested SwiftData model
    var repGoal: String                 // "8-12", "5x5", "AMRAP"
    var muscleGroup: String
    var exerciseOrder: Int
    var done: Bool
    var completedAt: Date?
    var createdAt: Date
    var startTime: String
    var endTime: String
}
```

#### Set Model (Nested)
```swift
@Model class Set {
    var weight: Double              // kg or lbs
    var reps: Int
    var failure: Bool               // Trained to failure
    var warmUp: Bool                // Warm-up set
    var restPause: Bool             // Rest-pause set
    var dropSet: Bool               // Drop set
    var bodyWeight: Bool            // Bodyweight exercise
    var time: String
    var note: String
}
```

#### Other Models
- **Split**: Workout routine with multiple days
- **Day**: Single workout day with exercises
- **DayStorage**: Calendar-indexed completed workouts
- **UserProfile**: User data, streaks, stats
- **ProgressPhoto**: Progress photo tracking
- **PersonalRecord**: PR tracking data
- **SplitTemplate**: Pre-built workout programs

### Project Statistics
- **~20,748 lines of Swift code**
- **95 Swift files**
- **14 SwiftData models**
- **4 managers** (User, Appearance, Photo, PR)
- **23 settings views**
- **22 workout views**
- **Comprehensive test coverage**

## 📱 App Structure

```
ShadowLift/
├── GymlyApp.swift              # App entry point
├── ToolBar.swift               # Main TabView navigation
├── Config.swift                # Global app state singleton
├── Models/                     # SwiftData models (14 files)
│   ├── Exercise.swift
│   ├── Day.swift
│   ├── Split.swift
│   ├── DayStorage.swift
│   ├── UserProfile.swift
│   ├── ProgressPhoto.swift
│   └── PersonalRecord.swift
├── Logic/                      # Business logic
│   ├── WorkoutViewModel.swift  # Central coordinator (41,290 lines)
│   └── iCloudSyncManager.swift
├── Workout/                    # Workout views (22 files)
│   ├── TodayWorkoutView.swift
│   ├── ExerciseDetailView.swift
│   ├── SplitsView.swift
│   ├── SplitTemplatesView.swift
│   └── ProgressPhotoTimelineView.swift
├── Calendar/                   # Calendar views (3 files)
│   ├── CalendarView.swift
│   ├── CalendarDayView.swift
│   └── CalendarExerciseView.swift
├── Settings/                   # Settings views (23 files)
│   ├── NewSettingsView.swift
│   ├── ProfileView.swift
│   ├── HealthKitManager.swift
│   ├── PremiumSubscriptionView.swift
│   ├── StreakDetailView.swift
│   └── AISummary/              # AI features (5 files)
├── CloudKit/                   # CloudKit sync (2 files)
│   ├── CloudKitManager.swift
│   └── CloudKitSyncStatus.swift
├── Managers/                   # Manager classes (4 files)
│   ├── UserProfileManager.swift
│   ├── AppearanceManager.swift
│   ├── PhotoManager.swift
│   └── PRManager.swift
└── Cells/                      # Reusable UI components (11 files)
```

## 🚀 Installation & Setup

### Prerequisites
- **iOS 26.0+**
- **Xcode 15.0+**
- **Swift 5.9+**

### Setup Steps
```bash
git clone https://github.com/rektoooooo/shadowlift.git
cd shadowlift
open ShadowLift.xcodeproj
```

### Required Permissions
The app requires these permissions in `Info.plist`:
```xml
<key>NSHealthShareUsageDescription</key>
<string>ShadowLift needs access to read your health data to sync workout and body metrics</string>
<key>NSHealthUpdateUsageDescription</key>
<string>ShadowLift needs access to write workout data to your health records</string>
<key>NSCameraUsageDescription</key>
<string>ShadowLift needs camera access to take progress photos</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>ShadowLift needs photo library access to save progress photos</string>
```

## 🔧 Configuration

### Bundle Information
- **Bundle ID:** `com.icservis.GymlyFitness`
- **App Name:** ShadowLift
- **CloudKit Container:** `iCloud.com.gymly.app`
- **File Type UTI:** `com.shadowlift.split`
- **File Extension:** `.shadowliftsplit`

### Data Persistence
- **SwiftData**: Exercise data, workout history, splits, photos
- **UserDefaults**: User preferences via Config singleton
- **CloudKit**: Cross-device sync (optional)
- **HealthKit**: Health data integration (optional)

## 📊 Key Technical Achievements

### Performance Optimization
The app was battle-tested and optimized for real gym conditions:

- ✅ **"Gym Lag" Fix** – Eliminated UI blocking during poor cellular connections
- ✅ **Network Quality Monitoring** – Only syncs on good connections
- ✅ **5-Second CloudKit Timeout** – Prevents network from blocking UI
- ✅ **Workout Mode Detection** – Disables auto-sync during active workouts
- ✅ **Cached Computed Properties** – Prevents unnecessary recomputation
- ✅ **Memory Leak Fixes** – Proper observer cleanup

### Testing Philosophy
- **Real Gym Conditions** – Tests simulate 60+ minute sessions with poor cellular
- **Performance Targets** – <20ms per operation, no operation >100ms
- **Memory Stability** – No leaks during extended use
- **Network Resilience** – Tested with network throttling

### Test Coverage
```
GymlyTests/
├── WorkoutPerformanceTests.swift       # Unit performance tests
├── WorkoutFlowPerformanceTests.swift   # Extended session simulation
└── NetworkPerformanceTests.swift       # CloudKit performance

GymlyUITests/
└── GymWorkflowTests.swift              # Full UI automation
```

## 📖 File Format

Split files use JSON-based `.shadowliftsplit` format:

```json
{
  "id": "uuid-string",
  "name": "Push Pull Legs",
  "days": [
    {
      "id": "uuid-string",
      "name": "Push",
      "dayOfSplit": 1,
      "exercises": [
        {
          "id": "uuid-string",
          "name": "Bench Press",
          "sets": [...],
          "muscleGroup": "Chest",
          "repGoal": "8-12"
        }
      ]
    }
  ],
  "isActive": false,
  "startDate": "2024-01-01T00:00:00Z"
}
```

## 📈 Analytics & Progress

<div align="center">
  <img src="images/Graph.png" width="300" alt="Muscle Group Analytics">
  <img src="images/MyWeight.png" width="300" alt="Weight Tracking Graph">
</div>

- **Muscle Group Radar Charts** – Visualize training balance across 10 muscle groups
- **Weight Progression Graphs** – Track body weight changes over time
- **BMI Monitoring** – Visual gauge with health indicators
- **Workout Frequency** – See training consistency patterns
- **Volume Tracking** – Monitor total training volume

## 🧪 Testing & Beta Access

### TestFlight Access
For TestFlight beta access, contact: [support@shadowlift.app](mailto:support@shadowlift.app)

### Current Status
- ✅ Active TestFlight beta
- ✅ Real users in production
- ✅ Performance optimized for gym conditions
- ✅ iOS 26+ ready with AI features

## 📬 Contact & Support

### Get in Touch
- 📧 **Support:** [support@shadowlift.app](mailto:support@shadowlift.app)
- 📧 **General:** [hello@shadowlift.app](mailto:hello@shadowlift.app)
- 🔒 **Privacy:** [privacy@shadowlift.app](mailto:privacy@shadowlift.app)
- 💬 **Discord:** rektoooooo
- 📧 **Developer:** [sebastian.kucera@icloud.com](mailto:sebastian.kucera@icloud.com)
- 📸 **Instagram:** [@seb.kuc](https://www.instagram.com/seb.kuc/)

### Legal
- [Privacy Policy](Resources/Legal/privacy-policy.md)
- [Terms of Service](Resources/Legal/terms-of-service.md)
- [FAQ](Resources/Legal/faq.md)
- [About](Resources/Legal/about.md)

## 🎯 Recent Major Updates

### v1.0 (November 2025)
- ✅ **Complete Rebrand** – Gymly → ShadowLift
- ✅ **Advanced Streak Analytics** – Predictions, weekly patterns, detailed insights
- ✅ **PR Tracking System** – Automatic personal record detection
- ✅ **Legal Documentation** – Privacy Policy, Terms, FAQ, Support
- ✅ **Performance Fixes** – Eliminated "gym lag" with CloudKit optimization
- ✅ **Premium UI** – Modernized weight tracking and streak views
- ✅ **App Icon System** – 5 themed icons matching accent colors

## 🔮 Future Roadmap

### Planned Features
- ⏰ **Rest Timer** – Built-in rest timer between sets
- ⌚ **Apple Watch App** – Companion watch application
- 📚 **Exercise Database** – Expanded library with video instructions
- 🌍 **Localization** – Multi-language support
- ♿ **Accessibility** – Full VoiceOver and accessibility improvements
- 🏆 **Achievements** – Gamification and milestone tracking

### Technical Improvements
- 🚀 **Widget Support** – Home screen widgets for quick access
- 📊 **Advanced Analytics** – More detailed progress insights
- 🔄 **Enhanced Sync** – Faster, more reliable CloudKit operations
- 🎨 **More Themes** – Additional color schemes and icons

## 🏆 What Makes ShadowLift Unique

### Technical Excellence
- **Zero external dependencies** – Pure native Apple stack
- **Performance-first** – Tested and optimized for real gym conditions
- **Privacy-focused** – On-device AI, optional cloud sync
- **Production-ready** – ~20,748 lines of battle-tested code

### Architectural Strengths
- Clean MVVM separation with SwiftUI
- Reactive data flow with Combine
- Modern async/await concurrency
- Intelligent CloudKit sync with network awareness
- SwiftData for modern persistence

### Unique Features
- On-device AI workout summaries (iOS 26+)
- Network-aware CloudKit sync (prevents gym lag!)
- Progress photo tracking with pose guidance
- Streak system with intelligent rest day logic
- Pre-built premium split templates
- Muscle group radar chart analytics
- HealthKit bidirectional sync

## 📄 License

© 2024 ShadowLift. All rights reserved.

This is proprietary software developed by Sebastián Kučera.

---

**Built with ❤️ by Sebastián Kučera**

*Making fitness tracking simple, powerful, and beautiful.*
