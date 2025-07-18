//
//  ProfileEditView.swift
//  prelaud
//
//  Simplified placeholder - will be rebuilt later
//

import SwiftUI

struct ProfileEditView: View {
    @ObservedObject var profileManager = UserProfileManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var username = ""
    @State private var artistName = ""
    @State private var bio = ""
    @State private var usernameAvailable: Bool?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Profile Edit")
                    .font(.largeTitle)
                    .padding()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Username")
                        .font(.headline)
                    TextField("Enter username", text: $username)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Text("Artist Name")
                        .font(.headline)
                    TextField("Enter artist name", text: $artistName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Text("Bio")
                        .font(.headline)
                    TextField("Enter bio", text: $bio)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding()
                
                Button("Save Changes") {
                    profileManager.updateProfile(
                        username: username.isEmpty ? nil : username,
                        artistName: artistName.isEmpty ? nil : artistName,
                        bio: bio.isEmpty ? nil : bio
                    )
                    dismiss()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                
                Spacer()
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if let profile = profileManager.userProfile {
                username = profile.username
                artistName = profile.artistName
                bio = profile.bio ?? ""
            }
        }
    }
}
