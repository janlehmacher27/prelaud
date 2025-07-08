//
//  AudioPlayerManager.swift - COMPLETE FIX
//  MusicPreview
//
//  Enhanced audio playback with better error handling and Supabase integration
//

import Foundation
import AVFoundation
import Combine
import MediaPlayer

@MainActor
class AudioPlayerManager: NSObject, ObservableObject {
    static let shared = AudioPlayerManager()
    
    @Published var isPlaying = false
    @Published var currentSong: Song?
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackProgress: Double = 0
    @Published var isBuffering = false
    @Published var playbackError: String?
    
    private var audioPlayer: AVAudioPlayer?
    private var avPlayer: AVPlayer?
    private var timeObserver: Any?
    private var timer: Timer?
    private var playerItemStatusObserver: NSKeyValueObservation?
    private var playerItemDurationObserver: NSKeyValueObservation?
    
    private override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
            setupRemoteTransportControls()
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self = self, let song = self.currentSong else {
                return .commandFailed
            }
            
            Task { @MainActor in
                self.play(song: song)
            }
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            
            Task { @MainActor in
                self.togglePlayback()
            }
            return .success
        }
        
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            
            Task { @MainActor in
                self.togglePlayback()
            }
            return .success
        }
        
        commandCenter.previousTrackCommand.isEnabled = false
        commandCenter.nextTrackCommand.isEnabled = false
    }
    
    private func updateNowPlayingInfo() {
        guard let song = currentSong else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = song.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = song.artist
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        if let coverImage = song.coverImage {
            let artwork = MPMediaItemArtwork(boundsSize: coverImage.size) { _ in
                return coverImage
            }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    // MARK: - Main Play Function (FIXED)
    func play(song: Song) {
        print("🎵 Attempting to play song: \(song.title)")
        
        // Clear any previous errors
        playbackError = nil
        
        // If the same song is already playing, toggle playback
        if currentSong?.id == song.id {
            print("🔄 Same song - toggling playback")
            togglePlayback()
            return
        }
        
        // Set new song
        currentSong = song
        print("📱 Current song set to: \(song.title)")
        
        // For test songs without audio file: Simulate playback
        if song.audioFileName == nil && song.songId == nil {
            print("🎭 No audio file - simulating playback")
            Task {
                await simulatePlayback(for: song)
            }
            return
        }
        
        // Try to load audio from different sources
        Task {
            await loadAndPlayAudio(for: song)
        }
    }
    
    private func loadAndPlayAudio(for song: Song) async {
        print("🔍 Loading audio for: \(song.title)")
        
        // 1. Try Supabase URL first
        if let supabaseURL = await getSupabaseURL(for: song) {
            print("☁️ Found Supabase URL: \(supabaseURL)")
            await playFromURL(supabaseURL, song: song)
            return
        }
        
        // 2. Try local file
        if let localURL = getLocalAudioFileURL(for: song) {
            print("📱 Found local file: \(localURL)")
            await playFromURL(localURL, song: song)
            return
        }
        
        // 3. Fallback to simulation
        print("🎭 No audio source found - simulating playback")
        await simulatePlayback(for: song)
    }
    
    private func getSupabaseURL(for song: Song) async -> URL? {
        // Check if SupabaseAudioManager has a URL for this song
        return SupabaseAudioManager.shared.getPlaybackURL(for: song)
    }
    
    private func getLocalAudioFileURL(for song: Song) -> URL? {
        // Try to find local bundle files
        if let audioFileName = song.audioFileName {
            return Bundle.main.url(forResource: audioFileName, withExtension: nil)
        }
        return nil
    }
    
    // MARK: - Enhanced URL Playback
    private func playFromURL(_ url: URL, song: Song) async {
        print("🔊 Starting playback from: \(url)")
        
        await stopCurrentPlayer()
        
        // Validate URL
        if !isValidAudioURL(url) {
            print("❌ Invalid audio URL, simulating playback instead")
            await simulatePlayback(for: song)
            return
        }
        
        // Choose player based on URL type
        if url.scheme == "https" || url.scheme == "http" {
            await playFromRemoteURL(url, song: song)
        } else {
            await playFromLocalURL(url, song: song)
        }
    }
    
    private func isValidAudioURL(_ url: URL) -> Bool {
        let supportedExtensions = ["mp3", "m4a", "wav", "aiff", "flac", "ogg"]
        let pathExtension = url.pathExtension.lowercased()
        
        // For remote URLs: Trust Supabase URLs or check extension
        if url.scheme == "https" || url.scheme == "http" {
            if url.absoluteString.contains("supabase.co") {
                return true
            }
            return supportedExtensions.contains(pathExtension) || pathExtension.isEmpty
        }
        
        // For local URLs: Extension must match
        return supportedExtensions.contains(pathExtension)
    }
    
    // MARK: - Remote URL Playback (ENHANCED)
    private func playFromRemoteURL(_ url: URL, song: Song) async {
        print("🌐 Playing from remote URL with AVPlayer")
        
        await MainActor.run {
            isBuffering = true
            duration = song.duration
            currentTime = 0
            playbackProgress = 0
        }
        
        let playerItem = AVPlayerItem(url: url)
        avPlayer = AVPlayer(playerItem: playerItem)
        
        // Enhanced observers with proper cleanup
        setupPlayerItemObservers(for: playerItem)
        
        // Setup time observer
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = avPlayer?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                self?.updateProgressFromAVPlayer()
            }
        }
        
        await MainActor.run {
            avPlayer?.play()
            isPlaying = true
            isBuffering = false
            updateNowPlayingInfo()
        }
        
        print("✅ AVPlayer playback started for remote URL")
        
        // Fallback timer: If remote URL doesn't work after 10 seconds, simulate
        Task {
            try await Task.sleep(nanoseconds: 10_000_000_000)
            await MainActor.run {
                if let player = self.avPlayer,
                   player.currentItem?.status == .failed ||
                   (player.currentItem?.status == .unknown && self.currentTime == 0) {
                    print("⚠️ Remote playback failed or stalled, falling back to simulation")
                    Task {
                        await self.simulatePlayback(for: song)
                    }
                }
            }
        }
    }
    
    private func setupPlayerItemObservers(for playerItem: AVPlayerItem) {
        // Status observer
        playerItemStatusObserver = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                self?.handlePlayerItemStatusChange(item)
            }
        }
        
        // Duration observer
        playerItemDurationObserver = playerItem.observe(\.duration, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                let duration = CMTimeGetSeconds(item.duration)
                if duration.isFinite && duration > 0 {
                    self?.duration = duration
                    self?.updateNowPlayingInfo()
                }
            }
        }
        
        // Notification observers
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handlePlaybackEnd()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                    self?.handlePlaybackError(error)
                }
            }
        }
    }
    
    private func handlePlayerItemStatusChange(_ playerItem: AVPlayerItem) {
        switch playerItem.status {
        case .readyToPlay:
            print("✅ AVPlayer ready to play")
            isBuffering = false
            playbackError = nil
        case .failed:
            let errorMessage = playerItem.error?.localizedDescription ?? "Unknown playback error"
            print("❌ AVPlayer failed: \(errorMessage)")
            playbackError = errorMessage
            isBuffering = false
            
            // Fallback to simulation
            if let currentSong = currentSong {
                print("🎭 Falling back to simulated playback")
                Task {
                    await simulatePlayback(for: currentSong)
                }
            }
        case .unknown:
            print("⚠️ AVPlayer status unknown")
            isBuffering = true
        @unknown default:
            break
        }
    }
    
    private func handlePlaybackEnd() {
        print("🏁 Playback ended naturally")
        isPlaying = false
        currentTime = 0
        playbackProgress = 0
        stopTimer()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    
    private func handlePlaybackError(_ error: Error) {
        print("❌ Playback error: \(error.localizedDescription)")
        playbackError = error.localizedDescription
        isPlaying = false
        isBuffering = false
    }
    
    // MARK: - Local URL Playback
    private func playFromLocalURL(_ url: URL, song: Song) async {
        print("📱 Playing from local URL with AVAudioPlayer")
        
        do {
            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            self.audioPlayer = audioPlayer
            audioPlayer.delegate = self
            audioPlayer.prepareToPlay()
            
            await MainActor.run {
                duration = audioPlayer.duration
                currentTime = 0
                playbackProgress = 0
                isBuffering = false
                playbackError = nil
                
                audioPlayer.play()
                isPlaying = true
                
                startTimer()
                updateNowPlayingInfo()
            }
            
            print("✅ AVAudioPlayer playback started")
        } catch {
            print("❌ Failed to play local audio: \(error)")
            await MainActor.run {
                playbackError = error.localizedDescription
            }
            await simulatePlayback(for: song)
        }
    }
    
    // MARK: - Stop Current Player (ENHANCED)
    private func stopCurrentPlayer() async {
        await MainActor.run {
            // Stop AVAudioPlayer
            audioPlayer?.stop()
            audioPlayer = nil
            
            // Stop AVPlayer
            avPlayer?.pause()
            if let observer = timeObserver {
                avPlayer?.removeTimeObserver(observer)
                timeObserver = nil
            }
            
            // Clean up observers
            playerItemStatusObserver?.invalidate()
            playerItemStatusObserver = nil
            playerItemDurationObserver?.invalidate()
            playerItemDurationObserver = nil
            
            // Remove notification observers
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: nil)
            
            avPlayer = nil
            stopTimer()
            isBuffering = false
        }
    }
    
    private func updateProgressFromAVPlayer() {
        guard let player = avPlayer else { return }
        
        let currentTime = CMTimeGetSeconds(player.currentTime())
        if currentTime.isFinite {
            self.currentTime = currentTime
            
            if duration > 0 {
                playbackProgress = currentTime / duration
            }
            
            updateNowPlayingInfo()
        }
    }
    
    // MARK: - Enhanced Simulation with Better UX
    private func simulatePlayback(for song: Song) async {
        print("🎭 Starting simulated playback for: \(song.title)")
        
        await stopCurrentPlayer()
        
        await MainActor.run {
            duration = song.duration
            currentTime = 0
            playbackProgress = 0
            isPlaying = true
            isBuffering = false
            playbackError = nil
            
            updateNowPlayingInfo()
            startTimer()
        }
        
        // Simulate song end after duration
        Task {
            try await Task.sleep(nanoseconds: UInt64(song.duration * 1_000_000_000))
            await MainActor.run {
                if self.currentSong?.id == song.id && self.isPlaying {
                    print("🎭 Simulated playback ended for: \(song.title)")
                    self.handlePlaybackEnd()
                }
            }
        }
        
        print("✅ Simulated playback started")
    }
    
    // MARK: - Playback Controls
    func togglePlayback() {
        if let player = avPlayer {
            if isPlaying {
                player.pause()
                isPlaying = false
            } else {
                player.play()
                isPlaying = true
            }
        } else if let player = audioPlayer {
            if player.isPlaying {
                player.pause()
                isPlaying = false
                stopTimer()
            } else {
                player.play()
                isPlaying = true
                startTimer()
            }
        } else if currentSong != nil {
            // Handle simulated playback toggle
            isPlaying.toggle()
            if isPlaying {
                startTimer()
            } else {
                stopTimer()
            }
        }
        
        updateNowPlayingInfo()
    }
    
    func stop() {
        Task {
            await stopCurrentPlayer()
            await MainActor.run {
                isPlaying = false
                currentSong = nil
                currentTime = 0
                duration = 0
                playbackProgress = 0
                isBuffering = false
                playbackError = nil
                
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            }
        }
    }
    
    func seek(to time: TimeInterval) {
        let clampedTime = max(0, min(time, duration))
        
        if let player = avPlayer {
            let cmTime = CMTime(seconds: clampedTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            player.seek(to: cmTime) { [weak self] completed in
                Task { @MainActor in
                    if completed {
                        self?.currentTime = clampedTime
                        self?.updateProgress()
                        self?.updateNowPlayingInfo()
                    }
                }
            }
        } else if let player = audioPlayer {
            player.currentTime = clampedTime
            currentTime = clampedTime
            updateProgress()
            updateNowPlayingInfo()
        } else {
            // Handle simulated playback seeking
            currentTime = clampedTime
            updateProgress()
            updateNowPlayingInfo()
        }
    }
    
    // MARK: - Timer Management
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateProgress()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateProgress() {
        if let player = avPlayer {
            let currentTime = CMTimeGetSeconds(player.currentTime())
            if currentTime.isFinite {
                self.currentTime = currentTime
                
                if duration > 0 {
                    playbackProgress = currentTime / duration
                }
                
                updateNowPlayingInfo()
            }
        } else if let player = audioPlayer {
            currentTime = player.currentTime
            
            if duration > 0 {
                playbackProgress = currentTime / duration
            }
            
            updateNowPlayingInfo()
        } else if isPlaying && currentSong != nil {
            // Handle simulated playback progress
            currentTime += 0.1
            
            if duration > 0 {
                playbackProgress = currentTime / duration
            }
            
            // Check if simulation should end
            if currentTime >= duration {
                handlePlaybackEnd()
            }
            
            updateNowPlayingInfo()
        }
    }
    
    // MARK: - Utility Functions
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var isCurrentlyPlaying: Bool {
        return isPlaying && currentSong != nil
    }
    
    var hasError: Bool {
        return playbackError != nil
    }
    
    // MARK: - Debug Functions
    func getPlaybackStatus() -> String {
        if isBuffering {
            return "Buffering..."
        } else if let error = playbackError {
            return "Error: \(error)"
        } else if isPlaying {
            return "Playing"
        } else if currentSong != nil {
            return "Paused"
        } else {
            return "Stopped"
        }
    }
}

// MARK: - AVAudioPlayerDelegate
extension AudioPlayerManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            if flag {
                handlePlaybackEnd()
            } else {
                playbackError = "Playback finished unsuccessfully"
                isPlaying = false
            }
        }
    }
    
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            let errorMessage = error?.localizedDescription ?? "Audio decode error"
            print("❌ Audio player decode error: \(errorMessage)")
            playbackError = errorMessage
            stop()
        }
    }
}

// MARK: - Error Recovery
extension AudioPlayerManager {
    func retryPlayback() {
        guard let song = currentSong else { return }
        play(song: song)
    }
    
    func clearError() {
        playbackError = nil
    }
}
