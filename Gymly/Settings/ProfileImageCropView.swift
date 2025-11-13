//
//  ProfileImageCropView.swift
//  ShadowLift
//
//  Created by Claude Code on 30.01.2025.
//

import SwiftUI

struct ProfileImageCropView: View {
    let image: UIImage
    let onComplete: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var currentScale: CGFloat = 1.0
    @State private var finalScale: CGFloat = 1.0
    @State private var currentOffset: CGSize = .zero
    @State private var finalOffset: CGSize = .zero

    // Circle size for crop area
    private let circleSize: CGFloat = 280

    init(image: UIImage, onComplete: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
        self.image = image
        self.onComplete = onComplete
        self.onCancel = onCancel
        print("🖼️ CROP VIEW INIT: Image size: \(image.size)")
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Layer 1: Black background
                Color.black
                    .ignoresSafeArea(.all, edges: .all)

                // Layer 2: The zoomable/draggable image (behind overlay)
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(finalScale * currentScale)
                    .offset(x: finalOffset.width + currentOffset.width,
                            y: finalOffset.height + currentOffset.height)
                    .gesture(
                        SimultaneousGesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    currentScale = value
                                }
                                .onEnded { value in
                                    finalScale *= currentScale
                                    // Limit zoom range 1x - 3x
                                    finalScale = min(max(finalScale, 1.0), 3.0)
                                    currentScale = 1.0
                                },
                            DragGesture()
                                .onChanged { value in
                                    currentOffset = value.translation
                                }
                                .onEnded { value in
                                    // Calculate new offset with bounds
                                    let newOffsetWidth = finalOffset.width + currentOffset.width
                                    let newOffsetHeight = finalOffset.height + currentOffset.height

                                    // Calculate maximum allowed offset based on image size and scale
                                    let screenSize = geometry.size
                                    let imageAspect = image.size.width / image.size.height
                                    let screenAspect = screenSize.width / screenSize.height

                                    let displayWidth: CGFloat
                                    let displayHeight: CGFloat

                                    if imageAspect > screenAspect {
                                        displayWidth = screenSize.width
                                        displayHeight = screenSize.width / imageAspect
                                    } else {
                                        displayHeight = screenSize.height
                                        displayWidth = screenSize.height * imageAspect
                                    }

                                    // Current scale
                                    let scale = finalScale * currentScale

                                    // Scaled dimensions
                                    let scaledWidth = displayWidth * scale
                                    let scaledHeight = displayHeight * scale

                                    // Maximum offset: half of scaled dimension minus half of circle
                                    let maxOffsetX = max(0, (scaledWidth / 2) - (circleSize / 2))
                                    let maxOffsetY = max(0, (scaledHeight / 2) - (circleSize / 2))

                                    // Constrain offset
                                    finalOffset.width = min(max(newOffsetWidth, -maxOffsetX), maxOffsetX)
                                    finalOffset.height = min(max(newOffsetHeight, -maxOffsetY), maxOffsetY)
                                    currentOffset = .zero
                                }
                        )
                    )

                // Layer 3: Fixed circular crop overlay (doesn't move/scale with image)
                CircularCropOverlay(circleSize: circleSize)
                    .allowsHitTesting(false)

                // Layer 4: UI elements on top (buttons and text)
                VStack {
                    // Top navigation bar
                    HStack {
                        Button("Cancel") {
                            onCancel()
                        }
                        .foregroundStyle(.white)
                        .font(.body)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .cornerRadius(35)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 5)

                        Spacer()

                        Button("Done") {
                            saveCroppedImage(screenSize: geometry.size)
                        }
                        .foregroundStyle(.white)
                        .font(.body.bold())
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .cornerRadius(35)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 5)

                    }
                    .ignoresSafeArea()

                    Spacer()

                    // Bottom instruction text
                    Text("Pinch to zoom, drag to move")
                        .foregroundStyle(.white.opacity(0.6))
                        .font(.subheadline)
                        .padding(.bottom, 40)
                        .background(Color.clear)
                }
            }
            .onAppear {
                print("🖼️ CROP VIEW: Image size: \(image.size)")
                print("🖼️ CROP VIEW: View appeared")
            }
        }
    }

    private func saveCroppedImage(screenSize: CGSize) {
        // Calculate the crop area in image coordinates
        let scale = finalScale * currentScale
        let offset = CGSize(
            width: finalOffset.width + currentOffset.width,
            height: finalOffset.height + currentOffset.height
        )

        print("🔍 CROP: Final scale: \(scale)")
        print("🔍 CROP: Final offset: \(offset)")
        print("🔍 CROP: Circle size: \(circleSize)")
        print("🔍 CROP: Image size: \(image.size)")

        // Crop and generate circular image
        if let croppedImage = cropImageToCircle(
            image: image,
            scale: scale,
            offset: offset,
            circleSize: circleSize,
            screenSize: screenSize
        ) {
            print("✅ CROP: Generated cropped image: \(croppedImage.size)")
            onComplete(croppedImage)
        } else {
            print("❌ CROP: Failed to generate cropped image")
        }
    }

    private func cropImageToCircle(image: UIImage, scale: CGFloat, offset: CGSize, circleSize: CGFloat, screenSize: CGSize) -> UIImage? {
        let imageSize = image.size

        // Calculate how the image is displayed with scaledToFit
        let imageAspect = imageSize.width / imageSize.height
        let screenAspect = screenSize.width / screenSize.height

        let displayWidth: CGFloat
        let displayHeight: CGFloat

        if imageAspect > screenAspect {
            // Image is wider - fits to width
            displayWidth = screenSize.width
            displayHeight = screenSize.width / imageAspect
        } else {
            // Image is taller - fits to height
            displayHeight = screenSize.height
            displayWidth = screenSize.height * imageAspect
        }

        print("🔍 Display size: \(displayWidth) x \(displayHeight)")
        print("🔍 Screen size: \(screenSize.width) x \(screenSize.height)")

        // Where is the displayed image positioned (centered on screen, BEFORE any transforms)
        let baseDisplayX = (screenSize.width - displayWidth) / 2
        let baseDisplayY = (screenSize.height - displayHeight) / 2

        print("🔍 Base display position: (\(baseDisplayX), \(baseDisplayY))")

        // Circle is always at screen center
        let circleCenterX = screenSize.width / 2
        let circleCenterY = screenSize.height / 2

        // The image is scaled around its center, then offset
        // Image center in screen coordinates after transforms:
        let imageCenterX = screenSize.width / 2 + offset.width
        let imageCenterY = screenSize.height / 2 + offset.height

        print("🔍 Image center after offset: (\(imageCenterX), \(imageCenterY))")
        print("🔍 Circle center: (\(circleCenterX), \(circleCenterY))")

        // Distance from image center to circle center (in screen coordinates)
        let deltaX = circleCenterX - imageCenterX
        let deltaY = circleCenterY - imageCenterY

        print("🔍 Delta from image center to circle center: (\(deltaX), \(deltaY))")

        // Convert to display coordinates (accounting for scale)
        let displayDeltaX = deltaX / scale
        let displayDeltaY = deltaY / scale

        print("🔍 Display delta (unscaled): (\(displayDeltaX), \(displayDeltaY))")

        // Image center in display coordinates is at (displayWidth/2, displayHeight/2)
        // Circle center in display coordinates relative to image:
        let circleInImageX = (displayWidth / 2) + displayDeltaX
        let circleInImageY = (displayHeight / 2) + displayDeltaY

        print("🔍 Circle position in display image: (\(circleInImageX), \(circleInImageY))")

        // Convert to actual image pixel coordinates
        let imageScale = imageSize.width / displayWidth
        let cropCenterX = circleInImageX * imageScale
        let cropCenterY = circleInImageY * imageScale

        print("🔍 Crop center in image pixels: (\(cropCenterX), \(cropCenterY))")
        print("🔍 Image scale factor: \(imageScale)")

        // Crop radius in image pixels
        let cropRadius = (circleSize / 2) / scale * imageScale

        print("🔍 Crop radius in image pixels: \(cropRadius)")

        // Create circular crop at the calculated position
        let cropDiameter = cropRadius * 2
        let outputSize = CGSize(width: cropDiameter, height: cropDiameter)

        let renderer = UIGraphicsImageRenderer(size: outputSize)
        let croppedImage = renderer.image { _ in
            // Create circular clipping path
            let circlePath = UIBezierPath(ovalIn: CGRect(origin: .zero, size: outputSize))
            circlePath.addClip()

            // Draw the image so that cropCenter is at the center of our output
            let drawRect = CGRect(
                x: cropRadius - cropCenterX,
                y: cropRadius - cropCenterY,
                width: imageSize.width,
                height: imageSize.height
            )

            image.draw(in: drawRect)
        }

        return croppedImage
    }
}

// Circular overlay with transparent center
struct CircularCropOverlay: View {
    let circleSize: CGFloat

    var body: some View {
        ZStack {
            // Dark overlay covering entire screen
            Color.black.opacity(0.7)

            // Transparent circle in center
            Circle()
                .frame(width: circleSize, height: circleSize)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
        .overlay {
            // White circle border for clarity
            Circle()
                .stroke(Color.white.opacity(0.8), lineWidth: 2)
                .frame(width: circleSize, height: circleSize)
        }
    }
}
