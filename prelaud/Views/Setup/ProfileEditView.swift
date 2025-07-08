//
//  ProfileEditView.swift
//  prelaud
//
//  Profile editing with enhanced username validation
//

import SwiftUI

struct ProfileEditView: View {
    @StateObject private var profileManager = UserProfileManager.shared
    @Environment(\.dismiss) private var dismiss
    
    // Editable fields
    @State private var username: String = ""
    @State private var artistName: String = ""
    @State private var bio: String = ""
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    
    // Validation states
    @State private var usernameError: String?
    @State private var artistNameError: String?
    @State private var usernameCheckResult: UsernameCheckResult?
    @State private var lastCheckedUsername = ""
    @State private var hasUnsavedChanges = false
    @State private var isSaving = false
    @State private var showingDiscardAlert = false
    
    // Focus states
    @FocusState private var isUsernameFocused: Bool
    @FocusState private var isArtistNameFocused: Bool
    @FocusState private var isBioFocused: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dark background
                Color.black.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        // Header
                        headerSection
                        
                        // Profile Image Section
                        profileImageSection
                        
                        // Form Fields
                        formSection
                        
                        // Save Button
                        saveButton
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            loadCurrentProfile()
        }
        .onChange(of: username) { _, newValue in
            checkForChanges()
            handleUsernameChange(newValue)
        }
        .onChange(of: artistName) { _, _ in checkForChanges() }
        .onChange(of: bio) { _, _ in checkForChanges() }
        .onChange(of: selectedImage) { _, _ in checkForChanges() }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
        }
        .alert("Discard Changes?", isPresented: $showingDiscardAlert) {
            Button("Discard", role: .destructive) {
                HapticFeedbackManager.shared.mediumImpact()
                dismiss()
            }
            Button("Cancel", role: .cancel) {
                HapticFeedbackManager.shared.lightImpact()
            }
        } message: {
            Text("You have unsaved changes. Are you sure you want to discard them?")
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: handleBackButton) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                        Text("Back")
                            .font(.system(size: 17))
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(MinimalButtonStyle())
                
                Spacer()
                
                Text("Edit Profile")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Invisible spacer for balance
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                    Text("Back")
                        .font(.system(size: 17))
                }
                .opacity(0)
            }
            .padding(.top, 20)
        }
    }
    
    // MARK: - Profile Image Section
    private var profileImageSection: some View {
        VStack(spacing: 16) {
            Button(action: { showingImagePicker = true }) {
                ZStack {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(.white.opacity(0.05))
                            .frame(width: 120, height: 120)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40, weight: .light))
                                    .foregroundColor(.white.opacity(0.3))
                            )
                    }
                    
                    // Edit overlay
                    Circle()
                        .fill(.black.opacity(0.6))
                        .frame(width: 120, height: 120)
                        .overlay(
                            VStack(spacing: 4) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                
                                Text("Edit")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        )
                        .opacity(0) // Hidden by default, could add hover effect
                }
            }
            .buttonStyle(MinimalButtonStyle())
            
            Text("Tap to change photo")
                .font(.system(size: 14, weight: .light))
                .foregroundColor(.white.opacity(0.5))
        }
    }
    
    // MARK: - Form Section
    private var formSection: some View {
        VStack(spacing: 24) {
            // Username Field with Enhanced Validation
            VStack(alignment: .leading, spacing: 12) {
                Text("Username")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                VStack(spacing: 8) {
                    HStack {
                        Text("@")
                            .font(.system(size: 18, weight: .light))
                            .foregroundColor(.white.opacity(0.4))
                        
                        TextField("", text: $username)
                            .font(.system(size: 18, weight: .light))
                            .foregroundColor(.white)
                            .textFieldStyle(PlainTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .focused($isUsernameFocused)
                        
                        // Validation indicator
                        Group {
                            if profileManager.isCheckingUsername && username != profileManager.username {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.6)))
                                    .scaleEffect(0.7)
                            } else if let result = usernameCheckResult, username != profileManager.username {
                                Image(systemName: result.isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(result.isValid ? .green : .red.opacity(0.8))
                                    .font(.system(size: 16))
                            } else if username == profileManager.username {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue.opacity(0.8))
                                    .font(.system(size: 16))
                            }
                        }
                        .frame(width: 20, height: 20)
                    }
                    
                    Rectangle()
                        .fill(getUsernameUnderlineColor())
                        .frame(height: 0.5)
                        .animation(.easeInOut(duration: 0.2), value: isUsernameFocused)
                        .animation(.easeInOut(duration: 0.2), value: usernameCheckResult)
                    
                    // Error or status message
                    if let error = usernameError {
                        Text(error)
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(.red.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    } else if let result = usernameCheckResult, result.isValid, username != profileManager.username {
                        Text("Username is available")
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(.green.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    } else if username == profileManager.username {
                        Text("Current username")
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(.blue.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            
            // Artist Name Field
            VStack(alignment: .leading, spacing: 12) {
                Text("Artist Name")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                VStack(spacing: 8) {
                    TextField("", text: $artistName)
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(.white)
                        .textFieldStyle(PlainTextFieldStyle())
                        .focused($isArtistNameFocused)
                    
                    Rectangle()
                        .fill(.white.opacity(isArtistNameFocused ? 0.6 : 0.2))
                        .frame(height: 0.5)
                        .animation(.easeInOut(duration: 0.2), value: isArtistNameFocused)
                    
                    if let error = artistNameError {
                        Text(error)
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(.red.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            
            // Bio Field
            VStack(alignment: .leading, spacing: 12) {
                Text("Bio")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("Optional")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(.white.opacity(0.4))
                
                VStack(spacing: 8) {
                    TextField("Tell us about yourself...", text: $bio, axis: .vertical)
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(.white)
                        .textFieldStyle(PlainTextFieldStyle())
                        .focused($isBioFocused)
                        .lineLimit(3...6)
                    
                    Rectangle()
                        .fill(.white.opacity(isBioFocused ? 0.6 : 0.2))
                        .frame(height: 0.5)
                        .animation(.easeInOut(duration: 0.2), value: isBioFocused)
                }
            }
        }
    }
    
    // MARK: - Save Button
    private var saveButton: some View {
        Button(action: saveProfile) {
            HStack(spacing: 8) {
                if isSaving {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .medium))
                }
                
                Text(isSaving ? "Saving..." : "Save Changes")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(canSave ? .white : .white.opacity(0.3))
            )
        }
        .disabled(!canSave)
        .buttonStyle(MinimalButtonStyle())
        .opacity(hasUnsavedChanges ? 1.0 : 0.6)
        .animation(.easeInOut(duration: 0.2), value: hasUnsavedChanges)
        .animation(.easeInOut(duration: 0.2), value: canSave)
    }
    
    // MARK: - Helper Methods
    
    private func loadCurrentProfile() {
        guard let profile = profileManager.userProfile else { return }
        
        username = profile.username
        artistName = profile.artistName
        bio = profile.bio ?? ""
        selectedImage = profile.profileImage
        
        // Set initial state as current username is valid
        lastCheckedUsername = username
    }
    
    private func handleUsernameChange(_ newUsername: String) {
        // Reset previous results if username changed
        if newUsername != profileManager.username {
            usernameError = nil
            usernameCheckResult = nil
            
            // Debounce username checking
            guard !newUsername.isEmpty && newUsername != lastCheckedUsername else { return }
            
            Task {
                // Wait for user to stop typing
                try? await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
                
                // Only check if username hasn't changed again and is different from current
                if newUsername == username && newUsername != lastCheckedUsername && newUsername != profileManager.username {
                    lastCheckedUsername = newUsername
                    
                    let result = await profileManager.checkUsernameAvailability(newUsername)
                    
                    await MainActor.run {
                        usernameCheckResult = result
                        if !result.isValid {
                            usernameError = result.errorMessage
                        }
                    }
                }
            }
        }
    }
    
    private func checkForChanges() {
        guard let profile = profileManager.userProfile else { return }
        
        let hasChanges = username != profile.username ||
                        artistName != profile.artistName ||
                        bio != (profile.bio ?? "") ||
                        selectedImage != profile.profileImage
        
        withAnimation(.easeInOut(duration: 0.2)) {
            hasUnsavedChanges = hasChanges
        }
    }
    
    private func handleBackButton() {
        if hasUnsavedChanges {
            showingDiscardAlert = true
        } else {
            HapticFeedbackManager.shared.navigationBack()
            dismiss()
        }
    }
    
    private func validateFields() -> Bool {
        var isValid = true
        
        // Validate username
        if username != profileManager.username {
            if let result = usernameCheckResult {
                if !result.isValid {
                    usernameError = result.errorMessage
                    isValid = false
                }
            } else {
                usernameError = "Please wait for username validation"
                isValid = false
            }
        }
        
        // Validate artist name
        let artistValidation = profileManager.isArtistNameValid(artistName)
        if !artistValidation.isValid {
            artistNameError = artistValidation.error
            isValid = false
        } else {
            artistNameError = nil
        }
        
        return isValid
    }
    
    private func saveProfile() {
        guard validateFields() else {
            HapticFeedbackManager.shared.error()
            return
        }
        
        isSaving = true
        HapticFeedbackManager.shared.lightImpact()
        
        // Simulate save delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            profileManager.updateProfile(
                username: username,
                artistName: artistName,
                bio: bio.isEmpty ? nil : bio,
                profileImage: selectedImage
            )
            
            isSaving = false
            hasUnsavedChanges = false
            
            HapticFeedbackManager.shared.success()
            
            // Auto-dismiss after successful save
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                dismiss()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var canSave: Bool {
        hasUnsavedChanges &&
        !isSaving &&
        !username.isEmpty &&
        !artistName.isEmpty &&
        (username == profileManager.username || usernameCheckResult?.isValid == true)
    }
    
    private func getUsernameUnderlineColor() -> Color {
        if username == profileManager.username {
            return .blue.opacity(0.6)
        } else if profileManager.isCheckingUsername {
            return .white.opacity(0.4)
        } else if let result = usernameCheckResult {
            return result.isValid ? .green.opacity(0.6) : .red.opacity(0.6)
        } else if isUsernameFocused {
            return .white.opacity(0.6)
        } else {
            return .white.opacity(0.2)
        }
    }
}


