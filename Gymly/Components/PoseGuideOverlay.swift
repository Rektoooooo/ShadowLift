//
//  PoseGuideOverlay.swift
//  ShadowLift
//
//  Created by Claude Code on 27.10.2025.
//

import SwiftUI

struct PoseGuideOverlay: View {
    let photoType: PhotoType

    var body: some View {
        ZStack {
            // Grid overlay for alignment
            GeometryReader { geometry in
                Path { path in
                    // Vertical center line
                    let centerX = geometry.size.width / 2
                    path.move(to: CGPoint(x: centerX, y: 0))
                    path.addLine(to: CGPoint(x: centerX, y: geometry.size.height))

                    // Horizontal thirds
                    let thirdHeight = geometry.size.height / 3
                    for i in 1...2 {
                        let y = thirdHeight * CGFloat(i)
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
            }

            // Silhouette guide
            VStack(spacing: 0) {
                Spacer()

                switch photoType {
                case .front:
                    frontPoseGuide
                case .side:
                    sidePoseGuide
                case .back:
                    backPoseGuide
                case .custom:
                    frontPoseGuide
                }

                Spacer()
            }
        }
    }

    private var frontPoseGuide: some View {
        VStack(spacing: 4) {
            // Head
            Circle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: 60, height: 60)

            // Shoulders line
            Rectangle()
                .fill(Color.white)
                .frame(width: 120, height: 3)

            // Body
            RoundedRectangle(cornerRadius: 30)
                .stroke(Color.white, lineWidth: 2)
                .frame(width: 100, height: 180)

            // Legs guide
            VStack(spacing: 2) {
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2, height: 120)
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2, height: 120)
            }
            .frame(width: 60)
        }
        .frame(maxWidth: 200)
    }

    private var sidePoseGuide: some View {
        VStack(spacing: 4) {
            // Head (side profile)
            Circle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: 60, height: 60)
                .offset(x: 15)

            // Shoulder/neck
            Rectangle()
                .fill(Color.white)
                .frame(width: 3, height: 40)

            // Body (side view - narrower)
            RoundedRectangle(cornerRadius: 25)
                .stroke(Color.white, lineWidth: 2)
                .frame(width: 70, height: 180)

            // Legs
            Rectangle()
                .fill(Color.white)
                .frame(width: 3, height: 140)
        }
        .frame(maxWidth: 200)
    }

    private var backPoseGuide: some View {
        VStack(spacing: 4) {
            // Head (back)
            Circle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: 60, height: 60)

            // Shoulders
            Rectangle()
                .fill(Color.white)
                .frame(width: 120, height: 3)

            // Body
            RoundedRectangle(cornerRadius: 30)
                .stroke(Color.white, lineWidth: 2)
                .frame(width: 100, height: 180)

            // Legs
            VStack(spacing: 2) {
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2, height: 120)
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2, height: 120)
            }
            .frame(width: 60)
        }
        .frame(maxWidth: 200)
    }
}

#Preview {
    ZStack {
        Color.black
        PoseGuideOverlay(photoType: .front)
            .opacity(0.3)
    }
}
