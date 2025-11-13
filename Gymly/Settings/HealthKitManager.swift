//
//  HealthKitManager.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 28.01.2025.
//


import HealthKit
import SwiftData
import CloudKit

class HealthKitManager: ObservableObject {
    let healthStore = HKHealthStore()

    /// Check if HealthKit is available
    func isHealthKitAvailable() -> Bool {
        return HKHealthStore.isHealthDataAvailable()
    }

    /// Request authorization for Height, Weight, and Date of Birth (age)
    func requestAuthorization() {
        guard isHealthKitAvailable() else {
            print("HealthKit is not available on this device.")
            return
        }

        let heightType = HKObjectType.quantityType(forIdentifier: .height)!
        let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass)!
        let dobType = HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!

        let readTypes: Set<HKObjectType> = [heightType, weightType, dobType]
        let writeTypes: Set<HKSampleType> = [heightType, weightType]

        healthStore.requestAuthorization(toShare: writeTypes, read: readTypes) { success, error in
            if success {
                print("HealthKit authorization granted!")
            } else {
                print("HealthKit authorization denied: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    /// Fetch users height
    func fetchHeight(completion: @escaping (Double?) -> Void) {
        let heightType = HKQuantityType.quantityType(forIdentifier: .height)!
        let query = HKSampleQuery(sampleType: heightType, predicate: nil, limit: 1, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { _, results, _ in
            if let sample = results?.first as? HKQuantitySample {
                let heightInMeters = sample.quantity.doubleValue(for: HKUnit.meter())
                completion(heightInMeters)
            } else {
                completion(nil)
            }
        }
        healthStore.execute(query)
    }

    func saveHeight(_ heightMeters: Double, date: Date = Date()) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .height) else { return }
        let quantity = HKQuantity(unit: .meter(), doubleValue: heightMeters)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: date, end: date)

        healthStore.save(sample) { success, error in
            if success {
                print("✅ Height saved to HealthKit")
            } else {
                print("❌ Error saving height: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }

    /// Fetch users weight
    func fetchWeight(completion: @escaping (Double?) -> Void) {
        let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass)!
        let query = HKSampleQuery(sampleType: weightType, predicate: nil, limit: 1, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { _, results, _ in
            if let sample = results?.first as? HKQuantitySample {
                let weightInKg = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                completion(weightInKg)
            } else {
                completion(nil)
            }
        }
        healthStore.execute(query)
    }
    
    func saveWeight(_ weightKg: Double, date: Date = Date()) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            print("❌ Unable to create bodyMass quantity type")
            return
        }

        // Check authorization status before saving
        let authStatus = healthStore.authorizationStatus(for: type)
        switch authStatus {
        case .notDetermined:
            print("⚠️ HealthKit authorization not determined. Requesting authorization...")
            requestAuthorization()
            return
        case .sharingDenied:
            print("❌ HealthKit sharing denied. Please enable in Settings > Privacy & Security > Health > Gymly")
            return
        case .sharingAuthorized:
            print("✅ HealthKit sharing authorized, proceeding to save weight")
        @unknown default:
            print("❌ Unknown HealthKit authorization status")
            return
        }

        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: weightKg)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: date, end: date)

        healthStore.save(sample) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ Weight saved to HealthKit: \(weightKg) kg")
                } else {
                    print("❌ Error saving weight: \(error?.localizedDescription ?? "Unknown error")")
                    if let error = error as? HKError {
                        switch error.code {
                        case .errorAuthorizationDenied:
                            print("❌ Authorization denied - check HealthKit permissions")
                        case .errorAuthorizationNotDetermined:
                            print("❌ Authorization not determined - requesting authorization")
                        default:
                            print("❌ HealthKit error code: \(error.code)")
                        }
                    }
                }
            }
        }
    }
    
    
    /// Fetch users age
    func fetchAge(completion: @escaping (Int?) -> Void) {
        do {
            let birthDate = try healthStore.dateOfBirthComponents()
            let calendar = Calendar.current
            let age = calendar.dateComponents([.year], from: birthDate.date!, to: Date()).year
            completion(age)
        } catch {
            print("Error retrieving age: \(error.localizedDescription)")
            completion(nil)
        }
    }
    
    func fetchDailyLatestWeightLastMonth(completion: @escaping ([(date: Date, weight: Double)]) -> Void) {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            print("Unable to get weight type")
            completion([])
            return
        }

        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate)!

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(sampleType: weightType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { (_, results, error) in
            guard let samples = results as? [HKQuantitySample] else {
                completion([])
                return
            }

            let calendar = Calendar.current
            var dailyLatest: [Date: HKQuantitySample] = [:]

            for sample in samples {
                let day = calendar.startOfDay(for: sample.startDate)
                if let existing = dailyLatest[day] {
                    // Replace only if sample is newer
                    if sample.startDate > existing.startDate {
                        dailyLatest[day] = sample
                    }
                } else {
                    dailyLatest[day] = sample
                }
            }

            // Transform to (Date, Weight)
            let dailyWeights = dailyLatest.map { (day, sample) -> (date: Date, weight: Double) in
                let weightInKg = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                return (date: day, weight: weightInKg)
            }.sorted { $0.date < $1.date }

            DispatchQueue.main.async {
                completion(dailyWeights)
            }
        }

        HKHealthStore().execute(query)
    }
    
    @MainActor
    func updateFromWeightChart(context: ModelContext) {
        Task { @MainActor in
            do {
                // Clear existing points
                let fetchDescriptor = FetchDescriptor<WeightPoint>()
                let existing = try context.fetch(fetchDescriptor)
                for point in existing {
                    context.delete(point)
                }

                // Fetch from HealthKit
                fetchDailyLatestWeightLastMonth { result in
                    Task { @MainActor in
                        var newWeightPoints: [WeightPoint] = []
                        for item in result {
                            let weightPoint = WeightPoint(date: item.date, weight: item.weight)
                            context.insert(weightPoint)
                            newWeightPoints.append(weightPoint)
                            debugPrint("Inserted into context: \(weightPoint)")
                        }

                        do {
                            try context.save()
                            debugPrint("Saved context after inserting weight points")

                            // Sync to CloudKit if enabled
                            if UserDefaults.standard.bool(forKey: "isCloudKitEnabled") {
                                for weightPoint in newWeightPoints {
                                    try? await CloudKitManager.shared.saveWeightPoint(weightPoint)
                                }
                            }
                        } catch {
                            print("❌ Failed to save new weight data: \(error)")
                        }
                    }
                }

            } catch {
                print("❌ Failed to clear old weight data: \(error)")
            }
        }
    }
}
