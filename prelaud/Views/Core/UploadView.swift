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
    
    // Year range for picker
    private let yearRange = Array(1950...2030)
    
    var body: some View {
        VStack(spacing: 0) {
            // Minimal Header
            HStack {
                Button("Cancel") {
                    HapticFeedbackManager.shared.buttonTap()
                    onDismiss()
                }
                .font(.system(size: 17))
                .foregroundColor(.white.opacity(0.6))
                
                Spacer()
                
                Button("Next") {
                    HapticFeedbackManager.shared.buttonTap()
                    if albumTitle.isEmpty { albumTitle = "Untitled Album" }
                    onNext()
                }
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.white)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 40) {
                    // Title with secret tap area
                    VStack(spacing: 8) {
                        Text("New Album")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white)
                            .onTapGesture {
                                secretTapCount += 1
                                HapticFeedbackManager.shared.lightImpact()
                                if secretTapCount >= 7 {
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                        showSecretTestButton = true
                                    }
                                }
                            }
                        
                        Text("by \(artistName)")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.top, 40)
                    
                    // Secret Test Button
                    if showSecretTestButton {
                        Button(action: createTestAlbum) {
                            HStack(spacing: 8) {
                                Image(systemName: "flask.fill")
                                    .font(.system(size: 14))
                                Text("Create Test Album")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.white.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(.white.opacity(0.1), lineWidth: 0.5)
                                    )
                            )
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    // Minimal Cover Image Selector
                    MinimalCoverImageSelector(
                        selectedImage: $selectedCoverImage,
                        showingImagePicker: $showingImagePicker
                    )
                    
                    // Enhanced Form Fields
                    VStack(spacing: 32) {
                        // Album Title
                        MinimalTextField(
                            text: $albumTitle,
                            placeholder: "Album title",
                            isActive: isAlbumTitleFocused
                        )
                        .focused($isAlbumTitleFocused)
                        
                        // Release Year Picker
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
                                    
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 12))
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
            
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .light),
                .foregroundColor: UIColor.white.withAlphaComponent(0.8)
            ]
            
            let titleString = NSAttributedString(string: "MIDNIGHT\nDREAMS", attributes: titleAttributes)
            let titleRect = CGRect(x: 40, y: size.height - 120, width: size.width - 80, height: 80)
            titleString.draw(in: titleRect)
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
            // Minimal Header
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                        Text("Back")
                            .font(.system(size: 17))
                    }
                    .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                Button("Create") {
                    HapticFeedbackManager.shared.buttonTap()
                    onCreate()
                }
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(canCreate ? .white : .white.opacity(0.3))
                .disabled(!canCreate || isProcessing)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    // Enhanced Title with Year
                    VStack(spacing: 8) {
                        Text("Add Songs")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("to \(albumTitle) (\(albumYear))")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text("\(songs.count) song\(songs.count == 1 ? "" : "s") added")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.4))
                    }
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
                            status: supabaseManager.currentUploadStatus.isEmpty ? processingStatus : supabaseManager.currentUploadStatus,
                            progress: supabaseManager.uploadProgress
                        )
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 24)
            }
        }
        .sheet(isPresented: $showingAudioPicker) {
            AudioFilePicker { audioFile in
                processAudioFile(audioFile)
            }
        }
    }
    
    private var canCreate: Bool {
        !songs.isEmpty && !isProcessing
    }
    
    private func processAudioFile(_ url: URL) {
        isProcessing = true
        processingStatus = "Analyzing audio file..."
        
        Task {
            do {
                await MainActor.run {
                    processingStatus = "Analyzing audio properties..."
                }
                
                let tempDirectory = FileManager.default.temporaryDirectory
                let tempFileName = "\(UUID().uuidString).\(url.pathExtension)"
                let tempURL = tempDirectory.appendingPathComponent(tempFileName)
                
                let hasAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if hasAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                
                try FileManager.default.copyItem(at: url, to: tempURL)
                
                let asset = AVURLAsset(url: tempURL)
                let duration = try await asset.load(.duration)
                let durationInSeconds = CMTimeGetSeconds(duration)
                
                let filename = url.deletingPathExtension().lastPathComponent
                let fileExtension = url.pathExtension
                let songId = UUID().uuidString
                let uniqueFilename = "\(songId).\(fileExtension)"
                
                await MainActor.run {
                    processingStatus = "Uploading to cloud..."
                }
                
                _ = try await SupabaseAudioManager.shared.uploadAudioFile(
                    tempURL,
                    filename: uniqueFilename,
                    songId: songId
                )
                
                let audioFile = AudioFile(
                    id: UUID(),
                    songId: songId,
                    url: tempURL,
                    originalFilename: filename,
                    songTitle: filename,
                    duration: durationInSeconds,
                    isExplicit: false,
                    supabaseFilename: uniqueFilename
                )
                
                await MainActor.run {
                    HapticFeedbackManager.shared.uploadComplete()
                    songs.append(audioFile)
                    processingStatus = "Upload complete!"
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.isProcessing = false
                        self.processingStatus = "Processing..."
                    }
                }
                
                try? FileManager.default.removeItem(at: tempURL)
                
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

// MARK: - Supporting Components (unchanged)
struct MinimalCoverImageSelector: View {
    @Binding var selectedImage: UIImage?
    @Binding var showingImagePicker: Bool
    
    var body: some View {
        Button(action: {
            HapticFeedbackManager.shared.lightImpact()
            showingImagePicker = true
        }) {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .frame(width: 160, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.1), lineWidth: 0.5)
                    )
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(0.03))
                    .frame(width: 160, height: 160)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .ultraLight))
                                .foregroundColor(.white.opacity(0.4))
                            
                            Text("Add Cover")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.1), lineWidth: 0.5)
                    )
            }
        }
        .buttonStyle(MinimalButtonStyle())
    }
}

struct MinimalTextField: View {
    @Binding var text: String
    let placeholder: String
    let isActive: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(placeholder, text: $text)
                .font(.system(size: 17))
                .foregroundColor(.white)
                .textFieldStyle(PlainTextFieldStyle())
                .onChange(of: text) { _, _ in
                    HapticFeedbackManager.shared.lightImpact()
                }
            
            Rectangle()
                .fill(isActive ? .white : .white.opacity(0.2))
                .frame(height: 0.5)
                .animation(.easeInOut(duration: 0.2), value: isActive)
        }
    }
}

struct MinimalAddButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .medium))
                Text("Add Audio File")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.white.opacity(0.2), lineWidth: 0.5)
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
                Circle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.6))
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(status)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    if progress > 0 {
                        Text("\(Int(progress * 100))% complete")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                Spacer()
            }
            
            if progress > 0 {
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(.white.opacity(0.1))
                        .frame(height: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 1)
                                .fill(.white)
                                .frame(width: geometry.size.width * progress, height: 2)
                                .animation(.smooth(duration: 0.3), value: progress),
                            alignment: .leading
                        )
                }
                .frame(height: 2)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.1), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Audio File Picker
struct AudioFilePicker: UIViewControllerRepresentable {
    let onAudioSelected: (URL) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
            .audio, .mp3, .mpeg4Audio, .wav, .aiff
        ])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
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
}, spacing: 4) {
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
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(.white.opacity(0.1), lineWidth: 0.5)
                        )
                )
                .onChange(of: audioFile.songTitle) { _, _ in
                    HapticFeedbackManager.shared.lightImpact()
                }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.1), lineWidth: 0.5)
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
    let progress: Double
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.1), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(.white, lineWidth: 2)
                        .frame(width: 24, height: 24)
                        .rotationEffect(.degrees(-90))
                        .animation(.smooth(duration: 0.3), value: progress)
                }
                
                VStack(alignment: .leading
