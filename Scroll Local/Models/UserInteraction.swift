//
//  UserInteraction.swift
//  Scroll_Local
//
//  Created by Eli Gooding on 2/5/25.
//

import Foundation
import FirebaseFirestore

struct VideoSave: Identifiable {
    let id: String
    let userId: String
    let videoId: String
    let createdAt: Date
    
    init?(id: String, data: [String: Any]) {
        self.id = id
        guard let userId = data["userId"] as? String,
              let videoId = data["videoId"] as? String,
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() else {
            return nil
        }
        
        self.userId = userId
        self.videoId = videoId
        self.createdAt = createdAt
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "userId": userId,
            "videoId": videoId,
            "createdAt": FieldValue.serverTimestamp()
        ]
    }
    
    // MARK: - Firebase Operations
    static func toggleSave(userId: String, videoId: String) async throws -> Bool {
        let db = Firestore.firestore()
        let savesRef = db.collection("videoSaves")
        let videoRef = db.collection("videos").document(videoId)
        
        // Check if save exists
        let snapshot = try await savesRef
            .whereField("userId", isEqualTo: userId)
            .whereField("videoId", isEqualTo: videoId)
            .getDocuments()
        
        let batch = db.batch()
        
        if let existingDoc = snapshot.documents.first {
            // Remove save
            batch.deleteDocument(existingDoc.reference)
            batch.updateData([
                "saveCount": FieldValue.increment(Int64(-1))
            ], forDocument: videoRef)
            
            try await batch.commit()
            return false // Indicates video is now unsaved
        } else {
            // Add save
            let data: [String: Any] = [
                "userId": userId,
                "videoId": videoId,
                "createdAt": FieldValue.serverTimestamp()
            ]
            let newSaveRef = savesRef.document()
            
            batch.setData(data, forDocument: newSaveRef)
            batch.updateData([
                "saveCount": FieldValue.increment(Int64(1))
            ], forDocument: videoRef)
            
            try await batch.commit()
            return true // Indicates video is now saved
        }
    }
}

struct VideoRating: Identifiable {
    let id: String
    let userId: String
    let videoId: String
    let isHelpful: Bool
    let createdAt: Date
    let updatedAt: Date
    
    init?(id: String, data: [String: Any]) {
        self.id = id
        guard let userId = data["userId"] as? String,
              let videoId = data["videoId"] as? String,
              let isHelpful = data["isHelpful"] as? Bool,
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
              let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() else {
            return nil
        }
        
        self.userId = userId
        self.videoId = videoId
        self.isHelpful = isHelpful
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "userId": userId,
            "videoId": videoId,
            "isHelpful": isHelpful,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }
    
    // MARK: - Firebase Operations
    static func updateRating(userId: String, videoId: String, isHelpful: Bool) async throws {
        let db = Firestore.firestore()
        let ratingsRef = db.collection("videoRatings")
        let videoRef = db.collection("videos").document(videoId)
        
        // Check if rating exists
        let snapshot = try await ratingsRef
            .whereField("userId", isEqualTo: userId)
            .whereField("videoId", isEqualTo: videoId)
            .getDocuments()
        
        let batch = db.batch()
        
        if let existingDoc = snapshot.documents.first {
            let existingRating = VideoRating(id: existingDoc.documentID, data: existingDoc.data())
            if let existingRating = existingRating, existingRating.isHelpful != isHelpful {
                // Update existing rating
                batch.updateData([
                    "isHelpful": isHelpful,
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: existingDoc.reference)
                
                // Update video counts
                let updates: [String: Any] = [
                    "helpfulCount": FieldValue.increment(Int64(existingRating.isHelpful ? -1 : 0)),
                    "notHelpfulCount": FieldValue.increment(Int64(!existingRating.isHelpful ? -1 : 0)),
                    "helpfulCount": FieldValue.increment(Int64(isHelpful ? 1 : 0)),
                    "notHelpfulCount": FieldValue.increment(Int64(!isHelpful ? 1 : 0))
                ]
                batch.updateData(updates, forDocument: videoRef)
            }
        } else {
            // Add new rating
            let data: [String: Any] = [
                "userId": userId,
                "videoId": videoId,
                "isHelpful": isHelpful,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ]
            let newRatingRef = ratingsRef.document()
            
            batch.setData(data, forDocument: newRatingRef)
            batch.updateData([
                isHelpful ? "helpfulCount" : "notHelpfulCount": FieldValue.increment(Int64(1))
            ], forDocument: videoRef)
        }
        
        try await batch.commit()
    }
} 