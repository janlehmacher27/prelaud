//
//  AlbumsView.swift - BACKEND NAVIGATION REPARIERT
//  prelaud
//
//  FIXED: onSelectAlbum wird jetzt korrekt weitergegeben
//

import SwiftUI

// Enum außerhalb definieren
enum AlbumTab: String, CaseIterable {
    case myAlbums = "my albums"
    case shared = "shared"
}

struct AlbumsView: View {
    @Binding var albums: [Album]
    @Binding var selectedService: StreamingService
    @Binding var showingSettings: Bool
    @Binding var currentAlbum: Album?
    let onCreateAlbum: () -> Void
    let onSelectAlbum: (Album) -> Void // FIXED: Diese Funktion fehlte!
    
    @StateObject private var audioPlayer = AudioPlayerManager.shared
    @StateObject private var profileManager = UserProfileManager.shared
    @StateObject private var supabaseManager = AudioManager.shared
    @StateObject private var dataManager = DataPersistenceManager.shared
    @StateObject private var sharingManager = AlbumSharingManager.shared
    
    // Backend states (hidden from UI)
    @State private var selectedTab: AlbumTab = .myAlbums
    @State private var sharedAlbums: [Album] = []
    @State private var pendingRequests: [SharingRequest] = []
    @State private var activeSheet: SheetType?
    @State private var albumToShare: Album?
    @State private var showingDeleteAlert = false
    @State private var albumToDelete: Album?
    @State private var showingEditSheet = false
    @State private var albumToEdit: Album?
    @State private var debugTapCount = 0
    @State private var processingRequests: Set<String> = []
    
    // Simple sheet enum
    enum SheetType: Identifiable {
        case settings
        case share(Album)
        
        var id: String {
            switch self {
            case .settings: return "settings"
            case .share(let album): return "share-\(album.id)"
            }
        }
    }
    
    // Computed properties
    private var headerTextColor: Color {
        switch selectedService {
        case .spotify:
            return .white.opacity(0.6)
        case .appleMusic:
            return .black.opacity(0.6)
        case .amazonMusic:
            return .white.opacity(0.6)
        case .youtubeMusic:
            return .white.opacity(0.6)
        }
    }
    
    private var serviceIconColor: Color {
        switch selectedService {
        case .spotify:
            return .white
        case .appleMusic:
            return .black
        case .amazonMusic:
            return .white
        case .youtubeMusic:
            return .white
        }
    }
    
    var body: some View {
        ZStack {
            // Dynamic Background
            backgroundForService
            
            VStack(spacing: 0) {
                // Simple Header
                headerSection
                    .padding(.top, 50)
                    .padding(.bottom, 24)
                
                // Service selector
                streamingServiceSelector
                    .padding(.bottom, 20)
                
                // Tab Bar
                HStack(spacing: 40) {
                    ForEach(AlbumTab.allCases, id: \.self) { tab in
                        TabButton(
                            tab: tab,
                            isSelected: selectedTab == tab,
                            textColor: serviceIconColor,
                            hasNotification: tab == .shared && !pendingRequests.isEmpty,
                            onTap: { selectTab(tab) }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
                
                // Content based on selected tab
                ScrollView {
                    VStack(spacing: 0) {
                        if selectedTab == .shared {
                            sharedAlbumsContent
                        } else {
                            myAlbumsContent
                        }
                    }
                }
                
                Spacer()
            }
            
            // Mini player overlay
            miniPlayerOverlay
        }
        .onAppear(perform: setupView)
        .refreshable {
            await refreshData()
        }
        .sheet(item: $activeSheet) { sheetType in
            switch sheetType {
            case .settings:
                SettingsView()
            case .share(let album):
                AlbumShareSheet(
                    album: album,
                    onDismiss: {
                        activeSheet = nil
                        albumToShare = nil
                    }
                )
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            if let album = albumToEdit {
                AlbumEditView(
                    album: .constant(album),
                    onSave: { updatedAlbum in
                        if let index = albums.firstIndex(where: { $0.id == updatedAlbum.id }) {
                            albums[index] = updatedAlbum
                            dataManager.savedAlbums[index] = updatedAlbum
                            dataManager.saveAlbumsMetadata()
                        }
                        albumToEdit = nil
                        showingEditSheet = false
                    },
                    onDelete: {
                        if let album = albumToEdit {
                            confirmDeleteAlbum(album)
                            albumToEdit = nil
                            showingEditSheet = false
                        }
                    }
                )
            }
        }
        .alert("Delete Album", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let album = albumToDelete {
                    confirmDeleteAlbum(album)
                }
            }
        } message: {
            if let album = albumToDelete {
                Text("Are you sure you want to delete \"\(album.title)\"? This action cannot be undone.")
            }
        }
    }
    
    @ViewBuilder
    private var backgroundForService: some View {
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
    
    private var headerSection: some View {
        HStack {
            Text("prelaud")
                .font(.system(size: 11, weight: .light, design: .monospaced))
                .foregroundColor(headerTextColor)
                .tracking(3.0)
                .onTapGesture {
                    handleHeaderTap()
                }
            
            Spacer()
            
            Button(action: {
                HapticFeedbackManager.shared.lightImpact()
                activeSheet = .settings
            }) {
                Image(systemName: "person.circle")
                    .font(.system(size: 20))
                    .foregroundColor(headerTextColor)
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var streamingServiceSelector: some View {
        HStack(spacing: 32) {
            ForEach(StreamingService.allCases, id: \.self) { service in
                ServiceButton(
                    service: service,
                    isSelected: selectedService == service,
                    selectedServiceColor: serviceIconColor,
                    onTap: { selectService(service) }
                )
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var myAlbumsContent: some View {
        VStack(spacing: 24) {
            if selectedService == .spotify {
                spotifyMyAlbumsContent
            } else {
                otherServiceContent
            }
        }
        .padding(.bottom, 100)
    }
    
    private var spotifyMyAlbumsContent: some View {
        VStack(spacing: 24) {
            // CREATE ALBUM BUTTON
            Button(action: {
                HapticFeedbackManager.shared.cardTap()
                onCreateAlbum()
            }) {
                VStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.02))
                        .frame(height: 120)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.system(size: 32, weight: .ultraLight))
                                    .foregroundColor(.white.opacity(0.3))
                                
                                Text("create album")
                                    .font(.system(size: 11, weight: .light, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.3))
                                    .tracking(1.0)
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.white.opacity(0.05), lineWidth: 1)
                        )
                }
            }
            .buttonStyle(MinimalButtonStyle())
            .padding(.horizontal, 20)
            
            // ALBUMS GRID - FIXED: onSelectAlbum wird jetzt weitergegeben!
            if !albums.isEmpty {
                SpotifyAlbumsGrid(
                    albums: albums,
                    onAlbumTap: { album in
                        print("🎯 Album tapped: \(album.title)")
                        onSelectAlbum(album) // FIXED: Korrekte Funktion aufrufen
                    },
                    onShareAlbum: { album in
                        print("📤 Share album: \(album.title)")
                        shareAlbum(album)
                    },
                    onDeleteAlbum: { album in
                        print("🗑️ Delete album: \(album.title)")
                        deleteAlbum(album)
                    },
                    onEditAlbum: { album in
                        print("✏️ Edit album: \(album.title)")
                        editAlbum(album)
                    }
                )
            } else {
                emptyStateView
            }
        }
    }
    
    private var otherServiceContent: some View {
        VStack(spacing: 16) {
            ForEach(albums, id: \.id) { album in
                UniversalAlbumRow(
                    album: album,
                    selectedService: selectedService,
                    onTap: {
                        print("🎯 Universal album tapped: \(album.title)")
                        onSelectAlbum(album) // FIXED: Korrekte Funktion aufrufen
                    },
                    onShare: {
                        print("📤 Universal share album: \(album.title)")
                        shareAlbum(album)
                    }
                )
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var sharedAlbumsContent: some View {
        VStack(spacing: 20) {
            // FIXED: Zeige pending requests zuerst
            if !pendingRequests.isEmpty {
                VStack(spacing: 16) {
                    HStack {
                        Text("pending requests")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(serviceIconColor.opacity(0.8))
                            .tracking(1.0)
                        
                        Spacer()
                        
                        Text("\(pendingRequests.count)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(.red))
                    }
                    .padding(.horizontal, 20)
                    
                    ForEach(pendingRequests, id: \.id) { request in
                        SharingRequestRow(
                            request: request,
                            selectedService: selectedService,
                            onAccept: {
                                print("✅ Accept request: \(request.shareId)")
                                acceptSharingRequest(request)
                            },
                            onDecline: {
                                print("❌ Decline request: \(request.shareId)")
                                declineSharingRequest(request)
                            }
                        )
                    }
                }
            }
            
            // Divider wenn beide Sections vorhanden sind
            if !pendingRequests.isEmpty && !sharedAlbums.isEmpty {
                HStack {
                    Rectangle()
                        .fill(serviceIconColor.opacity(0.2))
                        .frame(height: 0.5)
                    
                    Text("shared albums")
                        .font(.system(size: 12, weight: .light, design: .monospaced))
                        .foregroundColor(serviceIconColor.opacity(0.4))
                        .tracking(1.0)
                        .padding(.horizontal, 16)
                    
                    Rectangle()
                        .fill(serviceIconColor.opacity(0.2))
                        .frame(height: 0.5)
                }
                .padding(.horizontal, 20)
            }
            
            // Shared albums
            if !sharedAlbums.isEmpty {
                ForEach(sharedAlbums, id: \.id) { album in
                    UniversalAlbumRow(
                        album: album,
                        selectedService: selectedService,
                        onTap: {
                            print("🎯 Shared album tapped: \(album.title)")
                            onSelectAlbum(album)
                        },
                        onShare: {
                            print("📤 Share shared album: \(album.title)")
                            shareAlbum(album)
                        }
                    )
                }
            } else if pendingRequests.isEmpty {
                sharedEmptyStateView
            }
        }
        .padding(.bottom, 100)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 60)
            
            Image(systemName: "music.note")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundColor(headerTextColor.opacity(0.3))
            
            VStack(spacing: 12) {
                Text("Keine Alben")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(headerTextColor.opacity(0.8))
                
                Text("Erstelle dein erstes Album")
                    .font(.system(size: 16))
                    .foregroundColor(headerTextColor.opacity(0.5))
            }
            
            Button(action: {
                HapticFeedbackManager.shared.cardTap()
                onCreateAlbum()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                    
                    Text("Album erstellen")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(selectedService == .appleMusic ? .white : .black)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(selectedService == .appleMusic ? .black.opacity(0.8) : .white.opacity(0.9))
                )
            }
            .buttonStyle(MinimalButtonStyle())
            
            Spacer()
        }
    }
    
    private var sharedEmptyStateView: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 60)
            
            Image(systemName: "person.2")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundColor(headerTextColor.opacity(0.3))
            
            VStack(spacing: 12) {
                Text("Keine geteilten Alben")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(headerTextColor.opacity(0.8))
                
                Text("Hier erscheinen mit dir geteilte Alben")
                    .font(.system(size: 16))
                    .foregroundColor(headerTextColor.opacity(0.5))
            }
            
            Spacer()
        }
    }
    
    private var miniPlayerOverlay: some View {
        VStack {
            Spacer()
            if audioPlayer.currentSong != nil {
                AdaptiveMiniPlayer(service: selectedService)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 90)
            }
        }
    }
    
    // MARK: - Backend Functions (alle funktionieren jetzt korrekt)
    
    private func setupView() {
        print("🚀 AlbumsView setupView called")
        loadSharedContent()
        loadPendingRequests()
    }
    
    private func selectService(_ service: StreamingService) {
        HapticFeedbackManager.shared.selection()
        withAnimation(.smooth(duration: 0.3)) {
            selectedService = service
        }
        print("🎵 Service selected: \(service.rawValue)")
    }
    
    private func selectTab(_ tab: AlbumTab) {
        HapticFeedbackManager.shared.selection()
        withAnimation(.smooth(duration: 0.3)) {
            selectedTab = tab
        }
        print("📂 Tab selected: \(tab.rawValue)")
    }
    
    // FIXED: Diese Funktion wird nicht mehr verwendet, da onSelectAlbum direkt aufgerufen wird
    private func selectAlbum(_ album: Album) {
        print("⚠️ selectAlbum called - this should not happen anymore!")
        onSelectAlbum(album)
    }
    
    private func shareAlbum(_ album: Album) {
        print("📤 shareAlbum called for: \(album.title)")
        HapticFeedbackManager.shared.lightImpact()
        albumToShare = album
        activeSheet = .share(album)
    }
    
    private func deleteAlbum(_ album: Album) {
        print("🗑️ deleteAlbum called for: \(album.title)")
        HapticFeedbackManager.shared.lightImpact()
        albumToDelete = album
        showingDeleteAlert = true
    }
    
    private func confirmDeleteAlbum(_ album: Album) {
        print("💥 confirmDeleteAlbum called for: \(album.title)")
        HapticFeedbackManager.shared.mediumImpact()
        
        withAnimation(.smooth(duration: 0.3)) {
            albums.removeAll { $0.id == album.id }
        }
        
        dataManager.deleteAlbum(album)
        
        if let currentSong = audioPlayer.currentSong,
           album.songs.contains(where: { $0.id == currentSong.id }) {
            audioPlayer.stop()
        }
        
        albumToDelete = nil
        albumToEdit = nil
        
        HapticFeedbackManager.shared.success()
    }
    
    private func editAlbum(_ album: Album) {
        print("✏️ editAlbum called for: \(album.title)")
        HapticFeedbackManager.shared.lightImpact()
        albumToEdit = album
        showingEditSheet = true
    }
    
    private func loadSharedContent() {
        Task {
            _ = await sharingManager.loadSharedAlbums()
            sharedAlbums = sharingManager.sharedWithMeAlbums
        }
    }
    
    private func loadPendingRequests() {
        Task {
            if let requests = await sharingManager.loadPendingRequests() {
                // FIXED: Only show truly pending requests
                let trulyPendingRequests = requests.filter { $0.status == .pending }
                pendingRequests = trulyPendingRequests
                print("📋 Loaded \(trulyPendingRequests.count) truly pending requests in AlbumsView")
            } else {
                pendingRequests = []
            }
        }
    }
    
    private func acceptSharingRequest(_ request: SharingRequest) {
        // Prevent multiple clicks
        guard !processingRequests.contains(request.pocketBaseId) else {
            print("⏳ Request already being processed: \(request.shareId)")
            return
        }
        
        print("✅ Accepting sharing request: \(request.shareId)")
        HapticFeedbackManager.shared.success()
        
        // Add to processing set
        processingRequests.insert(request.pocketBaseId)
        
        Task {
            do {
                try await sharingManager.respondToRequest(requestId: request.pocketBaseId, accept: true)
                
                await MainActor.run {
                    // Remove from processing set
                    processingRequests.remove(request.pocketBaseId)
                    
                    // Remove from pending requests (redundant safety check)
                    pendingRequests.removeAll { $0.pocketBaseId == request.pocketBaseId }
                    
                    // Refresh shared content to get the new album
                    loadSharedContent()
                }
                
                print("✅ Successfully accepted sharing request")
            } catch {
                await MainActor.run {
                    // Remove from processing set on error
                    processingRequests.remove(request.pocketBaseId)
                }
                print("❌ Failed to accept sharing request: \(error)")
            }
        }
    }
    
    private func declineSharingRequest(_ request: SharingRequest) {
        // Prevent multiple clicks
        guard !processingRequests.contains(request.pocketBaseId) else {
            print("⏳ Request already being processed: \(request.shareId)")
            return
        }
        
        print("❌ Declining sharing request: \(request.shareId)")
        HapticFeedbackManager.shared.mediumImpact()
        
        // Add to processing set
        processingRequests.insert(request.pocketBaseId)
        
        Task {
            do {
                try await sharingManager.respondToRequest(requestId: request.pocketBaseId, accept: false)
                
                await MainActor.run {
                    // Remove from processing set
                    processingRequests.remove(request.pocketBaseId)
                    
                    // Remove from pending requests (redundant safety check)
                    pendingRequests.removeAll { $0.pocketBaseId == request.pocketBaseId }
                }
                
                print("✅ Successfully declined sharing request")
            } catch {
                await MainActor.run {
                    // Remove from processing set on error
                    processingRequests.remove(request.pocketBaseId)
                }
                print("❌ Failed to decline sharing request: \(error)")
            }
        }
    }
    
    private func refreshData() async {
        loadSharedContent()
        loadPendingRequests()
    }
    
    private func handleHeaderTap() {
        #if DEBUG
        debugTapCount += 1
        if debugTapCount >= 5 {
            print("🔧 Debug refresh triggered")
            Task {
                await refreshData()
            }
        }
        #endif
    }
}

// MARK: - Separate Komponenten (unverändert, aber mit Debug-Ausgaben)

struct SpotifyAlbumsGrid: View {
    let albums: [Album]
    let onAlbumTap: (Album) -> Void
    let onShareAlbum: (Album) -> Void
    let onDeleteAlbum: (Album) -> Void
    let onEditAlbum: (Album) -> Void
    
    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(albums, id: \.id) { album in
                SpotifyAlbumRowWithContextMenu(
                    album: album,
                    onTap: {
                        print("🎯 SpotifyAlbumRowWithContextMenu onTap: \(album.title)")
                        onAlbumTap(album)
                    },
                    onShare: {
                        print("📤 SpotifyAlbumRowWithContextMenu onShare: \(album.title)")
                        onShareAlbum(album)
                    },
                    onDelete: {
                        print("🗑️ SpotifyAlbumRowWithContextMenu onDelete: \(album.title)")
                        onDeleteAlbum(album)
                    },
                    onEdit: {
                        print("✏️ SpotifyAlbumRowWithContextMenu onEdit: \(album.title)")
                        onEditAlbum(album)
                    }
                )
            }
        }
        .padding(.horizontal, 0)
    }
}

struct SpotifyAlbumRowWithContextMenu: View {
    let album: Album
    let onTap: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            print("🎯 Button action triggered for: \(album.title)")
            onTap()
        }) {
            HStack(spacing: 16) {
                // Album Cover
                Group {
                    if let coverImage = album.coverImage {
                        Image(uiImage: coverImage)
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                    } else {
                        Rectangle()
                            .fill(Color(red: 0.18, green: 0.18, blue: 0.18))
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 32, weight: .ultraLight))
                                    .foregroundColor(.white.opacity(0.3))
                            )
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Album Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(album.title)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    Text(album.artist)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                    
                    Text("\(album.songs.count) songs")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Play indicator or more options
                Button(action: {
                    print("🎯 Context menu button tapped for: \(album.title)")
                    // Context menu wird automatisch angezeigt
                }) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.4))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .onLongPressGesture(minimumDuration: 0.0, maximumDistance: .infinity, perform: {}, onPressingChanged: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        })
        .contextMenu {
            Button(action: {
                print("🎯 Context menu Play Album: \(album.title)")
                onTap()
            }) {
                Label("Play Album", systemImage: "play.fill")
            }
            
            Button(action: {
                print("📤 Context menu Share Album: \(album.title)")
                onShare()
            }) {
                Label("Share Album", systemImage: "square.and.arrow.up")
            }
            
            Button(action: {
                print("✏️ Context menu Edit Album: \(album.title)")
                onEdit()
            }) {
                Label("Edit Album", systemImage: "pencil")
            }
            
            Button(role: .destructive, action: {
                print("🗑️ Context menu Delete Album: \(album.title)")
                onDelete()
            }) {
                Label("Delete Album", systemImage: "trash")
            }
        }
    }
}

// Rest der Komponenten bleibt unverändert...
struct TabButton: View {
    let tab: AlbumTab
    let isSelected: Bool
    let textColor: Color
    let hasNotification: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Text(tab.rawValue)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(isSelected ? textColor.opacity(0.9) : textColor.opacity(0.5))
                        .tracking(0.5)
                    
                    if hasNotification {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                    }
                }
                
                Rectangle()
                    .fill(isSelected ? textColor.opacity(0.8) : .clear)
                    .frame(height: 1)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ServiceButton: View {
    let service: StreamingService
    let isSelected: Bool
    let selectedServiceColor: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: service.iconName)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? selectedServiceColor.opacity(0.9) : selectedServiceColor.opacity(0.3))
                
                Text(service.rawValue)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(isSelected ? selectedServiceColor.opacity(0.7) : selectedServiceColor.opacity(0.3))
                    .tracking(0.5)
            }
        }
        .buttonStyle(MinimalButtonStyle())
    }
}

struct UniversalAlbumRow: View {
    let album: Album
    let selectedService: StreamingService
    let onTap: () -> Void
    let onShare: () -> Void
    
    private var textColor: Color {
        selectedService == .appleMusic ? .black : .white
    }
    
    var body: some View {
        Button(action: {
            print("🎯 UniversalAlbumRow tapped: \(album.title)")
            onTap()
        }) {
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
                Button(action: {
                    print("📤 UniversalAlbumRow share button: \(album.title)")
                    onShare()
                }) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20))
                        .foregroundColor(textColor.opacity(0.6))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Background Views (unverändert)
struct SpotifyBackground: View {
    var body: some View {
        Color.black.ignoresSafeArea()
    }
}

struct AppleMusicBackground: View {
    var body: some View {
        Color.white.ignoresSafeArea()
    }
}

struct AmazonMusicBackground: View {
    var body: some View {
        Color.blue.ignoresSafeArea()
    }
}

struct YouTubeMusicBackground: View {
    var body: some View {
        Color.red.ignoresSafeArea()
    }
}

// MARK: - NEW: Sharing Request Row Component
struct SharingRequestRow: View {
    let request: SharingRequest
    let selectedService: StreamingService
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    private var textColor: Color {
        selectedService == .appleMusic ? .black : .white
    }
    
    private var accentColor: Color {
        selectedService == .appleMusic ? .black : .white
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Album Icon
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedService == .appleMusic ? .gray.opacity(0.2) : Color(red: 0.18, green: 0.18, blue: 0.18))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 24, weight: .light))
                            .foregroundColor(textColor.opacity(0.4))
                    )
                
                // Request Info
                VStack(alignment: .leading, spacing: 4) {
                    Text("@\(request.fromUsername) wants to share")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(textColor.opacity(0.8))
                        .lineLimit(1)
                    
                    Text(request.albumTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(textColor)
                        .lineLimit(1)
                    
                    Text("by \(request.albumArtist)")
                        .font(.system(size: 14))
                        .foregroundColor(textColor.opacity(0.6))
                        .lineLimit(1)
                    
                    if request.songCount > 0 {
                        Text("\(request.songCount) songs")
                            .font(.system(size: 12))
                            .foregroundColor(textColor.opacity(0.4))
                    }
                }
                
                Spacer()
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                // Decline Button
                Button(action: onDecline) {
                    Text("decline")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(textColor.opacity(0.6))
                        .tracking(1.0)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(textColor.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                
                // Accept Button
                Button(action: onAccept) {
                    Text("accept")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(selectedService == .appleMusic ? .white : .black)
                        .tracking(1.0)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(accentColor)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(selectedService == .appleMusic ?
                      .white.opacity(0.8) :
                      .white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(textColor.opacity(0.1), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 20)
    }
}
