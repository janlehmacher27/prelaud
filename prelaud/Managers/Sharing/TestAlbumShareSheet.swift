//
//  TestAlbumShareSheet.swift
//  prelaud
//
//  Created by Jan Lehmacher on 16.07.25.
//


//
//  MINIMAL SHARE SHEET TEST
//  Teste diese absolute Minimal-Version zuerst
//

import SwiftUI

struct TestAlbumShareSheet: View {
    let album: Album
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.red.ignoresSafeArea() // ROT zum Testen
            
            VStack(spacing: 20) {
                Text("SHARE TEST")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                
                Text("Album: \(album.title)")
                    .foregroundColor(.white)
                
                Text("Artist: \(album.artist)")
                    .foregroundColor(.white)
                
                Button("Close") {
                    dismiss()
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(8)
            }
        }
    }
}

// VERWENDE DAS IN DEINER AlbumsView STATT AlbumShareSheet:
// .sheet(isPresented: $showingShareSheet) {
//     if let album = albumToShare {
//         TestAlbumShareSheet(album: album)
//     }
// }