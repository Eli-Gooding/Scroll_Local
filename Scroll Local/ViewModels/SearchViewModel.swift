import Foundation
import Firebase
import FirebaseFirestore
import SwiftUI

@MainActor
class SearchViewModel: ObservableObject {
    private let db = Firestore.firestore()
    @Published var searchText = ""
    @Published var suggestions: [SearchSuggestion] = []
    @Published var searchResults: SearchResults = SearchResults()
    @Published var selectedCategories: Set<VideoCategory> = Set(VideoCategory.allCases)
    @Published var isLoading = false
    @Published var error: Error?
    
    struct SearchResults {
        var videos: [Video] = []
        var tagResults: [TagResult] = []
        var placeResults: [PlaceResult] = []
        
        struct TagResult: Identifiable {
            let id: String
            let tag: String
            let videos: [Video]
        }
        
        struct PlaceResult: Identifiable {
            let id: String
            let location: String
            let videos: [Video]
        }
    }
    
    enum SearchSuggestion: Identifiable, Hashable {
        case title(String)
        case location(String)
        case tag(String)
        
        var id: String {
            switch self {
            case .title(let value): return "title_\(value)"
            case .location(let value): return "location_\(value)"
            case .tag(let value): return "tag_\(value)"
            }
        }
        
        var displayText: String {
            switch self {
            case .title(let value): return value
            case .location(let value): return value
            case .tag(let value): return "#\(value)"
            }
        }
        
        var type: String {
            switch self {
            case .title: return "Title"
            case .location: return "Location"
            case .tag: return "Tag"
            }
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        static func == (lhs: SearchSuggestion, rhs: SearchSuggestion) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    func updateSuggestions() async {
        guard !searchText.isEmpty else {
            suggestions = []
            return
        }
        
        do {
            var newSuggestions: [SearchSuggestion] = []
            let searchTerm = searchText.lowercased()
            
            // Title suggestions - keep both exact and word matches
            let titleExactQuery = db.collection("videos")
                .whereField("title", isGreaterThanOrEqualTo: searchTerm)
                .whereField("title", isLessThanOrEqualTo: searchTerm + "\u{f8ff}")
                .limit(to: 3)
            
            let titleWordQuery = db.collection("videos")
                .whereField("searchableTitle", arrayContains: searchTerm)
                .limit(to: 3)
            
            async let titleExactDocs = titleExactQuery.getDocuments()
            async let titleWordDocs = titleWordQuery.getDocuments()
            
            let (exactSnapshot, wordSnapshot) = try await (titleExactDocs, titleWordDocs)
            
            // Add exact matches first, then word matches
            newSuggestions += exactSnapshot.documents.map { doc in
                .title(doc.data()["title"] as? String ?? "")
            }
            newSuggestions += wordSnapshot.documents.map { doc in
                .title(doc.data()["title"] as? String ?? "")
            }
            
            // Location suggestions - same approach as title
            let locationExactQuery = db.collection("videos")
                .whereField("formatted_location", isGreaterThanOrEqualTo: searchTerm)
                .whereField("formatted_location", isLessThanOrEqualTo: searchTerm + "\u{f8ff}")
                .limit(to: 3)
            
            let locationWordQuery = db.collection("videos")
                .whereField("searchableLocation", arrayContains: searchTerm)
                .limit(to: 3)
            
            async let locationExactDocs = locationExactQuery.getDocuments()
            async let locationWordDocs = locationWordQuery.getDocuments()
            
            let (locationExactSnapshot, locationWordSnapshot) = try await (locationExactDocs, locationWordDocs)
            
            newSuggestions += locationExactSnapshot.documents.map { doc in
                .location(doc.data()["formatted_location"] as? String ?? "")
            }
            newSuggestions += locationWordSnapshot.documents.map { doc in
                .location(doc.data()["formatted_location"] as? String ?? "")
            }
            
            // Tag suggestions - keep as is since it works well
            let tagSnapshot = try await db.collection("videos")
                .whereField("tags", arrayContains: searchTerm)
                .limit(to: 4)
                .getDocuments()
            
            let tags = Set(tagSnapshot.documents.flatMap { doc in
                doc.data()["tags"] as? [String] ?? []
            })
            
            newSuggestions += tags.prefix(3).map { .tag($0) }
            
            // Remove duplicates but maintain order (exact matches first)
            suggestions = Array(NSOrderedSet(array: newSuggestions)) as? [SearchSuggestion] ?? []
        } catch {
            print("Error fetching suggestions: \(error)")
            suggestions = []
        }
    }
    
    func performSearch() async {
        isLoading = true
        error = nil
        suggestions = [] // Clear suggestions when search starts
        
        do {
            var videos: [Video] = []
            var tagResults: [SearchResults.TagResult] = []
            var placeResults: [SearchResults.PlaceResult] = []
            
            let searchTerm = searchText.lowercased()
            
            // Title search (keep as is since it works)
            let titleQuery = db.collection("videos")
                .whereField("title", isGreaterThanOrEqualTo: searchTerm)
                .whereField("title", isLessThanOrEqualTo: searchTerm + "\u{f8ff}")
                .limit(to: 20)
            
            let titleWordQuery = db.collection("videos")
                .whereField("searchableTitle", arrayContains: searchTerm)
                .limit(to: 20)
            
            async let titleDocs = titleQuery.getDocuments()
            async let titleWordDocs = titleWordQuery.getDocuments()
            
            // Location search - fix to match how we do suggestions
            let locationQuery = db.collection("videos")
                .whereField("formatted_location", isGreaterThanOrEqualTo: searchTerm)
                .whereField("formatted_location", isLessThanOrEqualTo: searchTerm + "\u{f8ff}")
                .limit(to: 20)
            
            let locationWordQuery = db.collection("videos")
                .whereField("searchableLocation", arrayContains: searchTerm)
                .limit(to: 20)
            
            async let locationDocs = locationQuery.getDocuments()
            async let locationWordDocs = locationWordQuery.getDocuments()
            
            // Execute all queries concurrently
            let (titleSnapshot, titleWordSnapshot, locationSnapshot, locationWordSnapshot) = 
                try await (titleDocs, titleWordDocs, locationDocs, locationWordDocs)
            
            // Process title results
            let titleVideos = Array(Set((titleSnapshot.documents + titleWordSnapshot.documents)
                .compactMap { try? $0.data(as: Video.self) }))
                .filter { selectedCategories.contains(VideoCategory(rawValue: $0.category) ?? .attractions) }
            videos.append(contentsOf: titleVideos)
            
            // Process location results
            let locationVideos = Array(Set((locationSnapshot.documents + locationWordSnapshot.documents)
                .compactMap { try? $0.data(as: Video.self) }))
                .filter { selectedCategories.contains(VideoCategory(rawValue: $0.category) ?? .attractions) }
            
            if !locationVideos.isEmpty {
                placeResults.append(SearchResults.PlaceResult(
                    id: searchText,
                    location: searchText,
                    videos: locationVideos
                ))
            }
            
            // Tag search (keep as is since it works)
            let tagSnapshot = try await db.collection("videos")
                .whereField("tags", arrayContains: searchText.lowercased())
                .limit(to: 20)
                .getDocuments()
            
            let tagVideos = tagSnapshot.documents
                .compactMap { try? $0.data(as: Video.self) }
                .filter { selectedCategories.contains(VideoCategory(rawValue: $0.category) ?? .attractions) }
            
            if !tagVideos.isEmpty {
                tagResults.append(SearchResults.TagResult(
                    id: searchText,
                    tag: searchText,
                    videos: tagVideos
                ))
            }
            
            // Update results
            searchResults = SearchResults(
                videos: videos,
                tagResults: tagResults,
                placeResults: placeResults
            )
            
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }
    
    // Add relevance scoring function
    private func score(for text: String) -> Double {
        let searchTerms = searchText.lowercased().split(separator: " ")
        let textTerms = text.lowercased().split(separator: " ")
        var score = 0.0
        
        for searchTerm in searchTerms {
            for textTerm in textTerms {
                if textTerm.contains(searchTerm) {
                    // Exact match gets higher score
                    if textTerm == searchTerm {
                        score += 1.0
                    } else {
                        // Partial match gets partial score
                        score += 0.5
                    }
                } else {
                    // Check for similar terms (basic fuzzy matching)
                    let distance = levenshteinDistance(String(searchTerm), String(textTerm))
                    if distance <= 2 { // Allow up to 2 character differences
                        score += 1.0 - (Double(distance) * 0.3)
                    }
                }
            }
        }
        return score
    }
    
    // Add Levenshtein distance for fuzzy matching
    private func levenshteinDistance(_ a: String, _ b: String) -> Int {
        let empty = Array(repeating: 0, count: b.count + 1)
        var last = Array(0...b.count)
        
        for (i, a_i) in a.enumerated() {
            var current = [i + 1] + empty
            for (j, b_j) in b.enumerated() {
                current[j + 1] = a_i == b_j ? last[j] : min(last[j], last[j + 1], current[j]) + 1
            }
            last = current
        }
        return last[b.count]
    }
    
    func toggleCategory(_ category: VideoCategory) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
        
        Task {
            await performSearch()
        }
    }
} 