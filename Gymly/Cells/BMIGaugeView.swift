//
//  BMIGaugeView.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 26.03.2025.
//


import SwiftUI

// MARK: - Animatable BMI Modifier
struct AnimatableBMIModifier: AnimatableModifier {
    var bmi: Double

    var animatableData: Double {
        get { bmi }
        set { bmi = newValue }
    }

    func body(content: Content) -> some View {
        content
    }
}

struct BMIGaugeView: View {
    let bmi: Double
    let bmiColor: Color
    let bmiText: String

    @State private var animatedBMI: Double = 0.0
    @State private var displayedBMI: Double = 0.0
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // MARK: Gauge Arc Background
            BMIGaugeShape(animatedBMI: animatedBMI, bmiColor: bmiColor)
                .frame(height: 230)
                .padding(.horizontal, 25)  // Increased to prevent glow clipping at extreme values
                .padding(.bottom, 20)

            // MARK: Animated Labels
            VStack(spacing: 6) {
                Text(bmiText)
                    .font(.title2)
                    .bold()
                    .foregroundStyle(bmiColor)
                    .scaleEffect(pulseScale)
                    .animation(.easeInOut(duration: 0.3), value: bmiText)

                Text("BMI")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .textCase(.uppercase)
                    .tracking(2)

                Text(String(format: "%.1f", displayedBMI))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(bmiColor)
                    .contentTransition(.numericText())
            }
            .offset(y: 50)
        }
        .onAppear {
            // Initial animation - smooth slide from 0 to actual BMI
            // Clamp BMI before animating so spring animation can ease into min/max
            let clampedBMI = min(max(bmi, 15.0), 32.5)
            withAnimation(.spring(response: 1.2, dampingFraction: 0.7)) {
                animatedBMI = clampedBMI
            }
            animateNumberCountUp(to: bmi)
            triggerPulse()
        }
        .onChange(of: bmi) { oldValue, newValue in
            // Smooth sliding animation when BMI changes - slower and more visible
            // Clamp BMI before animating so spring animation can ease smoothly into min/max
            let clampedBMI = min(max(newValue, 15.0), 32.5)
            withAnimation(.spring(response: 1.2, dampingFraction: 0.8)) {
                animatedBMI = clampedBMI
            }
            animateNumberCountUp(to: newValue)
            triggerPulse()
        }
    }

    private func animateNumberCountUp(to targetBMI: Double) {
        let startBMI = displayedBMI
        let duration: Double = 0.8
        let steps = 30
        let increment = (targetBMI - startBMI) / Double(steps)

        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + (duration / Double(steps)) * Double(i)) {
                displayedBMI = startBMI + increment * Double(i)
            }
        }
    }

    private func triggerPulse() {
        withAnimation(.easeInOut(duration: 0.2)) {
            pulseScale = 1.15
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                pulseScale = 1.0
            }
        }
    }
}

// MARK: - Animatable BMI Gauge Shape
struct BMIGaugeShape: View {
    var animatedBMI: Double
    let bmiColor: Color

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height - 30)
            let radius = size.width / 2.3
            let thickness: CGFloat = 16
            let startAngle: Angle = .degrees(180)

            // Define BMI ranges
            let ranges: [(range: ClosedRange<Double>, color: Color)] = [
                (15.0...18.5, .orange),
                (18.6...24.9, .green),
                (25.0...29.9, .orange),
                (30.0...32.5, .red)
            ]

            let arcPadding: Double = 0.017

            // Draw arcs
            for (range, color) in ranges {
                let totalSpan = 32.5 - 15.0
                let start = (range.lowerBound - 15.0) / totalSpan + arcPadding
                let end = (range.upperBound - 15.0) / totalSpan - arcPadding

                let arc = Path { path in
                    path.addArc(
                        center: center,
                        radius: radius,
                        startAngle: startAngle + .degrees(180 * start),
                        endAngle: startAngle + .degrees(180 * end),
                        clockwise: false
                    )
                }
                let strokeStyle = StrokeStyle(lineWidth: thickness, lineCap: .round)

                let isActiveRange = range.contains(animatedBMI)
                let opacity = isActiveRange ? 0.95 : 0.65
                context.stroke(arc, with: .color(color.opacity(opacity)), style: strokeStyle)
            }

            // Draw pointer circle
            // No need to clamp here - already clamped before animation
            let pointerPos = (animatedBMI - 15.0) / (32.5 - 15.0)
            let angle = startAngle + .degrees(180 * pointerPos)
            let pointerX = center.x + cos(angle.radians) * radius
            let pointerY = center.y + sin(angle.radians) * radius

            // Draw glow effect
            for i in stride(from: 3, through: 1, by: -1) {
                let glowRadius: CGFloat = 14 + CGFloat(i) * 3
                let glowCircle = Path(ellipseIn: CGRect(
                    x: pointerX - glowRadius,
                    y: pointerY - glowRadius,
                    width: glowRadius * 2,
                    height: glowRadius * 2
                ))
                context.fill(glowCircle, with: .color(bmiColor.opacity(0.15 / Double(i))))
            }

            // Pointer circle
            let pointer = Path(ellipseIn: CGRect(x: pointerX - 14, y: pointerY - 14, width: 28, height: 28))
            context.fill(pointer, with: .color(bmiColor))
        }
    }
}

// MARK: - Make BMIGaugeShape Animatable
extension BMIGaugeShape: Animatable {
    var animatableData: Double {
        get { animatedBMI }
        set { animatedBMI = newValue }
    }
}

#Preview {
    BMIGaugeView(bmi: 5.0, bmiColor: .green, bmiText: "Normal")
}
