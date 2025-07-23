//
//  ProfileSetupView.swift - FIXED VERSION
//  prelaud
//
//  Fixed unreachable catch block
//

import SwiftUI

struct ProfileSetupView: View {
    @StateObject private var profileManager = UserProfileManager.shared
    @State private var currentStep: SetupStep = .welcome
    @State private var username = ""
    @State private var artistName = ""
    @State private var bio = ""
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    
    // Enhanced validation states - FIXED for PocketBase
    @State private var usernameError: String?
    @State private var artistNameError: String?
    @State private var isCreatingProfile = false
    @State private var usernameAvailable: Bool?
    @State private var lastCheckedUsername = ""
    @State private var isCheckingUsername = false
    
    enum SetupStep {
        case welcome
        case username
        case artistName
        case profileImage
        case bio
        case complete
    }
    
    var body: some View {
        ZStack {
            // Ultra minimal black background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Ultra minimal progress (only dots, no other UI)
                if currentStep != .welcome {
                    ultraMinimalProgress
                        .padding(.top, 60)
                }
                
                Spacer()
                
                // Step content
                switch currentStep {
                case .welcome:
                    UltraMinimalWelcomeStep(onNext: { nextStep() })
                case .username:
                    EnhancedUsernameStep(
                        username: $username,
                        error: $usernameError,
                        checkResult: $usernameAvailable,
                        isChecking: $isCheckingUsername,
                        onNext: { nextStep() },
                        onBack: { previousStep() },
                        onUsernameChanged: { newUsername in
                            handleUsernameChange(newUsername)
                        }
                    )
                case .artistName:
                    UltraMinimalArtistNameStep(
                        artistName: $artistName,
                        error: $artistNameError,
                        onNext: { nextStep() },
                        onBack: { previousStep() }
                    )
                case .profileImage:
                    UltraMinimalProfileImageStep(
                        selectedImage: $selectedImage,
                        showingImagePicker: $showingImagePicker,
                        onNext: { nextStep() },
                        onBack: { previousStep() }
                    )
                case .bio:
                    UltraMinimalBioStep(
                        bio: $bio,
                        onNext: { nextStep() },
                        onBack: { previousStep() }
                    )
                case .complete:
                    UltraMinimalCompleteStep(isCreating: $isCreatingProfile)
                }
                
                Spacer()
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
        }
        .animation(.smooth(duration: 0.3), value: currentStep)
    }
    
    // MARK: - Ultra Minimal Progress
    private var ultraMinimalProgress: some View {
        HStack(spacing: 6) {
            ForEach(1...4, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep.rawValue ? .white.opacity(0.8) : .white.opacity(0.1))
                    .frame(width: 4, height: 4)
                    .animation(.smooth(duration: 0.2), value: currentStep)
            }
        }
    }
    
    // MARK: - FIXED Username Handling for PocketBase
    private func handleUsernameChange(_ newUsername: String) {
        // Reset previous results
        usernameError = nil
        usernameAvailable = nil
        
        // Debounce username checking
        guard !newUsername.isEmpty && newUsername != lastCheckedUsername else { return }
        
        Task {
            // Wait for user to stop typing
            try? await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
            
            // Only check if username hasn't changed again
            if newUsername == username && newUsername != lastCheckedUsername {
                lastCheckedUsername = newUsername
                
                await MainActor.run {
                    isCheckingUsername = true
                }
                
                // FIXED: Proper error handling instead of unreachable catch
                let result = await profileManager.checkUsernameAvailability(newUsername)
                
                await MainActor.run {
                    isCheckingUsername = false
                    usernameAvailable = result.isValid
                    if !result.isValid {
                        usernameError = result.errorMessage
                    }
                }
            }
        }
    }
    
    // MARK: - Navigation
    private func nextStep() {
        HapticFeedbackManager.shared.lightImpact()
        
        switch currentStep {
        case .welcome:
            currentStep = .username
        case .username:
            if validateUsername() {
                currentStep = .artistName
            }
        case .artistName:
            if validateArtistName() {
                currentStep = .profileImage
            }
        case .profileImage:
            currentStep = .bio
        case .bio:
            currentStep = .complete
            createProfile()
        case .complete:
            break
        }
    }
    
    private func previousStep() {
        HapticFeedbackManager.shared.lightImpact()
        
        switch currentStep {
        case .username:
            currentStep = .welcome
        case .artistName:
            currentStep = .username
        case .profileImage:
            currentStep = .artistName
        case .bio:
            currentStep = .profileImage
        case .complete:
            currentStep = .bio
        case .welcome:
            break
        }
    }
    
    // MARK: - Validation
    private func validateUsername() -> Bool {
        usernameError = nil
        
        if username.isEmpty {
            usernameError = "Username is required"
            return false
        }
        
        if username.count < 3 {
            usernameError = "Username must be at least 3 characters"
            return false
        }
        
        if username.count > 20 {
            usernameError = "Username must be 20 characters or less"
            return false
        }
        
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        if username.rangeOfCharacter(from: allowedCharacters.inverted) != nil {
            usernameError = "Username can only contain letters, numbers, and underscores"
            return false
        }
        
        if usernameAvailable != true {
            usernameError = "Username is not available"
            return false
        }
        
        return true
    }
    
    private func validateArtistName() -> Bool {
        artistNameError = nil
        
        if artistName.isEmpty {
            artistNameError = "Artist name is required"
            return false
        }
        
        if artistName.count < 2 {
            artistNameError = "Artist name must be at least 2 characters"
            return false
        }
        
        if artistName.count > 50 {
            artistNameError = "Artist name must be 50 characters or less"
            return false
        }
        
        return true
    }
    
    // MARK: - Profile Creation
    private func createProfile() {
        isCreatingProfile = true
        
        Task {
            // FIXED: Direct call without do-catch since checkUsernameAvailability doesn't throw
            await profileManager.createProfile(
                username: username,
                artistName: artistName,
                bio: bio.isEmpty ? nil : bio,
                profileImage: selectedImage
            )
            
            await MainActor.run {
                isCreatingProfile = false
                
                // WICHTIG: Explizit syncManager Status setzen
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    let syncManager = DatabaseSyncManager.shared
                    syncManager.syncComplete = true
                    syncManager.needsSetup = false
                    
                    print("🔧 Profile creation complete - updating sync status")
                    print("  - shouldShowSetup: \(syncManager.shouldShowSetup)")
                }
            }
        }
    }
}

// MARK: - FIXED Enhanced Username Step

struct EnhancedUsernameStep: View {
    @Binding var username: String
    @Binding var error: String?
    @Binding var checkResult: Bool?
    @Binding var isChecking: Bool
    let onNext: () -> Void
    let onBack: () -> Void
    let onUsernameChanged: (String) -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Text("choose your username")
                    .font(.system(size: 16, weight: .light, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                    .tracking(2.0)
                
                Text("this will be how others find and identify you")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                HStack {
                    Text("@")
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(.white.opacity(0.6))
                    
                    TextField("username", text: $username)
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(.white)
                        .textFieldStyle(PlainTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onSubmit {
                            if canContinue {
                                onNext()
                            }
                        }
                        .onChange(of: username) { _, newValue in
                            onUsernameChanged(newValue)
                        }
                    
                    // Status indicator
                    Group {
                        if isChecking {
                            ProgressView()
                                .scaleEffect(0.6)
                                .tint(.white.opacity(0.6))
                        } else if let available = checkResult {
                            Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(available ? .green : .red)
                        }
                    }
                    .frame(width: 20)
                }
                .padding(.bottom, 8)
                .overlay(
                    Rectangle()
                        .fill(.white.opacity(0.2))
                        .frame(height: 0.5),
                    alignment: .bottom
                )
                
                if let error = error {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.red.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 40)
            
            HStack(spacing: 40) {
                Button("back") {
                    onBack()
                }
                .font(.system(size: 11, weight: .light, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1.0)
                
                Button("continue") {
                    onNext()
                }
                .font(.system(size: 11, weight: .light, design: .monospaced))
                .foregroundColor(canContinue ? .white.opacity(0.8) : .white.opacity(0.2))
                .tracking(1.0)
                .disabled(!canContinue)
            }
        }
    }
    
    private var canContinue: Bool {
        !username.isEmpty && checkResult == true && !isChecking
    }
}

// MARK: - Other Step Views

struct UltraMinimalWelcomeStep: View {
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 40) {
            VStack(spacing: 16) {
                Text("welcome")
                    .font(.system(size: 24, weight: .ultraLight, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                    .tracking(3.0)
                
                Text("let's set up your profile")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Button("get started") {
                onNext()
            }
            .font(.system(size: 11, weight: .light, design: .monospaced))
            .foregroundColor(.white.opacity(0.8))
            .tracking(1.0)
            .buttonStyle(UltraMinimalButtonStyle())
        }
    }
}

struct UltraMinimalArtistNameStep: View {
    @Binding var artistName: String
    @Binding var error: String?
    let onNext: () -> Void
    let onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Text("artist name")
                    .font(.system(size: 16, weight: .light, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                    .tracking(2.0)
                
                Text("how should your music be credited?")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            VStack(spacing: 16) {
                TextField("Artist Name", text: $artistName)
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(.white)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(.bottom, 8)
                    .overlay(
                        Rectangle()
                            .fill(.white.opacity(0.2))
                            .frame(height: 0.5),
                        alignment: .bottom
                    )
                    .onSubmit {
                        if canContinue {
                            onNext()
                        }
                    }
                
                if let error = error {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.red.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 40)
            
            HStack(spacing: 40) {
                Button("back") {
                    onBack()
                }
                .font(.system(size: 11, weight: .light, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1.0)
                
                Button("continue") {
                    onNext()
                }
                .font(.system(size: 11, weight: .light, design: .monospaced))
                .foregroundColor(canContinue ? .white.opacity(0.8) : .white.opacity(0.2))
                .tracking(1.0)
                .disabled(!canContinue)
            }
        }
    }
    
    private var canContinue: Bool {
        !artistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct UltraMinimalProfileImageStep: View {
    @Binding var selectedImage: UIImage?
    @Binding var showingImagePicker: Bool
    let onNext: () -> Void
    let onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Text("profile image")
                    .font(.system(size: 16, weight: .light, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                    .tracking(2.0)
                
                Text("optional - you can add one later")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            Button(action: { showingImagePicker = true }) {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(.white.opacity(0.1))
                        .frame(width: 100, height: 100)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .light))
                                .foregroundColor(.white.opacity(0.4))
                        )
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            HStack(spacing: 40) {
                Button("back") {
                    onBack()
                }
                .font(.system(size: 11, weight: .light, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1.0)
                
                Button("continue") {
                    onNext()
                }
                .font(.system(size: 11, weight: .light, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
                .tracking(1.0)
            }
        }
    }
}

struct UltraMinimalBioStep: View {
    @Binding var bio: String
    let onNext: () -> Void
    let onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Text("about you")
                    .font(.system(size: 16, weight: .light, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                    .tracking(2.0)
                
                Text("optional - tell others about your music")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            TextField("Write something about yourself...", text: $bio, axis: .vertical)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .textFieldStyle(PlainTextFieldStyle())
                .lineLimit(3...6)
                .padding(.horizontal, 40)
                .padding(.bottom, 8)
                .overlay(
                    Rectangle()
                        .fill(.white.opacity(0.2))
                        .frame(height: 0.5),
                    alignment: .bottom
                )
            
            HStack(spacing: 40) {
                Button("back") {
                    onBack()
                }
                .font(.system(size: 11, weight: .light, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1.0)
                
                Button("finish") {
                    onNext()
                }
                .font(.system(size: 11, weight: .light, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
                .tracking(1.0)
            }
        }
    }
}

struct UltraMinimalCompleteStep: View {
    @Binding var isCreating: Bool
    
    var body: some View {
        VStack(spacing: 32) {
            if isCreating {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(.white.opacity(0.6))
                        .scaleEffect(1.2)
                    
                    Text("creating your profile...")
                        .font(.system(size: 14, weight: .light, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(1.0)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(.green.opacity(0.8))
                    
                    Text("profile created!")
                        .font(.system(size: 16, weight: .light, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                        .tracking(2.0)
                }
            }
        }
    }
}

// MARK: - Setup Step Extension
extension ProfileSetupView.SetupStep {
    var rawValue: Int {
        switch self {
        case .welcome: return 0
        case .username: return 1
        case .artistName: return 2
        case .profileImage: return 3
        case .bio: return 4
        case .complete: return 5
        }
    }
}

// MARK: - UNIQUE Button Style for ProfileSetupView
struct UltraMinimalButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
