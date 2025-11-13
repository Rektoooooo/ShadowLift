//
//  ProfileImageCell.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 07.03.2025.
//


import SwiftUI

struct ProfileImageCell: View {
    var profileImage: UIImage?
    var frameSize: CGFloat

    var body: some View {
        if let image = profileImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: frameSize, height: frameSize)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.6), radius: 15, x: 0, y: 5)
        } else {
            Image("defaultProfileImage")
                .resizable()
                .frame(width: frameSize, height: frameSize)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.6), radius: 15, x: 0, y: 5)
        }
    }
}
