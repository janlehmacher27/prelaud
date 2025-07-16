//
//  UploadView.swift - ENHANCED WITH YEAR SELECTION
//  MusicPreview
//
//  Enhanced album creation with year selection
//

import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

// MARK: - Upload Steps Enum
enum UploadStep {
    case albumInfo
    case songSelection
}

// MARK: - Audio File Model
struct AudioFile: Identifiable {
    let id: UUID
    let songId: String
    let url: URL
    let originalFilename: String
    var songTitle: String
    let duration: TimeInterval
    var isExplicit: Bool
    var supabaseFilename: String?
}

struct UploadView: View {
    let onAlbumCreated: (Album) -> Void
    let onDismiss: () -> Void
    
    @State private var currentStep: UploadStep = .albumInfo
    @State private var albumTitle = ""
    @State private var albumYear = Calendar.current.component(.year, from: Date())
    @State private var selectedCoverImage: UIImage?
    @State private var songs: [AudioFile] = []
    
    @StateObject private var profileManager = UserProfileManager.shared
    
    // Artist Name aus Profil
    private var artistName: String {
        profileManager.displayName
    }
    
    // Easter egg for test album
    @State private var secretTapCount = 0
    @State private var showSecretTestButton = false
    
    var body: some View {
        ZStack {
            // Minimal background
            LinearGradient(
                colors: [
                    Color.black,
                    Color.black.opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            switch currentStep {
            case .albumInfo:
                EnhancedAlbumInfoStep(
                    albumTitle: $albumTitle,
                    albumYear: $albumYear,
                    artistName: artistName,
                    selectedCoverImage: $selectedCoverImage,
                    showSecretTestButton: $showSecretTestButton,
                    secretTapCount: $secretTapCount,
                    onNext: {
                        HapticFeedbackManager.shared.pageTransition()
                        withAnimation(.smooth(duration: 0.4)) {
                            currentStep = .songSelection
                        }
                    },
                    onDismiss: {
                        HapticFeedbackManager.shared.navigationBack()
                        onDismiss()
                    },
                    onAlbumCreated: onAlbumCreated
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                
            case .songSelection:
                MinimalSongSelectionStep(
                    albumTitle: albumTitle,
                    albumYear: albumYear,
                    artistName: artistName,
                    selectedCoverImage: selectedCoverImage,
                    songs: $songs,
                    onBack: {
                        HapticFeedbackManager.shared.navigationBack()
                        withAnimation(.smooth(duration: 0.4)) {
                            currentStep = .albumInfo
                        }
                    },
                    onCreate: {
                        HapticFeedbackManager.shared.success()
                        createAlbum()
                    },
                    onDismiss: {
                        HapticFeedbackManager.shared.navigationBack()
                        onDismiss()
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            }
        }
    }
    
    private func createAlbum() {
        let convertedSongs = songs.map { audioFile in
            Song(
                title: audioFile.songTitle,
                artist: artistName,
                duration: audioFile.duration,
                coverImage: selectedCoverImage,
                audioFileName: audioFile.supabaseFilename,
                isExplicit: audioFile.isExplicit,
                songId: audioFile.songId
            )
        }
        
        // Create date from year
        let releaseDate = createDateFromYear(albumYear)
        
        let album = Album(
            title: albumTitle,
            artist: artistName,
            songs: convertedSongs,
            coverImage: selectedCoverImage,
            releaseDate: releaseDate
        )
        
        onAlbumCreated(album)
        onDismiss()
    }
    
    private func createDateFromYear(_ year: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = 1
        components.day = 1
        return Calendar.current.date(from: components) ?? Date()
    }
}

// MARK: - Enhanced Album Info Step with Year Selection
struct EnhancedAlbumInfoStep: View {
    @Binding var albumTitle: String
    @Binding var albumYear: Int
    let artistName: String
    @Binding var selectedCoverImage: UIImage?
    @Binding var showSecretTestButton: Bool
    @Binding var secretTapCount: Int
    let onNext: () -> Void
    let onDismiss: () -> Void
    let onAlbumCreated: (Album) -> Void
    
    @State private var showingImagePicker = false
    @State private var showingYearPicker = false
    @FocusState private var isAlbumTitleFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("cancel") {
                    HapticFeedbackManager.shared.lightImpact()
                    onDismiss()
                }
                .font(.system(size: 11, weight: .light, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1.0)
                
                Spacer()
                
                Text("new album")
                    .font(.system(size: 11, weight: .light, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                    .tracking(1.0)
                    .onTapGesture {
                        secretTapCount += 1
                        if secretTapCount >= 5 {
                            withAnimation(.spring()) {
                                showSecretTestButton = true
                            }
                        }
                    }
                
                Spacer()
                
                Button("next") {
                    HapticFeedbackManager.shared.lightImpact()
                    onNext()
                }
                .font(.system(size: 11, weight: .light, design: .monospaced))
                .foregroundColor(albumTitle.isEmpty ? .white.opacity(0.3) : .white.opacity(0.8))
                .tracking(1.0)
                .disabled(albumTitle.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 32)
            
            // Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 40) {
                    // Cover Image Selector
                    MinimalCoverImageSelector(selectedImage: $selectedCoverImage)
                        .onTapGesture {
                            HapticFeedbackManager.shared.lightImpact()
                            showingImagePicker = true
                        }
                    
                    // Album Details Form
                    VStack(spacing: 32) {
                        // Album Title
                        VStack(spacing: 16) {
                            HStack {
                                Text("album title")
                                    .font(.system(size: 11, weight: .light, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.4))
                                    .tracking(1.0)
                                
                                Spacer()
                            }
                            
                            VStack(spacing: 8) {
                                TextField("Enter album title", text: $albumTitle)
                                    .font(.system(size: 16, weight: .light))
                                    .foregroundColor(.white.opacity(0.8))
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .focused($isAlbumTitleFocused)
                                
                                Rectangle()
                                    .fill(isAlbumTitleFocused ? .white.opacity(0.2) : .white.opacity(0.1))
                                    .frame(height: 0.5)
                                    .animation(.easeInOut(duration: 0.2), value: isAlbumTitleFocused)
                            }
                        }
                        
                        // Year Selection
                        VStack(spacing: 16) {
                            HStack {
                                Text("release year")
                                    .font(.system(size: 11, weight: .light, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.4))
                                    .tracking(1.0)
                                
                                Spacer()
                            }
                            
                            Button(action: {
                                HapticFeedbackManager.shared.lightImpact()
                                showingYearPicker = true
                            }) {
                                HStack {
                                    Text("\(albumYear)")
                                        .font(.system(size: 16, weight: .light))
                                        .foregroundColor(.white.opacity(0.8))
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.3))
                                }
                                .padding(.vertical, 8)
                                .overlay(
                                    Rectangle()
                                        .fill(.white.opacity(0.1))
                                        .frame(height: 0.5),
                                    alignment: .bottom
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // Artist Name Info
                        VStack(spacing: 8) {
                            Text("Artist name will be taken from your profile")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.4))
                            
                            Text("→ \(artistName)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    
                    // Secret Test Button
                    if showSecretTestButton {
                        Button("create test album") {
                            createTestAlbum()
                        }
                        .font(.system(size: 11, weight: .light, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                        .tracking(1.0)
                        .padding(.top, 20)
                        .transition(.opacity.combined(with: .scale))
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 24)
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $selectedCoverImage)
        }
        .sheet(isPresented: $showingYearPicker) {
            YearPickerSheet(selectedYear: $albumYear, isPresented: $showingYearPicker)
        }
        .onTapGesture {
            isAlbumTitleFocused = false
        }
    }
    
    private func createTestAlbum() {
        HapticFeedbackManager.shared.heavyImpact()
        
        let testSongs = [
            Song(title: "Neon Lights", artist: artistName, duration: 205, isExplicit: false),
            Song(title: "Digital Heart", artist: artistName, duration: 183, isExplicit: false),
            Song(title: "City Rain", artist: artistName, duration: 227, isExplicit: false),
            Song(title: "Midnight Drive", artist: artistName, duration: 198, isExplicit: false),
            Song(title: "Electric Dreams", artist: artistName, duration: 241, isExplicit: true)
        ]
        
        let testAlbum = Album(
            title: "Midnight Dreams",
            artist: artistName,
            songs: testSongs,
            coverImage: createMinimalTestCoverImage(),
            releaseDate: createDateFromYear(albumYear)
        )
        
        onAlbumCreated(testAlbum)
        onDismiss()
    }
    
    private func createMinimalTestCoverImage() -> UIImage? {
        let size = CGSize(width: 400, height: 400)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                    colors: [
                                        UIColor.black.cgColor,
                                        UIColor(red: 0.1, green: 0.1, blue: 0.2, alpha: 1.0).cgColor
                                    ] as CFArray,
                                    locations: [0.0, 1.0])!
            
            context.cgContext.drawLinearGradient(gradient,
                                               start: CGPoint(x: 0, y: 0),
                                               end: CGPoint(x: size.width, y: size.height),
                                               options: [])
        }
    }
    
    private func createDateFromYear(_ year: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = 1
        components.day = 1
        return Calendar.current.date(from: components) ?? Date()
    }
}

// MARK: - Year Picker Sheet
struct YearPickerSheet: View {
    @Binding var selectedYear: Int
    @Binding var isPresented: Bool
    
    private let yearRange = Array(1950...2030)
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.95).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancel") {
                        HapticFeedbackManager.shared.lightImpact()
                        isPresented = false
                    }
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.6))
                    
                    Spacer()
                    
                    Text("Release Year")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button("Done") {
                        HapticFeedbackManager.shared.success()
                        isPresented = false
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 20)
                
                // Year Picker
                Picker("Year", selection: $selectedYear) {
                    ForEach(yearRange, id: \.self) { year in
                        Text("\(year)")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                            .tag(year)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .preferredColorScheme(.dark)
                .padding(.horizontal, 24)
                
                Spacer()
            }
        }
    }
}

// MARK: - Enhanced Song Selection Step
struct MinimalSongSelectionStep: View {
    let albumTitle: String
    let albumYear: Int
    let artistName: String
    let selectedCoverImage: UIImage?
    @Binding var songs: [AudioFile]
    let onBack: () -> Void
    let onCreate: () -> Void
    let onDismiss: () -> Void
    
    @State private var showingAudioPicker = false
    @State private var isProcessing = false
    @State private var processingStatus = "Processing..."
    @StateObject private var supabaseManager = SupabaseAudioManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("back") {
                    HapticFeedbackManager.shared.lightImpact()
                    onBack()
                }
                .font(.system(size: 11, weight: .light, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1.0)
                
                Spacer()
                
                Text("add songs")
                    .font(.system(size: 11, weight: .light, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                    .tracking(1.0)
                
                Spacer()
                
                Button("create") {
                    HapticFeedbackManager.shared.lightImpact()
                    onCreate()
                }
                .font(.system(size: 11, weight: .light, design: .monospaced))
                .foregroundColor(songs.isEmpty ? .white.opacity(0.3) : .white.opacity(0.8))
                .tracking(1.0)
                .disabled(songs.isEmpty || isProcessing)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 32)
            
            // Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    // Album Preview
                    VStack(spacing: 16) {
                        if let coverImage = selectedCoverImage {
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
                        
                        VStack(spacing: 8) {
                            Text(albumTitle)
                                .font(.system(size: 18, weight: .light))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                            
                            Text("\(albumYear)")
                                .font(.system(size: 11, weight: .light, design: .monospaced))
                                .foregroundColor(.white.opacity(0.4))
                                .tracking(0.5)
                        }
                    }
                    
                    // Songs count
                    Text("\(songs.count) song\(songs.count == 1 ? "" : "s") added")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.top, 20)
                    
                    if songs.isEmpty {
                        // Empty State
                        VStack(spacing: 24) {
                            Image(systemName: "music.note")
                                .font(.system(size: 48, weight: .ultraLight))
                                .foregroundColor(.white.opacity(0.2))
                            
                            VStack(spacing: 12) {
                                Text("No songs yet")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Text("Tap the button below to add your first song")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.5))
                                    .multilineTextAlignment(.center)
                            }
                            
                            MinimalAddButton(action: {
                                HapticFeedbackManager.shared.buttonTap()
                                showingAudioPicker = true
                            })
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else {
                        // Songs List
                        VStack(spacing: 16) {
                            ForEach(songs.indices, id: \.self) { index in
                                MinimalAudioFileRow(
                                    audioFile: $songs[index],
                                    onDelete: {
                                        HapticFeedbackManager.shared.mediumImpact()
                                        removeSong(at: index)
                                    }
                                )
                            }
                            
                            MinimalAddButton(action: {
                                HapticFeedbackManager.shared.buttonTap()
                                showingAudioPicker = true
                            })
                            .padding(.top, 8)
                        }
                    }
                    
                    // Processing Indicator
                    if isProcessing {
                        MinimalProcessingIndicator(
                            status: supabaseManager.currentUploadStatus.isEmpty ? processingStatus : supabaseManager.currentUploadStatus
                        )
                        .padding(.top, 20)
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 24)
            }
        }
        .sheet(isPresented: $showingAudioPicker) {
            AudioFilePicker { url in
                processAudioFile(url)
            }
        }
    }
    
    private func processAudioFile(_ url: URL) {
        HapticFeedbackManager.shared.lightImpact()
        
        Task {
            await MainActor.run {
                isProcessing = true
                processingStatus = "Processing audio file..."
            }
            
            do {
                let asset = AVURLAsset(url: url)
                let duration = try await asset.load(.duration)
                let durationSeconds = CMTimeGetSeconds(duration)
                
                let filename = url.lastPathComponent
                let songId = UUID().uuidString
                
                let audioFile = AudioFile(
                    id: UUID(),
                    songId: songId,
                    url: url,
                    originalFilename: filename,
                    songTitle: String(filename.prefix(while: { $0 != "." })),
                    duration: durationSeconds,
                    isExplicit: false,
                    supabaseFilename: nil
                )
                
                await MainActor.run {
                    songs.append(audioFile)
                    processingStatus = "Uploading to cloud..."
                }
                
                // Upload to Supabase
                let supabaseFilename = try await supabaseManager.uploadAudioFile(
                    url,
                    filename: filename,
                    songId: songId
                )
                
                await MainActor.run {
                    if let index = songs.firstIndex(where: { $0.songId == songId }) {
                        songs[index].supabaseFilename = supabaseFilename
                    }
                    
                    HapticFeedbackManager.shared.success()
                    processingStatus = "Upload complete!"
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.isProcessing = false
                        self.processingStatus = "Processing..."
                    }
                }
                
                try? FileManager.default.removeItem(at: url)
                
            } catch {
                await MainActor.run {
                    HapticFeedbackManager.shared.uploadFailed()
                    processingStatus = "Upload failed: \(error.localizedDescription)"
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        self.isProcessing = false
                        self.processingStatus = "Processing..."
                    }
                }
            }
        }
    }
    
    private func removeSong(at index: Int) {
        let audioFile = songs[index]
        SupabaseAudioManager.shared.cancelUpload(for: audioFile.songId)
        
        _ = withAnimation(.smooth(duration: 0.3)) {
            songs.remove(at: index)
        }
    }
}

// MARK: - Supporting Components
struct MinimalCoverImageSelector: View {
    @Binding var selectedImage: UIImage?
    
    var body: some View {
        VStack(spacing: 16) {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .frame(width: 140, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.white.opacity(0.02))
                    .frame(width: 140, height: 140)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "camera")
                                .font(.system(size: 24, weight: .ultraLight))
                                .foregroundColor(.white.opacity(0.3))
                            
                            Text("add cover")
                                .font(.system(size: 10, weight: .light, design: .monospaced))
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
    }
}

struct MinimalAddButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                
                Text("add song")
                    .font(.system(size: 11, weight: .light, design: .monospaced))
                    .tracking(1.0)
            }
            .foregroundColor(.white.opacity(0.6))
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.white.opacity(0.1), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(MinimalButtonStyle())
    }
}

struct MinimalAudioFileRow: View {
    @Binding var audioFile: AudioFile
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(audioFile.originalFilename)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(formatDuration(audioFile.duration))
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(MinimalButtonStyle())
            }
            
            TextField("Song title", text: $audioFile.songTitle)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.bottom, 8)
                .overlay(
                    Rectangle()
                        .fill(.white.opacity(0.1))
                        .frame(height: 0.5),
                    alignment: .bottom
                )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.white.opacity(0.05), lineWidth: 0.5)
                )
        )
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct MinimalProcessingIndicator: View {
    let status: String
    
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
                .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.6)))
            
            Text(status)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.white.opacity(0.1), lineWidth: 0.5)
                )
        )
    }
}

struct AudioFilePicker: UIViewControllerRepresentable {
    let onAudioSelected: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
            UTType.audio,
            UTType.mp3,
            UTType("public.mp3")!,
            UTType("public.mpeg-4-audio")!,
            UTType.wav,
            UTType.aiff
        ])
        
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: AudioFilePicker
        
        init(_ parent: AudioFilePicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            HapticFeedbackManager.shared.selection()
            parent.onAudioSelected(url)
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            HapticFeedbackManager.shared.lightImpact()
        }
    }
}

#Preview {
    UploadView(
        onAlbumCreated: { _ in },
        onDismiss: { }
    )
}
