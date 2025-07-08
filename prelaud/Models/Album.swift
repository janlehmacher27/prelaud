//
//  Album.swift - ERWEITERT FÜR SHARING (FIXED)
//  MusicPreview
//
//  Created by Jan on 08.07.25.
//

import Foundation
import UIKit

struct Album {
    let id = UUID()
    var title: String
    var artist: String
    var songs: [Song]
    var coverImage: UIImage?
    var releaseDate: Date
    
    // ✅ NEUE SHARING PROPERTIES
    var ownerId: String?
    var ownerUsername: String?
    var shareId: String?
    var sharedAt: Date?
    var sharePermissions: SharePermissions?
    
    // ✅ COMPUTED PROPERTY (FIXED für Swift 6)
    var isShared: Bool {
        // Verwende nur die ownerId ohne UserProfileManager-Zugriff
        guard let ownerId = ownerId else { return false }
        return !ownerId.isEmpty
    }
    
    // ✅ HELPER FUNCTION für expliziten Check
    @MainActor
    func isSharedWithCurrentUser() -> Bool {
        guard let ownerId = ownerId else { return false }
        guard let currentUserId = UserProfileManager.shared.userProfile?.id.uuidString else { return false }
        return ownerId != currentUserId
    }
}
