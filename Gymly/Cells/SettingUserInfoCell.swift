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
    @State var weightLastWeek: Double = 0.0
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
                            if metric == "Kg" || metric == "Lbs" {
                                HStack(spacing: 4) {
                                    Text("\(String(format: "%.1f", (Double(value) ?? 0.0) - weightLastWeek * (userProfileManager.currentProfile?.weightUnit ?? "Kg" == "Kg" ? 1.0 : 2.20462)))\(userProfileManager.currentProfile?.weightUnit ?? "Kg")")
                                    if Double(value) ?? 0.0 > weightLastWeek * (userProfileManager.currentProfile?.weightUnit ?? "Kg" == "Kg" ? 1.0 : 2.20462) {
                                       Image(systemName: "arrow.up")
                                    } else if Double(value) ?? 0.0 < weightLastWeek * (userProfileManager.currentProfile?.weightUnit ?? "Kg" == "Kg" ? 1.0 : 2.20462) {
                                        Image(systemName: "arrow.down")
                                    } else {
                                        Image(systemName: "arrow.up.arrow.down")
                                    }
                                    Text("From last week")
                                }
                                .font(.caption)
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

            getLastWeekWeight { weight in
                if let weight = weight {
                    DispatchQueue.main.async {
                        self.weightLastWeek = weight
                    }
                }
            }
        }
        .frame(width: 160, height: 120)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    func getLastWeekWeight(completion: @escaping (Double?) -> Void) {
        guard let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass) else {
            completion(nil)
            return
        }
        
        let now = Date()
        let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -10, to: now)!
        let predicate = HKQuery.predicateForSamples(withStart: tenDaysAgo, end: now)

        let query = HKSampleQuery(sampleType: weightType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { (_, samples, error) in
            guard
                error == nil,
                let samples = samples as? [HKQuantitySample],
                !samples.isEmpty
            else {
                completion(nil)
                return
            }

            let targetDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
            let closestSample = samples.min(by: { abs($0.startDate.timeIntervalSince(targetDate)) < abs($1.startDate.timeIntervalSince(targetDate)) })

            if let closestSample = closestSample {
                let weight = closestSample.quantity.doubleValue(for: .gramUnit(with: .kilo))
                completion(weight)
            } else {
                completion(nil)
            }
        }
        healthStore.execute(query)
    }
}

#Preview {
    SettingUserInfoCell()
}
