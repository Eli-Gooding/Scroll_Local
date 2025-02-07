import Firebase
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore
import UIKit

class ProfileService {
    static let shared = ProfileService()
    private let storage = Storage.storage()
    private let db = Firestore.firestore()
    private let userService = UserService.shared
    
    private init() {}
    
    func updateProfile(displayName: String?, bio: String?) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        var updateData: [String: Any] = [:]
        if let displayName = displayName {
            updateData["displayName"] = displayName
        }
        if let bio = bio {
            updateData["bio"] = bio
        }
        
        try await db.collection("users").document(uid).updateData(updateData)
        
        // Update local state
        if let displayName = displayName {
            userService.currentUser?.displayName = displayName
        }
        if let bio = bio {
            userService.currentUser?.bio = bio
        }
    }
    
    func uploadProfileImage(_ image: UIImage) async throws -> String {
        guard let uid = Auth.auth().currentUser?.uid,
              let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw NSError(domain: "ProfileService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to prepare image data"])
        }
        
        // Create a storage reference
        let storageRef = storage.reference().child("profile_pictures/\(uid)")
        
        // Upload the image
        _ = try await storageRef.putData(imageData, metadata: nil)
        
        // Get the download URL
        let downloadURL = try await storageRef.downloadURL()
        
        // Update the user's profile in Firestore
        try await db.collection("users").document(uid).updateData([
            "profileImageUrl": downloadURL.absoluteString
        ])
        
        // Update local state
        userService.currentUser?.profileImageUrl = downloadURL.absoluteString
        
        return downloadURL.absoluteString
    }
} 