//
//  ImageExtension.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 29.01.2025.
//

import Foundation
import SwiftUI

extension Image {
    func asUIImage() -> UIImage? {
        let controller = UIHostingController(rootView: self)
        let view = controller.view

        let size = CGSize(width: 300, height: 300) // Set the size you need
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            view?.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }
    }
}
