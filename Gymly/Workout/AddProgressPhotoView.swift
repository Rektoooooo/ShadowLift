//
//  AddProgressPhotoView.swift
//  ShadowLift
//
//  Created by Claude Code on 27.10.2025.
//

import SwiftUI
import PhotosUI
import SwiftData

struct AddProgressPhotoView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var context
    @EnvironmentObject var userProfileManager: UserProfileManager
    @EnvironmentObject var appearanceManager: AppearanceManager

    @StateObject private var photoManager = PhotoManager.shared
    @StateObject private var camera = CameraViewModel()

    @State private var selectedPhotoType: PhotoType = .front
    @State private var notes: String = ""
    @State private var showImagePicker = false
    @State private var showReviewSheet = false
    @State private var capturedImage: UIImage?
    @State private var showPoseGuide = true
    @State private var isSaving = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Camera Preview
                    ZStack {
                        CameraPreview(camera: camera)
                            .ignoresSafeArea()

                        // Pose Guide Overlay
                        if showPoseGuide {
                            PoseGuideOverlay(photoType: selectedPhotoType)
                                .opacity(0.3)
                        }

                        // Top Controls
                        VStack {
                            HStack {
                                Button(action: {
                                    withAnimation {
                                        showPoseGuide.toggle()
                                    }
                                }) {
                                    Image(systemName: showPoseGuide ? "eye.fill" : "eye.slash.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color.black.opacity(0.5))
                                        .clipShape(Circle())
                                }

                                Spacer()

                                Button(action: {
                                    camera.flipCamera()
                                }) {
                                    Image(systemName: "camera.rotate")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color.black.opacity(0.5))
                                        .clipShape(Circle())
                                }
                            }
                            .padding()

                            Spacer()
                        }
                    }
                    .frame(maxHeight: .infinity)

                    // Bottom Controls
                    VStack(spacing: 20) {
                        // Photo Type Selector
                        HStack(spacing: 20) {
                            ForEach([PhotoType.front, PhotoType.side, PhotoType.back], id: \.self) { type in
                                Button(action: {
                                    withAnimation {
                                        selectedPhotoType = type
                                    }
                                }) {
                                    Text(type.rawValue)
                                        .font(.subheadline)
                                        .bold()
                                        .foregroundColor(selectedPhotoType == type ? .black : .white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 20)
                                                .fill(selectedPhotoType == type ? appearanceManager.accentColor.color : Color.white.opacity(0.2))
                                        )
                                }
                            }
                        }

                        // Capture Buttons
                        HStack(spacing: 40) {
                            // Import Button
                            Button(action: {
                                showImagePicker = true
                            }) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .frame(width: 60, height: 60)
                                    .background(Color.white.opacity(0.2))
                                    .clipShape(Circle())
                            }

                            // Capture Button
                            Button(action: {
                                capturePhoto()
                            }) {
                                ZStack {
                                    Circle()
                                        .stroke(Color.white, lineWidth: 4)
                                        .frame(width: 80, height: 80)

                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 68, height: 68)
                                }
                            }

                            // Placeholder for symmetry
                            Color.clear
                                .frame(width: 60, height: 60)
                        }
                        .padding(.bottom, 30)
                    }
                    .padding()
                    .background(Color.black)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }

                ToolbarItem(placement: .principal) {
                    Text("Progress Photo")
                        .foregroundColor(.white)
                        .font(.headline)
                }
            }
            .onAppear {
                camera.checkPermissions()
            }
            .onDisappear {
                camera.stopCamera()
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $capturedImage, onImagePicked: {
                    showReviewSheet = true
                })
            }
            .sheet(isPresented: $showReviewSheet) {
                if let image = capturedImage {
                    ReviewPhotoView(
                        image: image,
                        photoType: selectedPhotoType,
                        notes: $notes,
                        onSave: {
                            savePhoto(image: image)
                        },
                        onCancel: {
                            capturedImage = nil
                            showReviewSheet = false
                        }
                    )
                }
            }
        }
    }

    private func capturePhoto() {
        camera.capturePhoto { image in
            if let image = image {
                capturedImage = image
                showReviewSheet = true
            }
        }
    }

    private func savePhoto(image: UIImage) {
        isSaving = true

        Task {
            let weight = userProfileManager.currentProfile?.weight
            let profile = userProfileManager.currentProfile

            let photo = await photoManager.saveProgressPhoto(
                image: image,
                type: selectedPhotoType,
                notes: notes,
                weight: weight,
                userProfile: profile,
                context: context
            )

            await MainActor.run {
                isSaving = false
                if photo != nil {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Review Photo View

struct ReviewPhotoView: View {
    let image: UIImage
    let photoType: PhotoType
    @Binding var notes: String
    let onSave: () -> Void
    let onCancel: () -> Void

    @EnvironmentObject var userProfileManager: UserProfileManager
    @EnvironmentObject var appearanceManager: AppearanceManager

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Photo Preview
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 400)
                    .cornerRadius(12)
                    .padding()

                // Info
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Type:")
                            .foregroundColor(.secondary)
                        Text(photoType.rawValue)
                            .bold()
                        Spacer()
                    }

                    HStack {
                        Text("Weight:")
                            .foregroundColor(.secondary)
                        if let weight = userProfileManager.currentProfile?.weight {
                            Text(String(format: "%.1f kg", weight))
                                .bold()
                        } else {
                            Text("Not set")
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }

                    HStack {
                        Text("Date:")
                            .foregroundColor(.secondary)
                        Text(Date().formatted(date: .abbreviated, time: .omitted))
                            .bold()
                        Spacer()
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes (Optional)")
                            .foregroundColor(.secondary)
                            .font(.caption)

                        TextField("How are you feeling?", text: $notes, axis: .vertical)
                            .lineLimit(3...5)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(.horizontal)

                Spacer()

                // Save Button
                Button(action: onSave) {
                    Text("Save Progress Photo")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(appearanceManager.accentColor.color)
                        .foregroundColor(.black)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Review Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Retake") {
                        onCancel()
                    }
                }
            }
        }
    }
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let onImagePicked: () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let provider = results.first?.itemProvider else { return }

            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    DispatchQueue.main.async {
                        self.parent.image = image as? UIImage
                        self.parent.onImagePicked()
                    }
                }
            }
        }
    }
}
