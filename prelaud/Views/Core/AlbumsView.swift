//
//  AlbumsView.swift - FIXED APPLE MUSIC TEXT COLORS
//  prelaud
//
//  Fixed header text and button colors for Apple Music service
//  ONLY REMOVED: Duplicate model definitions (SharingRequest, SharingRequestStatus)
//

import SwiftUI

// REMOVED: Duplicate SharingRequest and SharingRequestStatus definitions
// These are now in SharingModels.swift

struct AlbumsView: View {
    @Binding var albums: [Album]
    @Binding var selectedService: StreamingService
    @Binding var showingSettings: Bool
    @Binding var currentAlbum: Album?
    let onCreateAlbum: () -> Void
    
    @StateObject private var audioPlayer = AudioPlayerManager.shared
    @StateObject private var profileManager = UserProfileManager.shared
    @StateObject private var supabaseManager = AudioManager.shared
    @StateObject private var dataManager = DataPersistenceManager.shared
    @StateObject private var sharingManager = AlbumSharingManager.shared
    @State private var selectedTab: AlbumTab = .myAlbums
    @State private var sharedAlbums: [Album] = []
    @State private var pendingRequests: [SharingRequest] = []
    @State private var activeSheet: SheetType?
    @State private var albumToShare: Album?
    @State private var showingDeleteAlert = false
    @State private var albumToDelete: Album?
    
    // NEW: Album Edit States
    @State private var showingEditSheet = false
    @State private var albumToEdit: Album?
    
    // NEW: Sharing Request States
    @State private var isLoadingRequests = false
    @State private var requestError: String?
    
    private var textColor: Color {
        switch selectedService {
        case .spotify, .youtubeMusic, .amazonMusic:
            return .white
        case .appleMusic:
            return .black  // FIXED: Apple Music text should be black
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                backgroundView
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("albums")
                            .font(.system(size: 28, weight: .thin, design: .monospaced))
                            .foregroundColor(textColor)  // FIXED: Use proper text color
                            .tracking(1.0)
                        
                        Spacer()
                        
                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 18))
                                .foregroundColor(textColor.opacity(0.6))  // FIXED: Use proper text color
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                    
                    // Service-aware Tab Bar
                    tabBar
                    
                    // Content Area
                    TabView(selection: $selectedTab) {
                        // My Albums
                        myAlbumsView
                            .tag(AlbumTab.myAlbums)
                        
                        // Shared Albums
                        sharedAlbumsView
                            .tag(AlbumTab.shared)
                        
                        // Sharing Requests
                        sharingRequestsView
                            .tag(AlbumTab.requests)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .share:
                if let album = albumToShare {
                    AlbumShareSheet(album: album) {
                        activeSheet = nil
                        albumToShare = nil
                        // Refresh shared content after sharing
                        loadSharedContent()
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            if let album = albumToEdit {
                AlbumEditView(album: album) { updatedAlbum in
                    // Update the album in the main list
                    if let index = albums.firstIndex(where: { $0.id == updatedAlbum.id }) {
                        albums[index] = updatedAlbum
                        dataManager.savedAlbums[index] = updatedAlbum
                        dataManager.saveAlbums()
                    }
                    albumToEdit = nil
                    showingEditSheet = false
                }
            }
        }
        .alert("Delete Album", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let album = albumToDelete {
                    deleteAlbum(album)
                }
            }
        } message: {
            Text("Are you sure you want to delete this album? This action cannot be undone.")
        }
        .onAppear {
            loadSharedContent()
        }
        .onChange(of: selectedTab) { _ in
            HapticFeedbackManager.shared.lightImpact()
            if selectedTab == .requests {
                loadPendingRequests()
            } else if selectedTab == .shared {
                loadSharedAlbums()
            }
        }
    }
    
    // MARK: - Background Views
    
    @ViewBuilder
    private var backgroundView: some View {
        switch selectedService {
        case .spotify:
            SpotifyBackground()
        case .appleMusic:
            AppleMusicBackground()
        case .amazonMusic:
            AmazonMusicBackground()
        case .youtubeMusic:
            YouTubeMusicBackground()
        }
    }
    
    // MARK: - Tab Bar
    
    private var tabBar: some View {
        HStack(spacing: 0) {
            TabBarButton(
                title: "my albums",
                isSelected: selectedTab == .myAlbums,
                textColor: textColor,  // FIXED: Pass proper text color
                hasNotification: false
            ) {
                selectedTab = .myAlbums
            }
            
            TabBarButton(
                title: "shared",
                isSelected: selectedTab == .shared,
                textColor: textColor,  // FIXED: Pass proper text color
                hasNotification: sharingManager.getSharedAlbumCount() > 0
            ) {
                selectedTab = .shared
            }
            
            TabBarButton(
                title: "requests",
                isSelected: selectedTab == .requests,
                textColor: textColor,  // FIXED: Pass proper text color
                hasNotification: sharingManager.getPendingRequestsCount() > 0
            ) {
                selectedTab = .requests
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }
    
    // MARK: - Content Views
    
    private var myAlbumsView: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 8) {
                // Create Album Button
                SpotifyCreateAlbumRow(
                    selectedService: selectedService,
                    onTap: onCreateAlbum
                )
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                // Album List
                ForEach(albums) { album in
                    SpotifyAlbumRowWithContextMenu(
                        album: album,
                        onTap: {
                            HapticFeedbackManager.shared.lightImpact()
                            currentAlbum = album
                        },
                        onShare: {
                            albumToShare = album
                            activeSheet = .share
                        },
                        onDelete: {
                            albumToDelete = album
                            showingDeleteAlert = true
                        },
                        onEdit: {
                            albumToEdit = album
                            showingEditSheet = true
                        }
                    )
                    .padding(.horizontal, 24)
                }
            }
            .padding(.bottom, 100)
        }
    }
    
    private var sharedAlbumsView: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 8) {
                if sharingManager.isLoadingSharedAlbums {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: textColor))
                        .padding(.top, 40)
                } else if sharingManager.sharedWithMeAlbums.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2")
                            .font(.system(size: 40))
                            .foregroundColor(textColor.opacity(0.3))
                        
                        Text("no shared albums")
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(textColor.opacity(0.5))
                            .tracking(0.5)
                    }
                    .padding(.top, 60)
                } else {
                    ForEach(sharingManager.sharedWithMeAlbums) { album in
                        SpotifySharedAlbumRow(
                            album: album,
                            selectedService: selectedService,
                            onTap: {
                                HapticFeedbackManager.shared.lightImpact()
                                currentAlbum = album
                            },
                            onShare: {
                                // Could implement re-sharing here
                                print("Re-share album: \(album.title)")
                            }
                        )
                        .padding(.horizontal, 24)
                    }
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
    }
    
    private var sharingRequestsView: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                if isLoadingRequests {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: textColor))
                        .padding(.top, 40)
                } else if pendingRequests.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bell")
                            .font(.system(size: 40))
                            .foregroundColor(textColor.opacity(0.3))
                        
                        Text("no pending requests")
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(textColor.opacity(0.5))
                            .tracking(0.5)
                    }
                    .padding(.top, 60)
                } else {
                    ForEach(pendingRequests) { request in
                        SpotifyStyleSharingRequestRow(
                            request: request,
                            selectedService: selectedService,
                            onAccept: {
                                Task {
                                    do {
                                        try await approveSharingRequest(request)
                                        await loadPendingRequests()
                                        loadSharedAlbums()
                                    } catch {
                                        print("❌ Failed to approve request: \(error)")
                                        requestError = error.localizedDescription
                                    }
                                }
                            },
                            onDecline: {
                                Task {
                                    do {
                                        try await declineSharingRequest(request)
                                        await loadPendingRequests()
                                    } catch {
                                        print("❌ Failed to decline request: \(error)")
                                        requestError = error.localizedDescription
                                    }
                                }
                            }
                        )
                        .padding(.horizontal, 24)
                    }
                }
                
                if let error = requestError {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.8))
                        .padding(.top, 8)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
    }
    
    // MARK: - Helper Functions
    
    private func loadSharedContent() {
        sharingManager.loadSharedAlbums()
        loadPendingRequests()
    }
    
    private func loadSharedAlbums() {
        sharingManager.loadSharedAlbums()
    }
    
    private func loadPendingRequests() {
        Task {
            await MainActor.run {
                isLoadingRequests = true
            }
            
            do {
                let requests = try await fetchPendingSharingRequests()
                await MainActor.run {
                    self.pendingRequests = requests
                    self.isLoadingRequests = false
                    self.requestError = nil
                }
            } catch {
                await MainActor.run {
                    self.isLoadingRequests = false
                    self.requestError = error.localizedDescription
                }
                print("❌ Failed to load pending requests: \(error)")
            }
        }
    }
    
    private func deleteAlbum(_ album: Album) {
        withAnimation(.easeInOut(duration: 0.3)) {
            albums.removeAll { $0.id == album.id }
            dataManager.savedAlbums.removeAll { $0.id == album.id }
            dataManager.saveAlbums()
        }
        
        // Notify sharing manager if this album was shared
        if let shareId = album.shareId {
            NotificationCenter.default.post(
                name: NSNotification.Name("AlbumDeleted"),
                object: nil,
                userInfo: ["shareId": shareId]
            )
        }
        
        HapticFeedbackManager.shared.mediumImpact()
        albumToDelete = nil
    }
    
    private func getAlbumYear(_ album: Album) -> String {
        let year = Calendar.current.component(.year, from: album.releaseDate)
        return "\(year) • \(album.songs.count) songs"
    }
    
    // MARK: - Tab System
    
    enum AlbumTab: CaseIterable {
        case myAlbums
        case shared
        case requests
        
        var title: String {
            switch self {
            case .myAlbums: return "my albums"
            case .shared: return "shared"
            case .requests: return "requests"
            }
        }
    }
    
    enum SheetType: Identifiable {
        case share
        
        var id: String {
            switch self {
            case .share: return "share"
            }
        }
    }
    
    // MARK: - FIXED Tab Bar Button with proper color handling
    struct TabBarButton: View {
        let title: String
        let isSelected: Bool
        let textColor: Color  // NEW: Accept text color from parent
        let hasNotification: Bool
        let onTap: () -> Void
        
        var body: some View {
            Button(action: onTap) {
                VStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Text(title)
                            .font(.system(size: 11, weight: .light, design: .monospaced))
                            .foregroundColor(isSelected ? textColor.opacity(0.9) : textColor.opacity(0.5))  // FIXED: Use passed textColor
                            .tracking(0.5)
                        
                        if hasNotification {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                        }
                    }
                    
                    Rectangle()
                        .fill(isSelected ? textColor.opacity(0.8) : .clear)  // FIXED: Use passed textColor
                        .frame(height: 1)
                        .animation(.easeInOut(duration: 0.2), value: isSelected)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - FIXED Service Button with proper color handling
    struct ServiceButton: View {
        let service: StreamingService
        let isSelected: Bool
        let selectedServiceColor: Color  // NEW: Pass the correct color from parent
        let onTap: () -> Void
        
        var body: some View {
            Button(action: onTap) {
                VStack(spacing: 8) {
                    Image(systemName: service.iconName)
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? selectedServiceColor.opacity(0.9) : selectedServiceColor.opacity(0.3))  // FIXED: Use passed color
                    
                    Text(service.rawValue)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(isSelected ? selectedServiceColor.opacity(0.9) : selectedServiceColor.opacity(0.3))  // FIXED: Use passed color
                        .tracking(0.5)
                }
            }
            .buttonStyle(MinimalButtonStyle())
        }
    }
    
    // MARK: - Background Views (unchanged)
    struct SpotifyBackground: View {
        var body: some View {
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.05, green: 0.05, blue: 0.05),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
    
    struct AppleMusicBackground: View {
        var body: some View {
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.98, blue: 0.98),
                    Color(red: 0.95, green: 0.95, blue: 0.97)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
    
    struct AmazonMusicBackground: View {
        var body: some View {
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.16, blue: 0.20),
                    Color(red: 0.08, green: 0.12, blue: 0.16),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
    
    struct YouTubeMusicBackground: View {
        var body: some View {
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.05, green: 0.05, blue: 0.05),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
    
    // MARK: - Album Row Components (unchanged)
    
    struct SpotifyCreateAlbumRow: View {
        let selectedService: StreamingService
        let onTap: () -> Void
        @State private var isPressed = false
        
        private var textColor: Color {
            selectedService == .appleMusic ? .black : .white
        }
        
        var body: some View {
            Button(action: onTap) {
                HStack(spacing: 16) {
                    // Plus Icon
                    RoundedRectangle(cornerRadius: 6)
                        .fill(selectedService == .appleMusic ? .gray.opacity(0.2) : Color(red: 0.18, green: 0.18, blue: 0.18))
                        .frame(width: 56, height: 56)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.system(size: 24))
                                .foregroundColor(textColor.opacity(0.6))
                        )
                    
                    // Create Album Text
                    VStack(alignment: .leading, spacing: 4) {
                        Text("create album")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(textColor)
                        
                        Text("start your musical journey")
                            .font(.system(size: 14))
                            .foregroundColor(textColor.opacity(0.6))
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isPressed ? (selectedService == .appleMusic ? .black.opacity(0.05) : .white.opacity(0.05)) : Color.clear)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            }, perform: {})
        }
    }
    
    struct SpotifyAlbumRow: View {
        let album: Album
        let selectedService: StreamingService
        let onTap: () -> Void
        let onShare: () -> Void
        @State private var isHovered = false
        
        private var textColor: Color {
            selectedService == .appleMusic ? .black : .white
        }
        
        var body: some View {
            Button(action: onTap) {
                HStack(spacing: 16) {
                    // Album Cover
                    Group {
                        if let coverImage = album.coverImage {
                            Image(uiImage: coverImage)
                                .resizable()
                                .aspectRatio(1, contentMode: .fill)
                        } else {
                            Rectangle()
                                .fill(selectedService == .appleMusic ? .gray.opacity(0.2) : Color(red: 0.18, green: 0.18, blue: 0.18))
                                .overlay(
                                    Image(systemName: "music.note")
                                        .font(.system(size: 20))
                                        .foregroundColor(textColor.opacity(0.3))
                                )
                        }
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    
                    // Album Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(album.title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(textColor)
                            .lineLimit(1)
                        
                        Text(album.artist)
                            .font(.system(size: 14))
                            .foregroundColor(textColor.opacity(0.6))
                            .lineLimit(1)
                        
                        Text("\(album.songs.count) songs")
                            .font(.system(size: 12))
                            .foregroundColor(textColor.opacity(0.4))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // More Options
                    Button(action: onShare) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 20))
                            .foregroundColor(textColor.opacity(0.6))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isHovered ? (selectedService == .appleMusic ? .black.opacity(0.05) : .white.opacity(0.05)) : Color.clear)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }
        }
    }
    
    struct SpotifySharedAlbumRow: View {
        let album: Album
        let selectedService: StreamingService
        let onTap: () -> Void
        let onShare: () -> Void
        @State private var isHovered = false
        
        private var textColor: Color {
            selectedService == .appleMusic ? .black : .white
        }
        
        var body: some View {
            Button(action: onTap) {
                HStack(spacing: 16) {
                    // Album Cover
                    Group {
                        if let coverImage = album.coverImage {
                            Image(uiImage: coverImage)
                                .resizable()
                                .aspectRatio(1, contentMode: .fill)
                        } else {
                            Rectangle()
                                .fill(selectedService == .appleMusic ? .gray.opacity(0.2) : Color(red: 0.18, green: 0.18, blue: 0.18))
                                .overlay(
                                    Image(systemName: "music.note")
                                        .font(.system(size: 20))
                                        .foregroundColor(textColor.opacity(0.3))
                                )
                        }
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    
                    // Album Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(album.title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(textColor)
                            .lineLimit(1)
                        
                        if let ownerUsername = album.ownerUsername {
                            Text("von @\(ownerUsername)")
                                .font(.system(size: 14))
                                .foregroundColor(textColor.opacity(0.6))
                                .lineLimit(1)
                        }
                        
                        Text("\(album.songs.count) songs")
                            .font(.system(size: 12))
                            .foregroundColor(textColor.opacity(0.4))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Shared Icon
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 16))
                        .foregroundColor(textColor.opacity(0.4))
                    
                    // More Options
                    Button(action: onShare) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 20))
                            .foregroundColor(textColor.opacity(0.6))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isHovered ? (selectedService == .appleMusic ? .black.opacity(0.05) : .white.opacity(0.05)) : Color.clear)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }
        }
    }
    
    // MARK: - Enhanced Spotify Album Row with Context Menu
    struct SpotifyAlbumRowWithContextMenu: View {
        let album: Album
        let onTap: () -> Void
        let onShare: () -> Void
        let onDelete: () -> Void
        let onEdit: () -> Void
        @State private var isPressed = false
        
        var body: some View {
            Button(action: onTap) {
                HStack(spacing: 16) {
                    // Large Square Album Cover
                    Group {
                        if let coverImage = album.coverImage {
                            Image(uiImage: coverImage)
                                .resizable()
                                .aspectRatio(1, contentMode: .fill)
                        } else {
                            Rectangle()
                                .fill(Color(red: 0.25, green: 0.25, blue: 0.25))
                                .overlay(
                                    Image(systemName: "music.note")
                                        .font(.system(size: 35))
                                        .foregroundColor(.white.opacity(0.4))
                                )
                        }
                    }
                    .frame(width: 92, height: 92)
                    .cornerRadius(4)
                    
                    // Album Info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(album.title)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                        
                        Text(getAlbumYear(album))
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // More Options Button
                    Button(action: onShare) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.vertical, 12)
                .padding(.leading, 16)
                .padding(.trailing, 16)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isPressed ? Color.white.opacity(0.08) : Color.clear)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .contextMenu {
                Button("Share Album") {
                    onShare()
                }
                
                Button("Edit Album") {
                    onEdit()
                }
                
                Divider()
                
                Button("Delete Album", role: .destructive) {
                    onDelete()
                }
            }
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            }, perform: {})
        }
        
        private func getAlbumYear(_ album: Album) -> String {
            let year = Calendar.current.component(.year, from: album.releaseDate)
            return "\(year) • \(album.songs.count) songs"
        }
    }
    
    // MARK: - Sharing Components (unchanged)
    
    struct SpotifyStyleSharingRequestRow: View {
        let request: SharingRequest
        let selectedService: StreamingService
        let onAccept: () -> Void
        let onDecline: () -> Void
        @State private var isHovered = false
        
        private var textColor: Color {
            selectedService == .appleMusic ? .black : .white
        }
        
        var body: some View {
            HStack(spacing: 16) {
                // Album Cover Placeholder
                RoundedRectangle(cornerRadius: 6)
                    .fill(selectedService == .appleMusic ? .gray.opacity(0.2) : Color(red: 0.18, green: 0.18, blue: 0.18))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 20))
                            .foregroundColor(textColor.opacity(0.3))
                    )
                
                // Request Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(request.albumTitle)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(textColor)
                        .lineLimit(1)
                    
                    Text("by \(request.albumArtist)")
                        .font(.system(size: 14))
                        .foregroundColor(textColor.opacity(0.6))
                        .lineLimit(1)
                    
                    Text("from @\(request.fromUsername)")
                        .font(.system(size: 12))
                        .foregroundColor(textColor.opacity(0.5))
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 8) {
                    Button("Accept") {
                        onAccept()
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.green)
                    .font(.system(size: 12, weight: .medium))
                    
                    Button("Decline") {
                        onDecline()
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
                    .font(.system(size: 12, weight: .medium))
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? (selectedService == .appleMusic ? .black.opacity(0.05) : .white.opacity(0.05)) : Color.clear)
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }
        }
    }
}

// MARK: - IMPLEMENTED Functions for Sharing Requests
extension AlbumsView {
    func fetchPendingSharingRequests() async throws -> [SharingRequest] {
        print("🔍 Fetching pending sharing requests...")
        
        guard let currentUser = await UserProfileManager.shared.userProfile else {
            print("❌ No current user found")
            return []
        }
        
        let supabaseURL = "https://auzsunnwanzljiwdpzov.supabase.co"
        let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1enN1bm53YW56bGppd2Rwem92Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIxMzIyNjksImV4cCI6MjA2NzcwODI2OX0.UmuoVT-7uXq5SMFr9duiurbE52Oe865w4ghYPkFwexE"
        
        // Fetch sharing requests for current user
        let endpoint = "\(supabaseURL)/rest/v1/sharing_requests?to_user_id=eq.\(currentUser.id.uuidString)&status=eq.pending&select=*"
        guard let url = URL(string: endpoint) else {
            throw SharingError.invalidRequest
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SharingError.networkError
        }
        
        print("📋 Fetch sharing requests response: \(httpResponse.statusCode)")
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 Sharing requests data: \(responseString)")
        }
        
        if httpResponse.statusCode == 200 {
            // Parse the response manually to handle the JSON permissions
            guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                print("❌ Failed to parse JSON array")
                return []
            }
            
            var sharingRequests: [SharingRequest] = []
            
            for requestDict in jsonArray {
                do {
                    // Extract basic fields
                    guard let idString = requestDict["id"] as? String,
                          let id = UUID(uuidString: idString),
                          let shareId = requestDict["share_id"] as? String,
                          let fromUserId = requestDict["from_user_id"] as? String,
                          let fromUsername = requestDict["from_username"] as? String,
                          let toUserId = requestDict["to_user_id"] as? String,
                          let albumIdString = requestDict["album_id"] as? String,
                          let albumId = albumIdString, // Keep as String for SharingModels
                          let albumTitle = requestDict["album_title"] as? String,
                          let albumArtist = requestDict["album_artist"] as? String,
                          let songCount = requestDict["song_count"] as? Int,
                          let isRead = requestDict["is_read"] as? Bool,
                          let statusString = requestDict["status"] as? String,
                          let status = SharingRequestStatus(rawValue: statusString) else {
                        print("⚠️ Failed to parse basic fields for sharing request")
                        continue
                    }
                    
                    // Parse date
                    var createdAt = Date()
                    if let createdAtString = requestDict["created_at"] as? String {
                        createdAt = ISO8601DateFormatter().date(from: createdAtString) ?? Date()
                    }
                    
                    // Parse permissions from JSON string
                    var permissions = SharePermissions(canListen: true, canDownload: false)
                    if let permissionsString = requestDict["permissions"] as? String,
                       let permissionsData = permissionsString.data(using: .utf8),
                       let permissionsDict = try? JSONSerialization.jsonObject(with: permissionsData) as? [String: Any] {
                        
                        let canListen = permissionsDict["can_listen"] as? Bool ?? true
                        let canDownload = permissionsDict["can_download"] as? Bool ?? false
                        
                        var expiresAt: Date? = nil
                        if let expiresAtString = permissionsDict["expires_at"] as? String {
                            expiresAt = ISO8601DateFormatter().date(from: expiresAtString)
                        }
                        
                        permissions = SharePermissions(
                            canListen: canListen,
                            canDownload: canDownload,
                            expiresAt: expiresAt
                        )
                    }
                    
                    // Create SharingRequest using SharingModels definition
                    let sharingRequest = SharingRequest(
                        id: id,
                        shareId: shareId,
                        fromUserId: fromUserId,
                        fromUsername: fromUsername,
                        toUserId: toUserId,
                        albumId: albumId, // Now String instead of UUID
                        albumTitle: albumTitle,
                        albumArtist: albumArtist,
                        songCount: songCount,
                        permissions: permissions,
                        status: status,
                        isRead: isRead,
                        createdAt: createdAt
                    )
                    
                    sharingRequests.append(sharingRequest)
                    print("✅ Parsed sharing request: \(albumTitle) from @\(fromUsername)")
                    
                } catch {
                    print("❌ Failed to parse sharing request: \(error)")
                    continue
                }
            }
            
            print("✅ Fetched \(sharingRequests.count) pending sharing requests")
            return sharingRequests
            
        } else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Failed to fetch sharing requests: \(errorMessage)")
            throw SharingError.fetchFailed
        }
    }
    
    func approveSharingRequest(_ request: SharingRequest) async throws {
        print("✅ Approving sharing request: \(request.shareId)")
        
        let supabaseURL = "https://auzsunnwanzljiwdpzov.supabase.co"
        let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1enN1bm53YW56bGppd2Rwem92Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIxMzIyNjksImV4cCI6MjA2NzcwODI2OX0.UmuoVT-7uXq5SMFr9duiurbE52Oe865w4ghYPkFwexE"
        
        // Update the request status to approved
        let endpoint = "\(supabaseURL)/rest/v1/sharing_requests?id=eq.\(request.id.uuidString)"
        guard let url = URL(string: endpoint) else {
            throw SharingError.invalidRequest
        }
        
        let updateData: [String: Any] = [
            "status": "approved",
            "is_read": true
        ]
        
        var updateRequest = URLRequest(url: url)
        updateRequest.httpMethod = "PATCH"
        updateRequest.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        updateRequest.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        updateRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        updateRequest.httpBody = try JSONSerialization.data(withJSONObject: updateData)
        
        let (data, response) = try await URLSession.shared.data(for: updateRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SharingError.networkError
        }
        
        if httpResponse.statusCode == 204 {
            print("✅ Sharing request approved successfully")
        } else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Failed to approve sharing request: \(errorMessage)")
            throw SharingError.updateFailed
        }
    }
    
    func declineSharingRequest(_ request: SharingRequest) async throws {
        print("❌ Declining sharing request: \(request.shareId)")
        
        let supabaseURL = "https://auzsunnwanzljiwdpzov.supabase.co"
        let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1enN1bm53YW56bGppd2Rwem92Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIxMzIyNjksImV4cCI6MjA2NzcwODI2OX0.UmuoVT-7uXq5SMFr9duiurbE52Oe865w4ghYPkFwexE"
        
        // Update the request status to declined
        let endpoint = "\(supabaseURL)/rest/v1/sharing_requests?id=eq.\(request.id.uuidString)"
        guard let url = URL(string: endpoint) else {
            throw SharingError.invalidRequest
        }
        
        let updateData: [String: Any] = [
            "status": "declined",
            "is_read": true
        ]
        
        var updateRequest = URLRequest(url: url)
        updateRequest.httpMethod = "PATCH"
        updateRequest.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        updateRequest.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        updateRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        updateRequest.httpBody = try JSONSerialization.data(withJSONObject: updateData)
        
        let (data, response) = try await URLSession.shared.data(for: updateRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SharingError.networkError
        }
        
        if httpResponse.statusCode == 204 {
            print("✅ Sharing request declined successfully")
        } else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Failed to decline sharing request: \(errorMessage)")
            throw SharingError.updateFailed
        }
    }
}
