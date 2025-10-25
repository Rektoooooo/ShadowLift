# Gymly Testing Guide

## Overview

This guide explains how to run automated tests to catch performance issues, especially **gym lag** that happens during extended use.

---

## Why You Need These Tests

### The Problem
- **At home:** App is smooth ✅
- **In gym:** App lags after 30-60 minutes ❌

### The Cause
1. **Network delays** - CloudKit sync blocks UI with slow cellular
2. **Memory accumulation** - Observers and cached data pile up
3. **Repeated operations** - 50+ set edits stress the system

### The Solution
Automated tests that:
- Simulate 60-minute gym sessions
- Measure performance under load
- Catch regressions before they ship

---

## Test Types

We have **3 types of tests**:

### 1. Performance Tests (`GymlyTests/`)
**What:** Measures how fast operations are
**When to run:** Before every commit
**What it catches:** Slow functions, memory leaks

**Files:**
- `WorkoutPerformanceTests.swift` - Workout operations
- `NetworkPerformanceTests.swift` - CloudKit sync issues

### 2. UI Tests (`GymlyUITests/`)
**What:** Automates user actions (tap, swipe, navigate)
**When to run:** Before releases
**What it catches:** UI lag, navigation slowness

**Files:**
- `GymWorkflowTests.swift` - Simulates gym session

### 3. Stress Tests
**What:** Runs for 60+ minutes like real gym use
**When to run:** Weekly
**What it catches:** Memory leaks, accumulated lag

---

## How to Run Tests

### Method 1: Run All Tests (Recommended)

```bash
# In Terminal, navigate to project directory
cd /Users/sebastiankucera/Gymly

# Run all tests
xcodebuild test -scheme Gymly -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

### Method 2: Run from Xcode (Easier)

1. **Open Xcode**
2. **Press `Cmd + U`** (Run all tests)
3. **Or:** `Cmd + 6` → Click ▶️ next to specific test

### Method 3: Run Specific Test

**In Xcode:**
1. Open test file (e.g., `WorkoutPerformanceTests.swift`)
2. Click the diamond ◊ next to test function
3. Watch it run!

---

## Understanding Test Results

### ✅ PASS - Good Performance
```
✅ testRefreshViewPerformance (0.012s)
   Average: 12ms
   Max: 15ms
```
**Meaning:** Operation is fast enough for 60fps

### ⚠️ SLOW - Warning
```
⚠️ testSetEditSavePerformance (0.025s)
   Average: 25ms
   Max: 45ms
```
**Meaning:** Noticeable lag, optimize this!

### ❌ FAIL - Critical Issue
```
❌ testGymSessionStressTest
   Average: 150ms
   Operations >1s: 25
```
**Meaning:** Severe lag, MUST fix before release!

---

## Key Tests Explained

### 1. `testExtendedGymSessionPerformance` ⭐ MOST IMPORTANT
**What it does:**
- Simulates 50 set edits in a row
- Measures time for each operation
- Detects if operations slow down over time

**What to look for:**
- Average time should be <20ms
- No operations should take >100ms
- Later iterations shouldn't be slower than early ones

**Example output:**
```
📊 GYM SESSION TEST RESULTS:
   Total sets edited: 50
   Average time per set: 0.018s ✅
   Slowest operation: 0.045s ⚠️
   Operations >1s: 0 ✅
```

### 2. `testGymSessionStressTest` (UI Test)
**What it does:**
- Actually clicks through the app 50 times
- Measures real UI responsiveness
- Catches lag you'd experience in gym

**What to look for:**
- Average <0.5s per operation
- No more than 5 operations taking >1s
- App should remain smooth

### 3. `testMemoryDoesNotLeakDuringRepeatedOperations`
**What it does:**
- Runs same operation 100 times
- Checks if memory grows continuously

**What to look for:**
- Memory should stay flat
- Small fluctuations are OK
- Continuous growth = memory leak ❌

### 4. `testCloudKitSyncDoesNotBlockMainThread`
**What it does:**
- Verifies CloudKit sync is async
- Checks UI stays responsive during sync

**What to look for:**
- Main thread block time <100ms
- UI operations complete immediately
- Sync happens in background

---

## Running Tests with Network Conditions

### Simulate Gym Network (Slow Cellular)

**Option 1: Network Link Conditioner (Mac)**
1. Download from Apple: https://developer.apple.com/download/all/
2. Search "Additional Tools for Xcode"
3. Install Network Link Conditioner
4. Open System Preferences → Network Link Conditioner
5. Select "3G" or "Very Bad Network"
6. Run tests

**Option 2: Xcode Simulator Settings**
1. Run app in Simulator
2. Debug → Simulate Location → Custom...
3. Or use `xcrun simctl` command:
   ```bash
   xcrun simctl status_bar "iPhone 16 Pro" override \
     --cellularMode searching
   ```

**Option 3: Real Device with Poor Network**
1. Connect iPhone
2. Turn off WiFi
3. Go to area with weak signal (or use Settings → Developer → Network Link Conditioner)
4. Run tests on device

---

## Continuous Monitoring

### Add Tests to CI/CD (Future)

**GitHub Actions example:**
```yaml
name: Performance Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run Performance Tests
        run: xcodebuild test -scheme Gymly -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

---

## Interpreting Results for Gym Lag

### If Tests PASS but Gym Still Lags:

**Possible causes:**
1. **Network delays** - CloudKit sync is slow
   - Fix: Make CloudKit sync fully async
   - Add timeout handling

2. **Device-specific** - Older iPhone in gym?
   - Test on older devices
   - Add performance logging in production

3. **Extended time** - Tests don't run for 60+ minutes
   - Run manual stress test
   - Use Instruments for long session

4. **Real-world conditions** - Tests use mock data
   - Test with real database
   - Add production logging

### If Tests FAIL:

**Immediate actions:**
1. **Identify slowest operation** - Check test output
2. **Profile with Instruments** - Time Profiler
3. **Fix the bottleneck** - Optimize that function
4. **Re-run tests** - Verify fix works
5. **Commit** - Don't ship slow code!

---

## Production Logging (Detect Issues in Gym)

Since tests can't perfectly replicate gym conditions, add runtime monitoring:

### Add to TodayWorkoutView:
```swift
// Log performance in production
private func logPerformance(_ operation: String, time: TimeInterval) {
    #if DEBUG
    if time > 0.1 {  // 100ms threshold
        debugPrint("⚠️ PERF: \(operation) took \(time * 1000)ms")
    }
    #endif
}

// Use it:
let start = CFAbsoluteTimeGetCurrent()
await refreshView()
logPerformance("refreshView", CFAbsoluteTimeGetCurrent() - start)
```

---

## Quick Start Checklist

- [ ] Run `Cmd + U` to run all tests
- [ ] Check `testExtendedGymSessionPerformance` results
- [ ] Run UI tests with slow network simulation
- [ ] Profile with Instruments if tests show issues
- [ ] Add production logging for gym sessions
- [ ] Test on real device in gym before release

---

## When to Run Which Tests

**Before Every Commit:**
- Performance tests (fast, <1 minute)

**Before Every PR:**
- All unit + performance tests

**Before Release:**
- All tests including UI tests
- Manual gym session test
- Instruments profiling

**Weekly:**
- Extended stress tests
- Memory leak detection
- Real device testing

---

## Common Issues and Fixes

### Issue: Tests timeout
**Fix:** Increase timeout in test:
```swift
XCTAssertTrue(element.waitForExistence(timeout: 10))
```

### Issue: UI tests can't find elements
**Fix:** Add accessibility identifiers:
```swift
Button("Done")
    .accessibilityIdentifier("doneButton")
```

### Issue: Tests pass but gym still lags
**Fix:**
1. Run tests on real device
2. Enable slow network simulation
3. Use Instruments for 60-minute session
4. Add production logging

---

## Next Steps

1. ✅ Tests are created
2. **Run them:** `Cmd + U`
3. **Fix failing tests**
4. **Add to CI/CD** (optional)
5. **Test in gym** with production logging

---

## Questions?

Check these resources:
- [XCTest Documentation](https://developer.apple.com/documentation/xctest)
- [Performance Testing Guide](https://developer.apple.com/documentation/xctest/performance_tests)
- [UI Testing Guide](https://developer.apple.com/library/archive/documentation/DeveloperTools/Conceptual/testing_with_xcode/chapters/09-ui_testing.html)

**Need help?** Check the test output logs - they explain what failed and why!
