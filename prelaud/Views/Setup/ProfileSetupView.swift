//
//  ProfileSetupView.swift - FIXED FOR POCKETBASE
//  prelaud
//
//  Fixed username checking with proper PocketBase integration
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
                
                do {
                    // FIXED: Use new PocketBase API
                    let result = await profileManager.checkUsernameAvailability(newUsername)
                    
                    await MainActor.run {
                        isCheckingUsername = false
                        usernameAvailable = result.isValid
                        if !result.isValid {
                            usernameError = result.errorMessage
                        }
                    }
                } catch {
                    await MainActor.run {
                        isCheckingUsername = false
                        usernameAvailable = false
                        usernameError = "Failed to check username availability"
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
        case .welcome:
            break
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
        }
    }
    
    // MARK: - FIXED Validation for PocketBase
    private func validateUsername() -> Bool {
        // Check if username has been validated
        guard let isAvailable = usernameAvailable else {
            usernameError = "Please wait for username validation"
            HapticFeedbackManager.shared.error()
            return false
        }
        
        if isAvailable {
            return true
        } else {
            // Error message should already be set from the check
            if usernameError == nil {
                usernameError = "Username is not available"
            }
            HapticFeedbackManager.shared.error()
            return false
        }
    }
    
    private func validateArtistName() -> Bool {
        let validation = profileManager.isArtistNameValid(artistName)
        artistNameError = validation.error
        if !validation.isValid {
            HapticFeedbackManager.shared.error()
        }
        return validation.isValid
    }
    
    private func createProfile() {
        isCreatingProfile = true
        
        HapticFeedbackManager.shared.success()
        
        // Simulate API call delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            profileManager.createProfile(
                username: username,
                artistName: artistName,
                bio: bio.isEmpty ? nil : bio,
                profileImage: selectedImage
            )
            
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

// MARK: - FIXED Enhanced Username Step

struct EnhancedUsernameStep: View {
    @Binding var username: String
    @Binding var error: String?
    @Binding var checkResult: Bool?
    @Binding var isChecking: Bool
    let onNext: () -> Void
    let onBack: () -> Void
    let onUsernameChanged: (String) -> Void
    
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 40) {
            // Minimal title
            Text("username")
                .font(.system(size: 24, weight: .thin))
                .foregroundColor(.white.opacity(0.8))
            
            // Enhanced input with validation feedback
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
                        .focused($isTextFieldFocused)
                        .onChange(of: username) { _, newValue in
                            onUsernameChanged(newValue)
                        }
                    
                    // Validation indicator
                    validationIndicator
                }
                
                Rectangle()
                    .fill(getUnderlineColor())
                    .frame(height: 0.5)
                    .animation(.easeInOut(duration: 0.2), value: isTextFieldFocused)
                    .animation(.easeInOut(duration: 0.2), value: checkResult)
                
                // Error or status message
                statusMessage
            }
            .padding(.horizontal, 20)
            
            // Enhanced navigation
            UltraMinimalNavigation(
                canContinue: canContinue,
                onBack: onBack,
                onNext: onNext
            )
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }
    
    @ViewBuilder
    private var validationIndicator: some View {
        if isChecking {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.6)))
                .scaleEffect(0.7)
                .frame(width: 20, height: 20)
        } else if let result = checkResult {
            Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(result ? .green : .red.opacity(0.8))
                .font(.system(size: 16))
                .frame(width: 20, height: 20)
        } else {
            Color.clear
                .frame(width: 20, height: 20)
        }
    }
    
    @ViewBuilder
    private var statusMessage: some View {
        if let error = error {
            Text(error)
                .font(.system(size: 12, weight: .light))
                .foregroundColor(.red.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity.combined(with: .move(edge: .top)))
        } else if let result = checkResult, result {
            Text("Username is available")
                .font(.system(size: 12, weight: .light))
                .foregroundColor(.green.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity.combined(with: .move(edge: .top)))
        } else {
            Color.clear
                .frame(height: 16)
        }
    }
    
    private func getUnderlineColor() -> Color {
        if isChecking {
            return .white.opacity(0.4)
        } else if let result = checkResult {
            return result ? .green.opacity(0.6) : .red.opacity(0.6)
        } else if isTextFieldFocused {
            return .white.opacity(0.6)
        } else {
            return .white.opacity(0.2)
        }
    }
    
    private var canContinue: Bool {
        !username.isEmpty &&
        !isChecking &&
        checkResult == true
    }
}

// MARK: - Reused Components from Original File

struct UltraMinimalWelcomeStep: View {
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 60) {
            // Ultra minimal icon
            Image(systemName: "music.note")
                .font(.system(size: 32, weight: .ultraLight))
                .foregroundColor(.white.opacity(0.6))
            
            // Minimal text
            VStack(spacing: 20) {
                HStack(spacing: 0) {
                    Text("pre")
                        .font(.system(size: 28, weight: .thin, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                        .tracking(2.0)
                    
                    Text("laud")
                        .font(.system(size: 28, weight: .thin, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                        .tracking(2.0)
                }
                
                Text("setup")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            // Minimal continue action
            Button(action: onNext) {
                Text("begin")
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(.white.opacity(0.8))
                    .tracking(0.5)
            }
            .buttonStyle(UltraMinimalButtonStyle())
        }
    }
}

struct UltraMinimalArtistNameStep: View {
    @Binding var artistName: String
    @Binding var error: String?
    let onNext: () -> Void
    let onBack: () -> Void
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 40) {
            Text("artist name")
                .font(.system(size: 24, weight: .thin))
                .foregroundColor(.white.opacity(0.8))
            
            VStack(spacing: 8) {
                TextField("", text: $artistName)
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(.white)
                    .textFieldStyle(PlainTextFieldStyle())
                    .focused($isTextFieldFocused)
                    .multilineTextAlignment(.center)
                
                Rectangle()
                    .fill(.white.opacity(isTextFieldFocused ? 0.6 : 0.2))
                    .frame(height: 0.5)
                    .animation(.easeInOut(duration: 0.2), value: isTextFieldFocused)
                
                if let error = error {
                    Text(error)
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 20)
            
            UltraMinimalNavigation(
                canContinue: !artistName.isEmpty,
                onBack: onBack,
                onNext: onNext
            )
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }
}

struct UltraMinimalProfileImageStep: View {
    @Binding var selectedImage: UIImage?
    @Binding var showingImagePicker: Bool
    let onNext: () -> Void
    let onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 40) {
            Text("photo")
                .font(.system(size: 24, weight: .thin))
                .foregroundColor(.white.opacity(0.8))
            
            Button(action: { showingImagePicker = true }) {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(.white.opacity(0.05))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .ultraLight))
                                .foregroundColor(.white.opacity(0.4))
                        )
                }
            }
            .buttonStyle(UltraMinimalButtonStyle())
            
            UltraMinimalNavigation(
                canContinue: true,
                onBack: onBack,
                onNext: onNext
            )
        }
    }
}

struct UltraMinimalBioStep: View {
    @Binding var bio: String
    let onNext: () -> Void
    let onBack: () -> Void
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 40) {
            Text("bio")
                .font(.system(size: 24, weight: .thin))
                .foregroundColor(.white.opacity(0.8))
            
            Text("optional")
                .font(.system(size: 12, weight: .light))
                .foregroundColor(.white.opacity(0.3))
            
            VStack(spacing: 8) {
                TextField("", text: $bio, axis: .vertical)
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(.white)
                    .textFieldStyle(PlainTextFieldStyle())
                    .focused($isTextFieldFocused)
                    .lineLimit(3...4)
                    .multilineTextAlignment(.center)
                
                Rectangle()
                    .fill(.white.opacity(isTextFieldFocused ? 0.6 : 0.2))
                    .frame(height: 0.5)
                    .animation(.easeInOut(duration: 0.2), value: isTextFieldFocused)
            }
            .padding(.horizontal, 20)
            
            UltraMinimalNavigation(
                canContinue: true,
                onBack: onBack,
                onNext: onNext,
                nextText: "done"
            )
        }
    }
}

struct UltraMinimalCompleteStep: View {
    @Binding var isCreating: Bool
    
    var body: some View {
        VStack(spacing: 40) {
            if isCreating {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.6)))
                    .scaleEffect(0.8)
                
                Text("creating")
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(.white.opacity(0.6))
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 24, weight: .ultraLight))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("ready")
                        .font(.system(size: 20, weight: .light))
                        .foregroundColor(.white.opacity(0.8))
                    
                    // Automatischer Fade-Out nach 2 Sekunden
                    Text("welcome to prelaud")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(.white.opacity(0.4))
                }
                .onAppear {
                    // Automatisch nach 2 Sekunden zur Haupt-App
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        // Der Übergang passiert automatisch durch isProfileSetup = true
                    }
                }
            }
        }
    }
}

// MARK: - Ultra Minimal Navigation Component
struct UltraMinimalNavigation: View {
    let canContinue: Bool
    let onBack: () -> Void
    let onNext: () -> Void
    let nextText: String
    
    init(canContinue: Bool, onBack: @escaping () -> Void, onNext: @escaping () -> Void, nextText: String = "next") {
        self.canContinue = canContinue
        self.onBack = onBack
        self.onNext = onNext
        self.nextText = nextText
    }
    
    var body: some View {
        HStack(spacing: 60) {
            Button(action: onBack) {
                Text("back")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(.white.opacity(0.4))
            }
            .buttonStyle(UltraMinimalButtonStyle())
            
            Button(action: onNext) {
                Text(nextText)
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(canContinue ? .white.opacity(0.8) : .white.opacity(0.2))
            }
            .disabled(!canContinue)
            .buttonStyle(UltraMinimalButtonStyle())
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
