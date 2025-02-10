import SwiftUI
import MapKit
import CoreLocation
import FirebaseFirestore

// Category colors for heat map
enum VideoCategory: String, CaseIterable {
    case attractions = "Attractions"
    case eats = "Eats"
    case shopping = "Shopping"
    case localTips = "Local Tips"
    
    var color: Color {
        switch self {
        case .attractions: return .blue
        case .eats: return .red
        case .shopping: return .purple
        case .localTips: return .green
        }
    }
}

class ExploreViewModel: NSObject, ObservableObject {
    @Published private(set) var region: MKCoordinateRegion
    @Published private(set) var userLocation: CLLocation?
    @Published private(set) var videoAnnotations: [VideoAnnotation] = []
    @Published private(set) var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var locationError: String?
    @Published var selectedCategories: Set<VideoCategory> = Set(VideoCategory.allCases)
    @Published private(set) var heatMapOverlays: [MKOverlay] = []
    
    private let locationManager = CLLocationManager()
    private let db = Firestore.firestore()
    private let defaultSpan = MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    private var hasInitializedLocation = false
    let circleRadius: CLLocationDistance = 201.168 // 0.125 miles (1/8 mile) in meters
    
    override init() {
        // Initialize with a default region
        self.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        )
        
        super.init()
        
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        // Check current authorization status
        locationAuthorizationStatus = locationManager.authorizationStatus
        
        switch locationAuthorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        case .denied, .restricted:
            locationError = "Please enable location services in Settings to see nearby videos."
        @unknown default:
            break
        }
    }
    
    func startLocationUpdates() {
        locationManager.startUpdatingLocation()
        
        // If we already have a cached location, use it for initial setup
        if !hasInitializedLocation, let location = locationManager.location {
            handleLocationUpdate(location)
        }
    }
    
    private func handleLocationUpdate(_ location: CLLocation) {
        print("📍 Location update received: \(location.coordinate)")
        userLocation = location
        locationError = nil
        
        if !hasInitializedLocation {
            hasInitializedLocation = true
            centerMapOnLocation(location)
            print("🌟 First time initialization - fetching videos")
            fetchNearbyVideos()
        }
    }
    
    private func centerMapOnLocation(_ location: CLLocation) {
        // Update map region to center on the given location with a 25-mile radius
        let distanceInMeters = 40233.6 // 25 miles in meters
        let newRegion = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: distanceInMeters,
            longitudinalMeters: distanceInMeters
        )
        
        updateRegion(newRegion)
    }
    
    func centerMapOnCoordinate(_ coordinate: CLLocationCoordinate2D) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        centerMapOnLocation(location)
    }
    
    func updateRegion(_ newRegion: MKCoordinateRegion) {
        region = newRegion
    }
    
    func centerMapOnUser(_ completion: @escaping (MKCoordinateRegion) -> Void) {
        if let location = userLocation {
            // Update map region to center on the given location with a 25-mile radius
            let distanceInMeters = 40233.6 // 25 miles in meters
            let newRegion = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: distanceInMeters,
                longitudinalMeters: distanceInMeters
            )
            completion(newRegion)
        } else if locationAuthorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if locationAuthorizationStatus == .denied || locationAuthorizationStatus == .restricted {
            locationError = "Please enable location services in Settings to see nearby videos."
        }
    }
    
    func fetchVideo(id: String) async -> Video? {
        do {
            let document = try await db.collection("videos").document(id).getDocument()
            guard let data = document.data() else { return nil }
            return Video(id: id, data: data)
        } catch {
            print("Error fetching video: \(error)")
            return nil
        }
    }
    
    func toggleCategory(_ category: VideoCategory) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
        updateHeatMap()
    }
    
    func fetchNearbyVideos() {
        guard let userLocation = userLocation else {
            print("❌ No user location available")
            return
        }
        
        print("🔍 Fetching videos near: \(userLocation.coordinate)")
        
        // Calculate the bounding box for 25-mile radius
        let distanceInMeters = 40233.6 // 25 miles in meters
        let searchRegion = MKCoordinateRegion(
            center: userLocation.coordinate,
            latitudinalMeters: distanceInMeters,
            longitudinalMeters: distanceInMeters
        )
        
        let northEast = CLLocationCoordinate2D(
            latitude: searchRegion.center.latitude + (searchRegion.span.latitudeDelta / 2),
            longitude: searchRegion.center.longitude + (searchRegion.span.longitudeDelta / 2)
        )
        
        let southWest = CLLocationCoordinate2D(
            latitude: searchRegion.center.latitude - (searchRegion.span.latitudeDelta / 2),
            longitude: searchRegion.center.longitude - (searchRegion.span.longitudeDelta / 2)
        )
        
        print("🗺 Search bounds: NE(\(northEast)), SW(\(southWest))")
        
        // Query Firestore for videos within the bounding box
        let query = db.collection("videos")
            .whereField("location", isGreaterThan: GeoPoint(latitude: southWest.latitude, longitude: southWest.longitude))
            .whereField("location", isLessThan: GeoPoint(latitude: northEast.latitude, longitude: northEast.longitude))
        
        print("🔥 Executing Firestore query: \(query)")
        
        query.getDocuments { [weak self] snapshot, error in
            if let error = error {
                print("❌ Error fetching videos: \(error)")
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("⚠️ No documents found")
                return
            }
            
            print("📱 Found \(documents.count) videos in range")
            
            // Print raw document data for debugging
            for (index, doc) in documents.enumerated() {
                print("📄 Document \(index + 1):")
                print("   ID: \(doc.documentID)")
                print("   Data: \(doc.data())")
            }
            
            self?.videoAnnotations = documents.compactMap { document in
                let data = document.data()
                
                // Extract and verify location
                guard let location = data["location"] as? GeoPoint else {
                    print("❌ Missing or invalid location")
                    return nil
                }
                
                // Extract and verify video URL
                guard let videoUrl = data["video_url"] as? String else {
                    print("❌ Missing or invalid video_url")
                    return nil
                }
                
                // Extract and verify category
                guard let category = data["category"] as? String else {
                    print("❌ Missing or invalid category")
                    return nil
                }
                
                // Optional thumbnail URL
                let thumbnailUrl = data["thumbnail_url"] as? String
                
                print("✅ Successfully parsed video:")
                print("   Location: \(location)")
                print("   Category: \(category)")
                
                return VideoAnnotation(
                    id: document.documentID,
                    coordinate: CLLocationCoordinate2D(
                        latitude: location.latitude,
                        longitude: location.longitude
                    ),
                    thumbnailUrl: thumbnailUrl,
                    videoUrl: videoUrl,
                    category: category
                )
            }
            
            print("🎯 Created \(self?.videoAnnotations.count ?? 0) annotations")
            self?.updateHeatMap()
        }
    }
    
    private func updateHeatMap() {
        // Remove existing overlays
        heatMapOverlays.removeAll()
        
        print("🎨 Starting heat map update")
        print("📊 Current video annotations: \(videoAnnotations.count)")
        
        // Print all annotations for debugging
        for (index, annotation) in videoAnnotations.enumerated() {
            print("🎥 Video \(index + 1):")
            print("   Category: \(annotation.category)")
            print("   Location: \(annotation.coordinate)")
        }
        
        // Group annotations by category
        let annotationsByCategory = Dictionary(grouping: videoAnnotations) { annotation in
            VideoCategory(rawValue: annotation.category) ?? .attractions
        }
        
        print("🎨 Updating heat map with categories: \(selectedCategories)")
        print("📊 Annotations by category: \(annotationsByCategory.mapValues { $0.count })")
        
        // Create overlays only for selected categories
        for category in selectedCategories {
            guard let annotations = annotationsByCategory[category] else {
                print("ℹ️ No annotations for category: \(category)")
                continue
            }
            
            print("🔵 Adding \(annotations.count) circles for category: \(category)")
            
            // Create circles for each annotation
            for annotation in annotations {
                let circle = MKCircle(
                    center: annotation.coordinate,
                    radius: self.circleRadius
                )
                circle.title = category.rawValue
                self.heatMapOverlays.append(circle)
            }
        }
        
        print("✅ Total overlays: \(self.heatMapOverlays.count)")
        objectWillChange.send()
    }
}

extension ExploreViewModel: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        handleLocationUpdate(location)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error)")
        locationError = "Unable to determine your location. Please try again."
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        locationAuthorizationStatus = manager.authorizationStatus
        
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
            locationError = nil
        case .denied, .restricted:
            locationError = "Please enable location services in Settings to see nearby videos."
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }
}

// Custom annotation for videos
class VideoAnnotation: NSObject, MKAnnotation, Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let thumbnailUrl: String?
    let videoUrl: String
    let category: String
    
    init(id: String, coordinate: CLLocationCoordinate2D, thumbnailUrl: String?, videoUrl: String, category: String) {
        self.id = id
        self.coordinate = coordinate
        self.thumbnailUrl = thumbnailUrl
        self.videoUrl = videoUrl
        self.category = category
        super.init()
    }
} 