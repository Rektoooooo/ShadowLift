//
//  SettingUserInfoCell.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 25.03.2025.
//

import SwiftUI
import HealthKit


struct SettingUserInfoCell: View {
    let healthStore = HKHealthStore()
    @EnvironmentObject var config: Config
    @EnvironmentObject var userProfileManager: UserProfileManager

    @State var value: String = "20"
    @State var metric: String = "Kg"
    @State var headerColor: Color = .green
    @State var additionalInfo: String = "Normal Weight"
    @State var icon: String = "figure.run"
    @State var compareWeight: Double? = nil  // Weight to compare against
    @State var compareText: String = ""  // Text to display (e.g., "last week" or "last weigh-in")
    @State private var hasLoadedWeightData = false  // Prevent multiple loads

    var body: some View {
        VStack {
            GeometryReader { geo in
                ZStack {
                    Rectangle()
                        .fill(headerColor)
                        .frame(height: geo.size.height * 0.4) // 30% of HStack height
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.2) // center it vertically
                    Text(additionalInfo)
                         .foregroundColor(.black)
                         .bold()
                         .position(x: geo.size.width / 2, y: geo.size.height * 0.2)
                    HStack {
                        VStack {
                            HStack {
                                Text("\(value) \(metric)")
                                    .bold()
                                Image(systemName: icon)
                            }
                            // Show weight change
                            if (metric == "Kg" || metric == "Lbs"), let compareWt = compareWeight, compareWt > 0, !compareText.isEmpty {
                                let conversionFactor = userProfileManager.currentProfile?.weightUnit ?? "Kg" == "Kg" ? 1.0 : 2.20462
                                let currentWeight = Double(value) ?? 0.0
                                let compareConverted = compareWt * conversionFactor
                                let change = currentWeight - compareConverted

                                HStack(spacing: 3) {
                                    if change > 0.1 {
                                       Image(systemName: "arrow.up")
                                    } else if change < -0.1 {
                                        Image(systemName: "arrow.down")
                                    } else {
                                        Image(systemName: "minus")
                                    }
                                    Text("\(String(format: "%.1f", abs(change))) \(compareText)")
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 65)

                }
                .background(Color.black.opacity(0.2))
            }
        }
        .onAppear() {
            // Only fetch last week's weight if this is a weight cell and we haven't loaded yet
            guard (metric == "Kg" || metric == "Lbs") && !hasLoadedWeightData else { return }
            hasLoadedWeightData = true

            getWeightComparison()
        }
        .frame(width: 160, height: 120)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    func getWeightComparison() {
        guard let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass) else {
            return
        }

        let now = Date()
        let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -10, to: now)!
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        // Get recent weight samples (last 10 days)
        let predicate = HKQuery.predicateForSamples(withStart: tenDaysAgo, end: now)

        let query = HKSampleQuery(sampleType: weightType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { (_, samples, error) in

            // If we have recent samples, try to find weight from last week
            if error == nil, let samples = samples as? [HKQuantitySample], !samples.isEmpty {
                // Try to find weight from ~7 days ago (with 3 day tolerance)
                let targetDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
                let closestTo7Days = samples.min(by: { abs($0.startDate.timeIntervalSince(targetDate)) < abs($1.startDate.timeIntervalSince(targetDate)) })

                if let sample = closestTo7Days {
                    let daysDiff = abs(Calendar.current.dateComponents([.day], from: sample.startDate, to: targetDate).day ?? 0)

                    // If within 3 days of 7 days ago, use "last week"
                    if daysDiff <= 3 {
                        let weight = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
                        DispatchQueue.main.async {
                            self.compareWeight = weight
                            self.compareText = "vs last week"
                        }
                        return
                    }
                }
            }

            // No weight from last week (or no recent data), get last 2 weights
            self.getAllRecentWeights { allWeights in
                print("📊 SettingUserInfoCell: Found \(allWeights.count) total weight entries in HealthKit")

                guard allWeights.count >= 2 else {
                    print("⚠️ SettingUserInfoCell: Not enough weight data (need at least 2 entries)")
                    return
                }

                // Compare last weight to 2nd last weight
                let lastWeight = allWeights[0].quantity.doubleValue(for: .gramUnit(with: .kilo))
                let secondLastWeight = allWeights[1].quantity.doubleValue(for: .gramUnit(with: .kilo))

                print("📊 SettingUserInfoCell: Comparing last (\(lastWeight)kg) to 2nd last (\(secondLastWeight)kg)")

                DispatchQueue.main.async {
                    self.compareWeight = secondLastWeight
                    self.compareText = "vs last time"
                    print("✅ SettingUserInfoCell: Set compareWeight=\(secondLastWeight), compareText='vs last time'")
                }
            }
        }
        healthStore.execute(query)
    }

    func getAllRecentWeights(completion: @escaping ([HKQuantitySample]) -> Void) {
        guard let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass) else {
            completion([])
            return
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        // Get all weight samples
        let query = HKSampleQuery(sampleType: weightType, predicate: nil, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { (_, samples, error) in
            guard error == nil, let samples = samples as? [HKQuantitySample] else {
                completion([])
                return
            }
            completion(samples)
        }
        healthStore.execute(query)
    }
}

#Preview {
    SettingUserInfoCell()
}
