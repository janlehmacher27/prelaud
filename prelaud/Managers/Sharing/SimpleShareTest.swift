//
//  SimpleShareTest.swift
//  prelaud
//
//  Created by Jan Lehmacher on 15.07.25.
//


//
//  Simple Share Sheet Test
//  Teste das Share Sheet isoliert
//

import SwiftUI

struct SimpleShareTest: View {
    @State private var showingShareSheet = false
    
    // Test Album
    private let testAlbum = Album(
        title: "Test Album",
        artist: "Test Artist", 
        songs: [
            Song(title: "Test Song", artist: "Test Artist", duration: 180)
        ],
        coverImage: nil,
        releaseDate: Date()
    )
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 40) {
                Text("Share Sheet Test")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                
                Button("Show Share Sheet") {
                    showingShareSheet = true
                }
                .font(.title2)
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            AlbumShareSheet(album: testAlbum)
        }
    }
}

#Preview {
    SimpleShareTest()
}