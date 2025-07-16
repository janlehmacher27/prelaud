//
//  AlbumShareSheet.swift - FIXED VERSION (ENGLISH + DATA FORMAT)
//  prelaud
//
//  Fixed data encoding and English interface
//

import SwiftUI

struct AlbumShareSheet: View {
    let album: Album
    @Environment(\.dismiss) private var dismiss
    
    @State private var targetUsername = ""
    @State private var isSharing = false
    @State private var shareResult: String?
    @State private var shareError: String?
    @State private var canDownload = false
    @State private var showAdvancedOptions = false
    
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        ZStack {
            // Consistent background gradient matching the app
            LinearGradient(
                colors: [
                    Color.black,
                    Color.black.opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Minimal header
                headerSection
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                
                // Content area
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 40) {
                        // Album preview - ultra minimal
                        albumPreviewSection
                        
                        // Share form - clean and simple
                        shareFormSection
                        
                        // Advanced options - collapsible
                        advancedOptionsSection
                        
                        // Share action
                        shareActionSection
                        
                        Spacer(minLength: 60)
                    }
                    .padding(.horizontal, 32)
                }
            }
        }
        .onTapGesture {
            // Dismiss keyboard on background tap
            isTextFieldFocused = false
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            Button("cancel") {
                HapticFeedbackManager.shared.lightImpact()
                dismiss()
            }
            .font(.system(size: 11, weight: .light, design: .monospaced))
            .foregroundColor(.white.opacity(0.4))
            .tracking(1.0)
            
            Spacer()
            
            Text("share album")
                .font(.system(size: 11, weight: .light, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
                .tracking(1.0)
            
            Spacer()
            
            // Invisible balance button
            Text("cancel")
                .font(.system(size: 11, weight: .light, design: .monospaced))
                .foregroundColor(.clear)
                .tracking(1.0)
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Album Preview
    private var albumPreviewSection: some View {
        VStack(spacing: 24) {
            // Cover - minimal square
            Group {
                if let coverImage = album.coverImage {
                    Image(uiImage: coverImage)
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.02))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 32, weight: .ultraLight))
                                .foregroundColor(.white.opacity(0.2))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.white.opacity(0.05), lineWidth: 0.5)
                        )
                }
            }
            
            // Info - minimal typography
            VStack(spacing: 8) {
                Text(album.title)
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                
                Text("by \(album.artist)")
                    .font(.system(size: 11, weight: .light, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(0.5)
                
                Text("\(album.songs.count) songs")
                    .font(.system(size: 10, weight: .light, design: .monospaced))
                    .foregroundColor(.white.opacity(0.25))
                    .tracking(0.5)
            }
        }
    }
    
    // MARK: - Share Form
    private var shareFormSection: some View {
        VStack(spacing: 24) {
            // Username input - ultra minimal
            VStack(spacing: 16) {
                HStack {
                    Text("with")
                        .font(.system(size: 11, weight: .light, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                        .tracking(1.0)
                    
                    Spacer()
                }
                
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Text("@")
                            .font(.system(size: 16, weight: .light))
                            .foregroundColor(.white.opacity(0.3))
                        
                        TextField("", text: $targetUsername)
                            .font(.system(size: 16, weight: .light))
                            .foregroundColor(.white.opacity(0.8))
                            .textFieldStyle(PlainTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .focused($isTextFieldFocused)
                            .placeholder("username", when: targetUsername.isEmpty)
                    }
                    
                    // Minimal underline
                    Rectangle()
                        .fill(isTextFieldFocused ? .white.opacity(0.3) : .white.opacity(0.08))
                        .frame(height: 0.5)
                        .animation(.easeInOut(duration: 0.2), value: isTextFieldFocused)
                    
                    // Status text
                    if !targetUsername.isEmpty {
                        HStack {
                            Text("request will be sent to @\(targetUsername)")
                                .font(.system(size: 9, weight: .light, design: .monospaced))
                                .foregroundColor(.white.opacity(0.25))
                                .tracking(0.5)
                            
                            Spacer()
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
    }
    
    // MARK: - Advanced Options
    private var advancedOptionsSection: some View {
        VStack(spacing: 16) {
            // Toggle for advanced options
            Button(action: {
                HapticFeedbackManager.shared.lightImpact()
                withAnimation(.smooth(duration: 0.3)) {
                    showAdvancedOptions.toggle()
                }
            }) {
                HStack {
                    Text("permissions")
                        .font(.system(size: 11, weight: .light, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                        .tracking(1.0)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.2))
                        .rotationEffect(.degrees(showAdvancedOptions ? 90 : 0))
                        .animation(.smooth(duration: 0.3), value: showAdvancedOptions)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Collapsible options
            if showAdvancedOptions {
                VStack(spacing: 16) {
                    // Listen permission (always on)
                    permissionRow(
                        icon: "play.circle",
                        title: "can listen",
                        subtitle: "play all songs",
                        isOn: .constant(true),
                        disabled: true
                    )
                    
                    // Download permission
                    permissionRow(
                        icon: "arrow.down.circle",
                        title: "can download",
                        subtitle: "save for offline",
                        isOn: $canDownload,
                        disabled: false
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    private func permissionRow(icon: String, title: String, subtitle: String, isOn: Binding<Bool>, disabled: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(disabled ? 0.2 : 0.4))
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(.white.opacity(disabled ? 0.3 : 0.6))
                
                Text(subtitle)
                    .font(.system(size: 9, weight: .light, design: .monospaced))
                    .foregroundColor(.white.opacity(disabled ? 0.15 : 0.25))
                    .tracking(0.5)
            }
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .toggleStyle(MinimalToggleStyle())
                .disabled(disabled)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Share Action
    private var shareActionSection: some View {
        VStack(spacing: 20) {
            // Share button - minimal
            Button(action: sendSharingRequest) {
                HStack(spacing: 8) {
                    if isSharing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black.opacity(0.8)))
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "paperplane")
                            .font(.system(size: 12, weight: .light))
                    }
                    
                    Text(isSharing ? "sending request" : "send request")
                        .font(.system(size: 11, weight: .light, design: .monospaced))
                        .tracking(1.0)
                }
                .foregroundColor(.black.opacity(0.8))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(canShare ? .white.opacity(0.9) : .white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(.white.opacity(canShare ? 0 : 0.05), lineWidth: 0.5)
                        )
                )
            }
            .disabled(!canShare)
            .animation(.easeInOut(duration: 0.2), value: canShare)
            .animation(.easeInOut(duration: 0.2), value: isSharing)
            
            // Result messages - minimal
            resultMessages
        }
    }
    
    private var resultMessages: some View {
        VStack(spacing: 12) {
            if let result = shareResult {
                HStack {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text(result)
                        .font(.system(size: 10, weight: .light, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(0.5)
                    
                    Spacer()
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            
            if let error = shareError {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 10))
                        .foregroundColor(.red.opacity(0.6))
                    
                    Text(error)
                        .font(.system(size: 10, weight: .light, design: .monospaced))
                        .foregroundColor(.red.opacity(0.6))
                        .tracking(0.5)
                    
                    Spacer()
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
    }
    
    // MARK: - Computed Properties
    private var canShare: Bool {
        !targetUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSharing
    }
    
    // MARK: - Actions
    private func sendSharingRequest() {
        guard canShare else { return }
        
        let username = targetUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        
        HapticFeedbackManager.shared.lightImpact()
        
        Task {
            await MainActor.run {
                isSharing = true
                shareResult = nil
                shareError = nil
            }
            
            do {
                let permissions = SharePermissions(
                    canListen: true,
                    canDownload: canDownload,
                    expiresAt: nil
                )
                
                try await createSharingRequestFixed(
                    album: album,
                    targetUsername: username,
                    permissions: permissions
                )
                
                await MainActor.run {
                    shareResult = "Request sent to @\(username)"
                    HapticFeedbackManager.shared.success()
                    
                    // Auto-dismiss after success
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                }
                
            } catch {
                await MainActor.run {
                    shareError = "Failed to send request"
                    HapticFeedbackManager.shared.error()
                    print("❌ Sharing error: \(error)")
                }
            }
            
            await MainActor.run {
                isSharing = false
            }
        }
    }
}

// MARK: - Custom View Extensions
extension View {
    func placeholder<Content: View>(
        _ placeholder: Content,
        when shouldShow: Bool,
        alignment: Alignment = .leading
    ) -> some View {
        ZStack(alignment: alignment) {
            self
            
            if shouldShow {
                placeholder
                    .allowsHitTesting(false)
            }
        }
    }
    
    func placeholder(
        _ text: String,
        when shouldShow: Bool,
        alignment: Alignment = .leading
    ) -> some View {
        placeholder(
            Text(text)
                .font(.system(size: 16, weight: .light))
                .foregroundColor(.white.opacity(0.3))
                .tracking(0.5),
            when: shouldShow,
            alignment: alignment
        )
    }
}

// MARK: - Toggle Style
struct MinimalToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            HapticFeedbackManager.shared.lightImpact()
            configuration.isOn.toggle()
        }) {
            Circle()
                .fill(configuration.isOn ? .white.opacity(0.8) : .white.opacity(0.1))
                .frame(width: 16, height: 16)
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.2), lineWidth: 0.5)
                )
                .overlay(
                    Circle()
                        .fill(.black.opacity(0.8))
                        .frame(width: 8, height: 8)
                        .opacity(configuration.isOn ? 1 : 0)
                        .scaleEffect(configuration.isOn ? 1 : 0.5)
                        .animation(.smooth(duration: 0.2), value: configuration.isOn)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - FIXED API Function for Creating Sharing Requests
@MainActor
func createSharingRequestFixed(album: Album, targetUsername: String, permissions: SharePermissions) async throws {
    print("🔍 createSharingRequestFixed called for album: \(album.title), user: \(targetUsername)")
    
    guard let currentUser = UserProfileManager.shared.userProfile else {
        print("❌ No current user found")
        throw SharingError.notLoggedIn
    }
    
    let supabaseURL = "https://auzsunnwanzljiwdpzov.supabase.co"
    let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1enN1bm53YW56bGppd2Rwem92Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIxMzIyNjksImV4cCI6MjA2NzcwODI2OX0.UmuoVT-7uXq5SMFr9duiurbE52Oe865w4ghYPkFwexE"
    
    // 1. Get target user by username
    print("🔍 Looking up user: \(targetUsername)")
    let userEndpoint = "\(supabaseURL)/rest/v1/users?username=eq.\(targetUsername.lowercased())&is_active=eq.true&select=*"
    guard let userUrl = URL(string: userEndpoint) else {
        print("❌ Invalid user URL")
        throw SharingError.invalidRequest
    }
    
    var userRequest = URLRequest(url: userUrl)
    userRequest.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
    userRequest.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
    userRequest.setValue("application/json", forHTTPHeaderField: "Accept")
    
    let (userData, userResponse) = try await URLSession.shared.data(for: userRequest)
    
    guard let httpUserResponse = userResponse as? HTTPURLResponse, httpUserResponse.statusCode == 200 else {
        print("❌ User lookup failed with status: \(String(describing: (userResponse as? HTTPURLResponse)?.statusCode))")
        throw SharingError.networkError
    }
    
    // MANUAL JSON PARSING for user lookup to avoid Codable issues
    guard let userJsonArray = try JSONSerialization.jsonObject(with: userData) as? [[String: Any]],
          let userDict = userJsonArray.first,
          let userIdString = userDict["id"] as? String,
          let targetUserId = UUID(uuidString: userIdString) else {
        print("❌ User not found or invalid user data")
        throw SharingError.userNotFound
    }
    
    print("✅ Found target user with ID: \(targetUserId)")
    
    // 2. Create sharing request with FIXED JSON structure
    let shareId = generateShareId()
    print("🔍 Generated share ID: \(shareId)")
    
    // FIXED: Create a plain dictionary with explicit type annotations
    let permissionsDict: [String: Any] = [
        "canListen": permissions.canListen,
        "canDownload": permissions.canDownload,
        "expiresAt": permissions.expiresAt?.iso8601String ?? NSNull()
    ]
    
    let sharingRequestData: [String: Any] = [
        "id": UUID().uuidString,
        "share_id": shareId,
        "from_user_id": currentUser.id.uuidString,
        "from_username": currentUser.username,
        "to_user_id": targetUserId.uuidString,
        "album_id": album.id.uuidString,
        "album_title": album.title,
        "album_artist": album.artist,
        "song_count": album.songs.count,
        "permissions": permissionsDict,
        "created_at": Date().iso8601String,
        "is_read": false,
        "status": "pending"
    ]
    
    print("🔍 Prepared sharing request data")
    
    // 3. Store album data for sharing
    let albumData = EncodableAlbum(
        from: album,
        shareId: shareId,
        ownerId: currentUser.id.uuidString,
        ownerUsername: currentUser.username
    )
    
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    
    if let encoded = try? encoder.encode(albumData) {
        UserDefaults.standard.set(encoded, forKey: "SharedAlbumData_\(shareId)")
        print("✅ Album data stored locally")
    }
    
    // 4. Send request to database
    let requestEndpoint = "\(supabaseURL)/rest/v1/sharing_requests"
    guard let requestUrl = URL(string: requestEndpoint) else {
        print("❌ Invalid request URL")
        throw SharingError.invalidRequest
    }
    
    var requestRequest = URLRequest(url: requestUrl)
    requestRequest.httpMethod = "POST"
    requestRequest.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
    requestRequest.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
    requestRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    requestRequest.setValue("return=representation", forHTTPHeaderField: "Prefer")
    
    // FIXED: Use JSONSerialization instead of Codable
    requestRequest.httpBody = try JSONSerialization.data(withJSONObject: sharingRequestData)
    
    print("🔍 About to send sharing request to Supabase")
    
    let (responseData, requestResponse) = try await URLSession.shared.data(for: requestRequest)
    
    guard let httpRequestResponse = requestResponse as? HTTPURLResponse else {
        print("❌ Invalid response type")
        throw SharingError.networkError
    }
    
    if !(200...299).contains(httpRequestResponse.statusCode) {
        // Print the actual error response
        if let errorString = String(data: responseData, encoding: .utf8) {
            print("❌ Supabase error response: \(errorString)")
        }
        print("❌ HTTP Status Code: \(httpRequestResponse.statusCode)")
        throw SharingError.creationFailed
    }
    
    print("✅ Sharing request created successfully")
}

private func generateShareId() -> String {
    return "share_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased().prefix(12))"
}
