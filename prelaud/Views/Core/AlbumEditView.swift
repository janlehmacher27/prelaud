//
//  AlbumEditView.swift
//  prelaud
//
//  Created by Jan Lehmacher on 16.07.25.
//

//
//  AlbumEditView.swift
//  prelaud
//
//  Album editing functionality with year, title, and cover image
//

import SwiftUI

struct AlbumEditView: View {
    @Binding var album: Album
    let onSave: (Album) -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    // Editable fields
    @State private var albumTitle: String = ""
    @State private var albumYear: Int = 2024
    @State private var selectedCoverImage: UIImage?
    @State private var hasChanges = false
    
    // UI States
    @State private var showingImagePicker = false
    @State private var showingYearPicker = false
    @State private var showingDeleteAlert = false
    @State private var isSaving = false
    
    @FocusState private var isTitleFocused: Bool
    
    // Year range for picker
    private let yearRange = Array(1950...2030)
    
    var body: some View {
        ZStack {
            // Dark background consistent with app
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerSection
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                
                // Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 40) {
                        // Album preview
                        albumPreviewSection
                        
                        // Edit form
                        editFormSection
                        
                        // Actions
                        actionsSection
                        
                        Spacer(minLength: 60)
                    }
                    .padding(.horizontal, 32)
                }
            }
        }
        .onAppear(perform: loadAlbumData)
        .onTapGesture {
            isTitleFocused = false
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $selectedCoverImage)
        }
        .sheet(isPresented: $showingYearPicker) {
            YearPickerSheet(selectedYear: $albumYear, isPresented: $showingYearPicker)
        }
        .alert("Delete Album", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                HapticFeedbackManager.shared.heavyImpact()
                onDelete()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete \"\(album.title)\"? This action cannot be undone.")
        }
        .onChange(of: albumTitle) { _, _ in checkForChanges() }
        .onChange(of: albumYear) { _, _ in checkForChanges() }
        .onChange(of: selectedCoverImage) { _, _ in checkForChanges() }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            Button("cancel") {
                HapticFeedbackManager.shared.lightImpact()
                if hasChanges {
                    showDiscardAlert()
                } else {
                    dismiss()
                }
            }
            .font(.system(size: 11, weight: .light, design: .monospaced))
            .foregroundColor(.white.opacity(0.4))
            .tracking(1.0)
            
            Spacer()
            
            Text("edit album")
                .font(.system(size: 11, weight: .light, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
                .tracking(1.0)
            
            Spacer()
            
            Button("save") {
                HapticFeedbackManager.shared.lightImpact()
                saveAlbum()
            }
            .font(.system(size: 11, weight: .light, design: .monospaced))
            .foregroundColor(hasChanges ? .white.opacity(0.8) : .white.opacity(0.3))
            .tracking(1.0)
            .disabled(!hasChanges || isSaving)
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Album Preview Section
    private var albumPreviewSection: some View {
        VStack(spacing: 24) {
            // Cover image with edit overlay
            Button(action: {
                HapticFeedbackManager.shared.lightImpact()
                showingImagePicker = true
            }) {
                ZStack {
                    if let coverImage = selectedCoverImage {
                        Image(uiImage: coverImage)
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                            .frame(width: 140, height: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.white.opacity(0.02))
                            .frame(width: 140, height: 140)
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
                    
                    // Edit overlay
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.black.opacity(0.5))
                        .frame(width: 140, height: 140)
                        .overlay(
                            VStack(spacing: 4) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                
                                Text("edit")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        )
                        .opacity(0.8)
                }
            }
            .buttonStyle(MinimalButtonStyle())
            
            // Album info preview
            VStack(spacing: 8) {
                Text(albumTitle.isEmpty ? "Untitled Album" : albumTitle)
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                
                Text("\(albumYear)")
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
    
    // MARK: - Edit Form Section
    private var editFormSection: some View {
        VStack(spacing: 32) {
            // Album title
            VStack(spacing: 16) {
                HStack {
                    Text("title")
                        .font(.system(size: 11, weight: .light, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                        .tracking(1.0)
                    
                    Spacer()
                }
                
                VStack(spacing: 8) {
                    TextField("Album title", text: $albumTitle)
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(.white.opacity(0.8))
                        .textFieldStyle(PlainTextFieldStyle())
                        .focused($isTitleFocused)
                        .onChange(of: albumTitle) { _, _ in
                            HapticFeedbackManager.shared.lightImpact()
                        }
                    
                    Rectangle()
                        .fill(isTitleFocused ? .white.opacity(0.2) : .white.opacity(0.1))
                        .frame(height: 0.5)
                        .animation(.easeInOut(duration: 0.2), value: isTitleFocused)
                }
            }
            
            // Album year
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
        }
    }
    
    // MARK: - Actions Section
    private var actionsSection: some View {
        VStack(spacing: 20) {
            // Delete button
            Button(action: {
                HapticFeedbackManager.shared.lightImpact()
                showingDeleteAlert = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .light))
                    
                    Text("delete album")
                        .font(.system(size: 11, weight: .light, design: .monospaced))
                        .tracking(1.0)
                }
                .foregroundColor(.red.opacity(0.8))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.red.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(.red.opacity(0.1), lineWidth: 0.5)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isSaving)
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadAlbumData() {
        albumTitle = album.title
        albumYear = Calendar.current.component(.year, from: album.releaseDate)
        selectedCoverImage = album.coverImage
    }
    
    private func checkForChanges() {
        let titleChanged = albumTitle != album.title
        let yearChanged = albumYear != Calendar.current.component(.year, from: album.releaseDate)
        let imageChanged = selectedCoverImage != album.coverImage
        
        withAnimation(.easeInOut(duration: 0.2)) {
            hasChanges = titleChanged || yearChanged || imageChanged
        }
    }
    
    private func saveAlbum() {
        guard hasChanges else { return }
        
        isSaving = true
        HapticFeedbackManager.shared.lightImpact()
        
        // Create updated album
        var updatedAlbum = album
        updatedAlbum.title = albumTitle.isEmpty ? "Untitled Album" : albumTitle
        updatedAlbum.releaseDate = createDateFromYear(albumYear)
        updatedAlbum.coverImage = selectedCoverImage
        
        // Update songs with new cover image
        for index in updatedAlbum.songs.indices {
            updatedAlbum.songs[index].coverImage = selectedCoverImage
        }
        
        // Simulate save delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isSaving = false
            hasChanges = false
            
            // Update the original album
            album = updatedAlbum
            
            // Call save callback
            onSave(updatedAlbum)
            
            HapticFeedbackManager.shared.success()
            
            // Auto-dismiss after success
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                dismiss()
            }
        }
    }
    
    private func showDiscardAlert() {
        let alert = UIAlertController(
            title: "Discard Changes?",
            message: "You have unsaved changes. Are you sure you want to discard them?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Discard", style: .destructive) { _ in
            HapticFeedbackManager.shared.mediumImpact()
            dismiss()
        })
        
        // Present alert
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(alert, animated: true)
        }
    }
    
    private func createDateFromYear(_ year: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = 1
        components.day = 1
        return Calendar.current.date(from: components) ?? Date()
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Preview
#Preview {
    AlbumEditView(
        album: .constant(Album(
            title: "Test Album",
            artist: "Test Artist",
            songs: [
                Song(title: "Test Song", artist: "Test Artist", duration: 180)
            ],
            coverImage: nil,
            releaseDate: Date()
        )),
        onSave: { _ in },
        onDelete: { }
    )
}
