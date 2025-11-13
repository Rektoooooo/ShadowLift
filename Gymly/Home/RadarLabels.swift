//
//  RadarLabels.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 24.09.2024.
//

import SwiftUI

struct RadarLabels: View {
    let labels = ["Chest","Back","Biceps","Triceps","Shoulders","Quads","Hamstrings","Calves","Glutes","Abs"]

    var body: some View {
        GeometryReader { geo in
            let positions = radarLabelPositions(size: geo.size, count: labels.count)

            ZStack {
                ForEach(0..<labels.count, id: \.self) { i in
                    Text(labels[i])
                        .font(.caption)
                        .position(x: positions[i].x, y: positions[i].y)
                }
            }
        }
        .frame(width: 300, height: 300)
    }
}

func radarLabelPositions(size: CGSize, count: Int, radiusOffset: CGFloat = 2) -> [CGPoint] {
    let center = CGPoint(x: size.width / 2, y: size.height / 2)
    let radius = min(size.width, size.height) / 2 + radiusOffset
    var points: [CGPoint] = []

    for i in 0..<count {
        let angle = (Double(i) / Double(count)) * 2 * .pi
        let x = center.x + CGFloat(cos(angle)) * radius
        let y = center.y + CGFloat(sin(angle)) * radius
        points.append(CGPoint(x: x, y: y))
    }

    return points
}

#Preview {
    RadarLabels()
}


struct RadarBackground: Shape {
    var levels: Int

    func path(in rect: CGRect) -> Path {
        let sides = 10
        let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
        let radius = min(rect.width, rect.height) / 2

        var path = Path()
        
        for level in 1...levels {
            let currentRadius = radius * CGFloat(level) / CGFloat(levels)
            
            for i in 0..<sides {
                let angle = (Double(i) / Double(sides)) * 2 * .pi
                let x = center.x + CGFloat(cos(angle)) * currentRadius
                let y = center.y + CGFloat(sin(angle)) * currentRadius
                
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            
            path.closeSubpath()
        }
        
        return path
    }
}

struct RadarChart: Shape {
    var values: [Double]
    var maxValue: Double

    func path(in rect: CGRect) -> Path {
        let sides = values.count
        let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
        let radius = min(rect.width, rect.height) / 2
        
        var path = Path()
        
        for i in 0..<sides {
            let angle = (Double(i) / Double(sides)) * 2 * .pi
            let value = values[i] / maxValue
            let x = center.x + CGFloat(cos(angle)) * radius * CGFloat(value)
            let y = center.y + CGFloat(sin(angle)) * radius * CGFloat(value)
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        path.closeSubpath()
        return path
    }
}
