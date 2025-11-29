# Gymly - Claude Code Context Document

## Project Overview

**Gymly** is a production-ready iOS fitness tracking application built with 100% native Apple technologies. This is a sophisticated, performance-optimized workout logging and planning app with ~17,600 lines of Swift code, currently in active TestFlight beta.

**Critical Context:**
- **Zero external dependencies** - Pure Apple frameworks only
- **Real users in production** - Performance and UX are critical
- **Active development** - Recent major performance fixes for "gym lag" issue
- **Premium features** - Some features behind premium flag (currently enabled for testing)

### Key Stats
- **Language:** Swift 5.9+
- **Platform:** iOS 17.0+ (iOS 26+ for AI features)
- **Architecture:** MVVM with SwiftUI + SwiftData
- **Lines of Code:** ~17,615 lines
- **Developer:** Sebastián Kučera
- **Bundle ID:** com.icservis.GymlyFitness

## Technology Stack

### Core Frameworks (All Native Apple)
```
SwiftUI           - 100% declarative UI (no UIKit)
SwiftData         - Modern persistence (replaces Core Data)
HealthKit         - Weight, BMI, height, workout data sync
CloudKit          - iCloud cross-device sync
AuthenticationServices - Apple Sign In
FoundationModels  - iOS 26+ on-device LLM for workout summaries
Combine           - Reactive data flow
PhotosUI/PhotoKit - Progress photo management
AVFoundation      - Camera for progress photos
Network           - Network quality monitoring for intelligent sync
```

### Important: NO Third-Party Dependencies
- No CocoaPods, SPM packages, or external frameworks
- All functionality built with Apple's native APIs
- Simplifies debugging and ensures App Store compatibility

## Directory Structure & Key Files

### Critical Entry Points
```
GymlyApp.swift              - App entry, ModelContainer setup, file import handling
ToolBar.swift               - Main TabView (Routine/Calendar/Settings)
Config.swift                - Global app state singleton (ObservableObject)
Logic/WorkoutViewModel.swift - Core business logic (1,000+ lines)
```

### Models (SwiftData) - `/Models/`
```
Exercise.swift              - Exercise with nested Set model
Day.swift                   - Workout day
Split.swift                 - Workout routine/split
DayStorage.swift            - Calendar-based completed workout storage
UserProfile.swift           - User profile, streak tracking
ProgressPhoto.swift         - Progress photo tracking
SplitTemplate.swift         - Pre-built templates (PPL, PHAT, etc.)
WeightPoint.swift           - HealthKit weight data
GraphEntry.swift            - Muscle group analytics
FitnessProfile.swift        - User goals & preferences
MuscleGroup.swift           - UI muscle group grouping
```

### ViewModels & Business Logic - `/Logic/`
```
WorkoutViewModel.swift      - CENTRAL BUSINESS LOGIC (read this first!)
iCloudSyncManager.swift     - CloudKit sync coordination
```

### Managers - `/Managers/`
```
UserProfileManager.swift    - Profile operations, streak calculations
AppearanceManager.swift     - Theme & accent color management
PhotoManager.swift          - Progress photo handling
```

### Views by Feature

**Workout** (`/Workout/`) - 20 files
```
TodayWorkoutView.swift      - Main workout interface
ExerciseDetailView.swift    - Exercise tracking with sets
ShowSplitDayView.swift      - Day-specific workout display
SplitsView.swift            - Split management
SplitTemplatesView.swift    - Pre-built template selection
WorkoutSummaryView.swift    - Post-workout analytics
CreateExerciseView.swift    - Add exercise flow
EditExerciseView.swift      - Edit exercise metadata
ProgressPhotoTimelineView.swift   - Photo gallery
```

**Calendar** (`/Calendar/`) - 3 files
```
CalendarView.swift          - Workout history calendar
CalendarDayView.swift       - Individual day view
CalendarExerciseView.swift  - Historical exercise viewer
```

**Settings** (`/Settings/`) - 18 files
```
NewSettingsView.swift       - Main settings interface
ProfileView.swift           - User profile
HealthKitManager.swift      - HealthKit operations
ConnectionsView.swift       - HealthKit integration UI
FitnessProfileSetupView.swift - Onboarding
AISummary/                  - 5 files for AI workout analysis
  ├── WorkoutSummarizer.swift
  ├── AISummaryView.swift
  └── ...
```

**CloudKit** (`/CloudKit/`) - 2 files
```
CloudKitManager.swift       - CloudKit operations
CloudKitSyncStatus.swift    - Sync status tracking
```

**Reusable Components** (`/Cells/`) - 9 files
```
SetCell.swift               - Set display
SetWeightCell.swift         - Weight input
SetRepetitionsCell.swift    - Reps input
SetTypeCell.swift           - Set type toggles
BMIGaugeView.swift          - BMI visualization
WeightChart.swift           - Weight progress chart
```

## Core Data Models (SwiftData)

### Hierarchical Relationship
```
Split (1) ──cascade──> Day (many) ──nullify──> Exercise (many) ──cascade──> Set (many)
```

### Key Model: Exercise (with nested Set)
```swift
@Model class Exercise: ObservableObject, Codable {
    @Attribute(.unique) var id: UUID
    var name: String
    var sets: [Set]?                    // Nested SwiftData model
    var repGoal: String                 // Flexible format: "8-12", "5x5", "AMRAP"
    var muscleGroup: String             // One of 10 muscle groups
    var exerciseOrder: Int              // For ordering in UI
    var done: Bool                      // Completion status
    var completedAt: Date?              // Completion timestamp
    var createdAt: Date
    var startTime: String
    var endTime: String

    // Nested Set model - NOT a separate @Model!
    @Model class Set {
        var weight: Double              // Weight in kg or lbs
        var reps: Int
        var failure: Bool               // Trained to failure
        var warmUp: Bool                // Warm-up set
        var restPause: Bool             // Rest-pause set
        var dropSet: Bool               // Drop set
        var bodyWeight: Bool            // Bodyweight exercise
        var time: String                // Timestamp
        var note: String                // Set-specific notes
    }
}
```

### Model: Split
```swift
@Model class Split: ObservableObject, Codable {
    @Attribute(.unique) var id: UUID
    var name: String
    var days: [Day]?
    var isActive: Bool                  // Only one active split at a time
    var startDate: Date
    var lastUpdated: Date
}
```

### Model: Day
```swift
@Model class Day: ObservableObject, Codable {
    @Attribute(.unique) var id: UUID
    var name: String                    // e.g., "Push", "Pull", "Legs"
    var dayOfSplit: Int                 // Position in split (1-indexed)
    var exercises: [Exercise]?
    var date: String                    // Format: "yyyy-MM-dd"
}
```

### Model: UserProfile
```swift
@Model class UserProfile: ObservableObject {
    @Attribute(.unique) var id: UUID
    var username: String
    var email: String
    var heightCm: Double
    var weightKg: Double
    var age: Int
    var bmi: Double
    var currentStreak: Int              // Current workout streak
    var longestStreak: Int              // Record streak
    var lastWorkoutDate: Date?
    var restDaysPerWeek: Int            // For streak calculation
    var isStreakPaused: Bool
    @Attribute(.externalStorage) var profileImage: Data?
}
```

## Architecture Patterns

### 1. Config Singleton Pattern
**File:** `Config.swift`

The `Config` class is the **single source of truth** for app-wide state. It's an `ObservableObject` with all properties using `@Published` and `didSet` to auto-persist to `UserDefaults`.

**Critical Properties:**
```swift
class Config: ObservableObject {
    @Published var splitStarted: Bool           // Has user started a split?
    @Published var dayInSplit: Int              // Current day index
    @Published var splitLength: Int             // Total days in active split
    @Published var lastUpdateDate: Date         // Last app update for day progression
    @Published var isUserLoggedIn: Bool         // Apple Sign In status
    @Published var graphDataValues: [Double]    // Muscle group radar data (10 values)
    @Published var totalWorkoutTimeMinutes: Int // Cumulative workout time
    @Published var isCloudKitEnabled: Bool      // CloudKit sync toggle
    @Published var isHealtKitEnabled: Bool      // HealthKit sync toggle (typo in original)
    @Published var isPremium: Bool              // Premium subscription status

    // Fitness Profile
    @Published var hasCompletedFitnessProfile: Bool
    @Published var fitnessGoal: String          // Muscle Building, Strength, Weight Loss, etc.
    @Published var equipmentAccess: String      // Full Gym, Home Gym, Minimal, Bodyweight
    @Published var experienceLevel: String      // Beginner, Intermediate, Advanced
    @Published var trainingDaysPerWeek: Int

    // All properties auto-persist to UserDefaults via didSet
}
```

**Usage Pattern:**
```swift
// Inject into views via @EnvironmentObject
ToolBar()
    .environmentObject(config)

// Access in views
@EnvironmentObject var config: Config
```

### 2. MVVM Architecture
```
View (SwiftUI) ──> ViewModel (WorkoutViewModel) ──> Model (SwiftData)
       ↑                      ↓
       └──────── Config ──────┘
```

**WorkoutViewModel** is the central coordinator for all workout-related operations. It holds a reference to `Config` and `ModelContext`.

### 3. SwiftData Query Pattern
```swift
// In views, query SwiftData directly
@Query(sort: \Split.lastUpdated, order: .reverse) private var splits: [Split]
@Query private var exercises: [Exercise]

// Or fetch via ViewModel
let allSplits = viewModel.getAllSplits()
```

### 4. Observable Pattern with Combine
- All managers use `@MainActor` for thread-safe UI updates
- `@Published` properties trigger view updates
- NotificationCenter for cross-component communication

### 5. Deep Copy Pattern for Codable Models
**Critical for import/export and duplication:**
```swift
func copy() -> Exercise {
    let newExercise = Exercise(
        id: UUID(),  // NEW UUID - critical!
        name: self.name,
        // ... copy all properties
    )
    newExercise.sets = self.sets?.map { $0.copySets() }  // Deep copy sets
    return newExercise
}
```

## Critical Features & Implementation Details

### 1. Workout Split System

**Concept:** A "split" is a workout routine (e.g., Push/Pull/Legs). Each split has multiple "days", each day has multiple "exercises", each exercise has multiple "sets".

**Active Split Logic:**
- Only ONE split can be active at a time (`split.isActive = true`)
- Config tracks current day in split (`config.dayInSplit`)
- Day automatically progresses based on calendar (see `updateDayInSplit()`)

**Day Progression Algorithm:**
```swift
// WorkoutViewModel.swift
func updateDayInSplit() -> Int {
    let daysPassed = numberOfDaysBetween(start: config.lastUpdateDate, end: Date())
    let totalDays = config.dayInSplit + daysPassed
    let newDay = (totalDays - 1) % activeSplit.days.count + 1
    config.lastUpdateDate = Date()
    return newDay
}
```

**Split Templates:**
- 5 pre-built premium templates: PPL, PHAT, Upper/Lower, Arnold Split, Full Body
- Import/export as `.gymlysplit` files (JSON-based Codable)
- File type registered with UTI: `com.gymly.split`

### 2. Exercise Tracking

**10 Muscle Groups (Enum):**
```swift
enum MuscleGroupEnum: String, CaseIterable {
    case chest, back, biceps, triceps, shoulders
    case quads, hamstrings, calves, glutes, abs
}
```

**Set Types (Boolean Flags):**
Instead of enum, uses multiple booleans for flexibility:
- `warmUp` - Warm-up set
- `failure` - Trained to failure
- `restPause` - Rest-pause technique
- `dropSet` - Drop set
- `bodyWeight` - Bodyweight exercise

**Rep Goal Format (String):**
Flexible format stored as string:
- "8-12" (range)
- "5x5" (sets x reps)
- "AMRAP" (as many reps as possible)
- "20" (exact number)

**Exercise Completion:**
- Each exercise has `done: Bool` flag
- When completed, `completedAt: Date?` is set
- Copied to `DayStorage` for calendar persistence

### 3. Calendar & Workout History

**Storage Strategy:**
- **DayStorage** model stores completed workouts indexed by date string ("yyyy-MM-dd")
- Allows quick lookup for calendar display
- Exercises are deep-copied to DayStorage on completion

**Date String Convention:**
```swift
// ALWAYS use this format for dates
let dateFormatter = DateFormatter()
dateFormatter.dateFormat = "yyyy-MM-dd"
let dateString = dateFormatter.string(from: Date())
```

### 4. HealthKit Integration

**File:** `Settings/HealthKitManager.swift`

**Permissions Required:**
```swift
// Read
HKQuantityType(.height)
HKQuantityType(.bodyMass)  // weight
HKCharacteristicType(.dateOfBirth)  // age

// Write
HKQuantityType(.height)
HKQuantityType(.bodyMass)
HKWorkout  // workout sessions
```

**Bidirectional Sync:**
- User can write weight to HealthKit from app
- App reads weight from HealthKit for charts
- BMI auto-calculated from weight + height

**BMI Calculation:**
```swift
let bmi = weight(kg) / (height(m) * height(m))
```

### 5. CloudKit Sync (CRITICAL - Recently Fixed!)

**File:** `CloudKit/CloudKitManager.swift`

**The "Gym Lag" Problem (FIXED Oct 2024):**
- App performed well at home but lagged terribly in gym after 30-60 minutes
- Root cause: CloudKit sync blocked UI on poor cellular connection
- Solution: Made sync fully async with network monitoring + timeouts

**Current Implementation:**
```swift
// Network quality monitoring
import Network

class CloudKitManager {
    private let networkMonitor = NWPathMonitor()
    private var networkQuality: NetworkQuality = .unknown

    enum NetworkQuality {
        case excellent  // WiFi
        case good       // Strong cellular
        case poor       // Weak cellular
        case offline
    }

    // Only sync on good connections
    func shouldAutoSync() -> Bool {
        return networkQuality == .excellent || networkQuality == .good
    }

    // 5 second timeout to prevent UI blocking
    func syncWithTimeout() async throws {
        try await withTimeout(seconds: 5) {
            await performSync()
        }
    }
}
```

**Workout Mode Detection:**
- Disables auto-sync during active workouts
- Prevents sync from competing with UI updates during set logging

**Synced Data:**
- User profile (username, email, stats)
- Profile images (using `@Attribute(.externalStorage)`)
- Workout splits
- Progress photos

**Container:** `iCloud.com.gymly.app` (private database only)

### 6. AI Workout Summaries (iOS 26+)

**File:** `Settings/AISummary/WorkoutSummarizer.swift`

**Uses Apple's FoundationModels Framework:**
```swift
class WorkoutSummarizer {
    private let model = LLMModel.default  // On-device LLM

    func generateSummary(workouts: [DayStorage]) async throws -> WorkoutSummary {
        let prompt = buildPrompt(from: workouts)
        let response = try await model.generate(prompt)
        return parse(response)
    }
}
```

**Analysis Includes:**
- Performance trends (strength progress, volume changes)
- Muscle imbalances (radar chart analysis)
- Personal records (PRs)
- Consistency patterns
- Personalized recommendations

**Key Point:** Fully on-device, no external API calls, completely private!

### 7. Progress Photos (Premium)

**File:** `Workout/ProgressPhotoTimelineView.swift`

**Features:**
- Camera integration with pose guidance overlay
- Before/after comparison view with swipe
- Timeline gallery with date markers
- Body part categorization (Front, Back, Side, Full Body, Custom)
- CloudKit sync for cross-device access

**Storage:**
- Photos stored with `@Attribute(.externalStorage)` in SwiftData
- Automatically backed up to CloudKit if enabled

### 8. Streak Tracking

**File:** `Managers/UserProfileManager.swift`

**Streak Algorithm:**
```swift
func calculateStreak(workoutDate: Date) {
    let daysSinceLastWorkout = days(from: lastWorkoutDate, to: workoutDate)
    let maxAllowedGap = 1 + restDaysPerWeek  // e.g., 1 + 2 = 3 days max gap

    if daysSinceLastWorkout <= maxAllowedGap {
        currentStreak += 1
        if currentStreak > longestStreak {
            longestStreak = currentStreak
        }
    } else {
        currentStreak = 1  // Reset streak
    }

    lastWorkoutDate = workoutDate
}
```

**Rest Day Logic:**
- User configures rest days per week (default: 2)
- Streak allows gap of `1 + restDaysPerWeek` days
- Example: 2 rest days = 3 day max gap before streak breaks

**Streak Pause:**
- User can pause streak (vacation, injury, etc.)
- Preserves current streak value
- Resumes counting when unpaused

### 9. Theming & Customization

**File:** `Managers/AppearanceManager.swift`

**5 Accent Colors:**
- Blue (default)
- Green
- Purple
- Pink
- Orange

**Alternate App Icons:**
- 5 icons matching accent colors
- Configured in `Info.plist` under `CFBundleAlternateIcons`

**Implementation:**
```swift
// Change icon
UIApplication.shared.setAlternateIconName("AppIcon-Blue")

// Change accent color
@AppStorage("accentColor") private var accentColorName: String = "blue"
```

### 10. Performance Optimizations

**Recent Fixes (Oct 2024):**

**Problem:** UI lag during extended gym sessions (60+ minutes)

**Solutions:**
1. **CloudKit async + timeout** - Prevents network blocking UI
2. **Network quality monitoring** - Only sync on good connections
3. **Cached computed properties** - Avoid recomputation in TodayWorkoutView
4. **GraphEntry simplification** - Recalculate from DB instead of accumulating IDs
5. **Memory leak fixes** - Proper observer cleanup

**TodayWorkoutView Optimization:**
```swift
@State private var cachedGroupedExercises: [(String, [Exercise])] = []
@State private var cachedGlobalOrderMap: [UUID: Int] = [:]

// Only recompute when exercises actually change
.onChange(of: exercises) {
    cachedGroupedExercises = groupExercisesByMuscle()
    cachedGlobalOrderMap = buildGlobalOrderMap()
}
```

## Testing Strategy

### Test Files
```
GymlyTests/
├── WorkoutPerformanceTests.swift       - Unit performance tests
├── WorkoutFlowPerformanceTests.swift   - Extended session simulation (50+ ops)
└── NetworkPerformanceTests.swift       - CloudKit performance

GymlyUITests/
└── GymWorkflowTests.swift              - Full UI automation
```

### Critical Tests

**testExtendedGymSessionPerformance:**
- Simulates 50 consecutive set edits
- Measures time degradation over extended use
- **Target:** <20ms per operation, no operation >100ms
- **Why:** Prevents "gym lag" regression

**testGymSessionStressTest (UI):**
- Real UI interactions for 50 operations
- **Target:** <0.5s per operation
- **Why:** Detects UI lag under real-world load

**testCloudKitSyncDoesNotBlockMainThread:**
- Verifies async CloudKit operations
- **Target:** Main thread block time <100ms
- **Why:** Critical for UX during poor network

**testMemoryDoesNotLeakDuringRepeatedOperations:**
- Detects memory leaks from observers
- **Target:** Memory should stay flat over 100 iterations
- **Why:** Prevents crashes during long sessions

### Testing Philosophy
Tests prevent "gym lag" - performance degradation during real 60+ minute workouts with poor cellular. Always test on real devices with network throttling!

## Common Pitfalls & Gotchas

### 1. HealthKit Typo
```swift
@Published var isHealtKitEnabled: Bool  // TYPO: "Healt" instead of "Health"
```
This typo exists throughout the codebase. Don't "fix" it without migrating UserDefaults key!

### 2. Config Property Migration
```swift
// Old key: "splitLenght" (typo)
// New key: "splitLength"
// Migration code in Config.init() handles backward compatibility
```

### 3. Optional Arrays vs Empty Arrays
**Convention:** Use `nil` instead of `[]` for empty arrays in SwiftData models:
```swift
var exercises: [Exercise]?  // Set to nil when empty, not []
```
**Why:** Reduces storage overhead, cleaner optional handling

### 4. Date String Format
**Always use:** `"yyyy-MM-dd"` format for date strings
**Why:** Enables easy sorting, calendar lookups, and consistency

### 5. UUID Regeneration in Deep Copy
**Critical:** Always generate new UUIDs when copying models:
```swift
func copy() -> Exercise {
    return Exercise(id: UUID(), ...)  // NEW UUID!
}
```
**Why:** SwiftData uses `@Attribute(.unique)` on IDs. Duplicate UUIDs cause crashes!

### 6. GraphEntry Simplification
**Old approach (removed):**
```swift
@Published var graphUpdatedExerciseIDs: Set<UUID>  // Accumulated exercise IDs
```

**New approach:**
Recalculate graph data from database on-demand. Simpler, more reliable, fixes data inconsistencies.

### 7. Premium Flag Default
```swift
config.isPremium = true  // Default TRUE for testing
```
Currently all users get premium features. Subscription system planned.

### 8. CloudKit Container Name
```
Identifier: iCloud.com.gymly.app
Bundle ID:  com.icservis.GymlyFitness  // NOTE: Different prefix!
```

### 9. iOS Version Availability
```swift
```
App compiles for iOS 26+, but some features require iOS 26+.

### 10. ModelContainer Injection
```swift
// GymlyApp.swift
.modelContainer(for: [Split.self, Exercise.self, Day.self, DayStorage.self,
                      WeightPoint.self, UserProfile.self])
```
**All** models must be registered here, even if they're nested (like Set in Exercise).

## Code Style & Conventions

### Naming Conventions
```swift
// Models: PascalCase
class Exercise, struct Day

// Properties: camelCase
var exerciseOrder: Int

// Enums: PascalCase with lowercase cases
enum MuscleGroupEnum: String, CaseIterable {
    case chest, back, biceps
}

// Functions: camelCase, descriptive
func updateDayInSplit() -> Int
```

### Emoji Logging
Code uses emoji-prefixed debug logs for readability:
```swift
print("🔧 Setup/configuration")
print("✅ Success operations")
print("❌ Errors")
print("🧪 Test operations")
print("📊 Analytics")
print("🔥 CloudKit")
print("💪 Workout operations")
```

### SwiftUI View Structure
```swift
struct MyView: View {
    // MARK: - Environment & State
    @EnvironmentObject var config: Config
    @Query var exercises: [Exercise]
    @State private var isEditing = false

    // MARK: - Body
    var body: some View {
        // View code
    }

    // MARK: - Helper Functions
    private func helperFunction() {
        // Logic
    }
}
```

### Async/Await Everywhere
Modern concurrency throughout:
```swift
@MainActor
func updateProfile() async throws {
    let data = try await fetchData()
    await processData(data)
}
```

## Git Workflow & Commit Style

### Recent Commit History (for context)
```
42baec3   FEATURE: Modernize BMI Calculator UI with animations and improved UX
7eca99f FIX: Progress photo preview loading and workout summary sheet issues
fdc767f FIX: Eliminate gym lag caused by iCloud sync with poor connection
12e1ba0 FEATURE: Add 5 premium workout split templates with performance tests
92ddeac TEST: Add comprehensive automated testing for gym performance issues
```

### Commit Message Style
```
TYPE: Brief description of change

Examples:
FEATURE: Add workout summary AI generation
FIX: Resolve memory leak in exercise observer
TEST: Add performance tests for gym session flow
REFACTOR: Simplify GraphEntry calculation logic
```

### Branch Strategy
- `main` branch for production-ready code
- Feature branches for new features
- Thorough testing before merge to main

## Development Workflow Best Practices

### Before Making Changes
1. **Read WorkoutViewModel.swift first** - It's the brain of the app	
2. **Check Config.swift** - Understand app state
3. **Review SwiftData models** - Know the data structure
4. **Run existing tests** - Ensure baseline performance

### When Adding Features
1. **Update Config** if new app-wide state needed
2. **Add to WorkoutViewModel** if business logic
3. **Update models** if data structure changes (requires migration!)
4. **Add tests** especially for performance-critical code
5. **Test on real device** with network throttling (Settings > Developer > Network Link Conditioner)

### When Fixing Bugs
1. **Check recent commits** - Bug may have been introduced recently
2. **Look for performance regressions** - Run performance tests
3. **Test in "gym conditions"** - Poor cellular, extended use (60+ min)
4. **Verify CloudKit sync** doesn't cause issues

### Code Review Checklist
- [ ] SwiftData relationships correct? (cascade/nullify)
- [ ] New UUIDs generated in copy() methods?
- [ ] CloudKit operations async with timeout?
- [ ] HealthKit permissions requested if needed?
- [ ] Premium flag checked for premium features?
- [ ] Date strings use "yyyy-MM-dd" format?
- [ ] @MainActor used for UI updates?
- [ ] Performance impact considered?
- [ ] Tests added/updated?

## Common Tasks - Quick Reference

### Task: Add a New Muscle Group
1. Update `MuscleGroupEnum` in WorkoutViewModel.swift
2. Update `muscleGroupNames` array
3. Update radar chart in ContentViewGraph.swift
4. Update `graphDataValues` array size in Config.swift

### Task: Add a New Split Template
1. Create template in SplitTemplate.swift
2. Add to `allTemplates` array
3. Add UI card in SplitTemplatesView.swift
4. Test import/export functionality

### Task: Add a New Premium Feature
1. Gate UI with `if config.isPremium { ... }`
2. Add to PremiumSubscriptionView.swift feature list
3. Test with `config.isPremium = false`

### Task: Modify SwiftData Model
**WARNING: Requires migration!**
1. Create migration plan
2. Update model schema
3. Increment model version if needed
4. Test migration with existing user data
5. Provide fallback/default values

### Task: Fix Performance Issue
1. Run WorkoutPerformanceTests to measure baseline
2. Use Instruments (Time Profiler, Allocations)
3. Check for:
   - Unnecessary view recomputation
   - Memory leaks (observers not cleaned up)
   - Synchronous operations on main thread
   - CloudKit operations blocking UI
4. Add regression test

## File Import/Export System

### .gymlysplit File Format
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

### Import Flow
```
1. User receives .gymlysplit file (AirDrop, Files app)
2. iOS opens Gymly via URL scheme
3. GymlyApp.handleIncomingFile() called
4. WorkoutViewModel.importSplit() decodes JSON
5. New UUIDs generated for all entities (deep copy)
6. Inserted into SwiftData
7. NotificationCenter posts .importSplit notification
8. UI refreshes to show new split
```

### Export Flow
```
1. User taps "Export" on split
2. Split encoded to JSON (Codable)
3. Saved to temporary file with .gymlysplit extension
4. UIActivityViewController for sharing
```

## Debugging Tips

### Common Issues

**"Split not appearing after import"**
- Check NotificationCenter is posting `.importSplit`
- Verify ModelContext.save() called
- Check split's `isActive` flag if expecting it in active split

**"CloudKit not syncing"**
- Check `config.isCloudKitEnabled = true`
- Verify network quality (should be .excellent or .good)
- Check CloudKit console for errors
- Ensure not in workout mode (auto-sync disabled)

**"Exercise sets not saving"**
- Verify Exercise.sets is deep-copied, not referenced
- Check ModelContext.save() after modifications
- Look for SwiftData relationship issues

**"App lagging in gym"**
- Run WorkoutPerformanceTests
- Check CloudKit operation timeouts (should be 5s max)
- Verify network quality detection working
- Look for memory accumulation (Instruments > Allocations)

**"Streak calculation wrong"**
- Check `restDaysPerWeek` setting
- Verify date comparison logic
- Look for timezone issues (use Calendar correctly)

### Useful Print Statements
```swift
// Check CloudKit network quality
print("🔥 Network quality: \(cloudKitManager.networkQuality)")

// Verify split state
print("🔧 Active split: \(split.name), day: \(config.dayInSplit)/\(split.days?.count ?? 0)")

// Monitor performance
let start = CFAbsoluteTimeGetCurrent()
// ... operation ...
let duration = CFAbsoluteTimeGetCurrent() - start
print("⏱️ Operation took \(duration * 1000)ms")

// Check SwiftData context
print("📊 Context has changes: \(context.hasChanges)")
```

## Contact & Resources

### Developer
- **Name:** Sebastián Kučera
- **Email:** sebastian.kucera@icloud.com
- **Discord:** rektoooooo
- **Instagram:** @seb.kuc

### Documentation
- `README.md` - Project overview
- `ARCHITECTURE.md` - Architecture details
- `USER_GUIDE.md` - End-user documentation
- `TESTING_GUIDE.md` - Testing procedures

### TestFlight
Contact sebastian.kucera@icloud.com for beta access

## Summary: What Makes Gymly Unique

### Technical Excellence
- **Zero dependencies** - Pure native Apple stack
- **Performance-first** - Learned from real "gym lag" issues
- **Privacy-focused** - On-device AI, optional cloud sync
- **Production-ready** - ~17,600 lines, comprehensive testing

### Architectural Strengths
- Clean MVVM separation
- Reactive data flow with Combine
- Modern async/await concurrency
- Intelligent CloudKit sync with network awareness
- SwiftData for persistence

### Unique Features
- On-device AI workout summaries (iOS 26+)
- Network-aware CloudKit sync (prevents gym lag!)
- Progress photo tracking with pose guidance
- Streak system with rest day logic
- Pre-built premium split templates
- Muscle group radar chart analytics
- HealthKit bidirectional sync

### Key Learnings
1. **Performance in real conditions matters** - App worked perfectly at home (WiFi) but lagged in gym (poor cellular). Solution: Network quality monitoring + async operations with timeout.

2. **SwiftData relationships need care** - Nested models (Set inside Exercise) require special handling for deep copy and Codable conformance.

3. **User state is complex** - Config singleton with UserDefaults persistence works well for app-wide state.

4. **Testing prevents regressions** - Performance tests for extended sessions critical for catching "gym lag" type issues.

---

## For AI Assistants (Claude Code)

When working with this codebase:

1. **Start with WorkoutViewModel.swift** - It's the central business logic
2. **Respect the architecture** - Don't bypass Config or introduce singletons
3. **Performance is critical** - Always consider gym conditions (poor network, 60+ min sessions)
4. **Test thoroughly** - Run existing performance tests before/after changes
5. **SwiftData migrations are expensive** - Avoid model schema changes if possible
6. **CloudKit must be async** - Never block main thread with CloudKit operations
7. **Preserve conventions** - Date strings, UUID regeneration, emoji logging
8. **Premium features** - Check `config.isPremium` flag
9. **iOS version availability** - Some features require iOS 26+ (AI summaries)
10. **No external dependencies** - Keep it pure Apple frameworks

**Most Important:** This is a production app with real users. Changes must be tested thoroughly, especially for performance impact in poor network conditions.
