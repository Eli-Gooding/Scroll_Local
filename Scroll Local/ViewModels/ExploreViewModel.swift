import SwiftUI
import MapKit
import CoreLocation
import FirebaseFirestore

class ExploreViewModel: NSObject, ObservableObject {
    @Published private(set) var region: MKCoordinateRegion
    @Published private(set) var userLocation: CLLocation?
    @Published private(set) var videoAnnotations: [VideoAnnotation] = []
    @Published private(set) var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var locationError: String?
    
    private let locationManager = CLLocationManager()
    private let db = Firestore.firestore()
    private let defaultSpan = MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    private var hasInitializedLocation = false
    
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
        userLocation = location
        locationError = nil
        
        if !hasInitializedLocation {
            hasInitializedLocation = true
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
    
    func fetchNearbyVideos() {
        guard let userLocation = userLocation else { return }
        
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
        
        // Query Firestore for videos within the bounding box
        db.collection("videos")
            .whereField("location", isGreaterThan: GeoPoint(latitude: southWest.latitude, longitude: southWest.longitude))
            .whereField("location", isLessThan: GeoPoint(latitude: northEast.latitude, longitude: northEast.longitude))
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("Error fetching videos: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                self?.videoAnnotations = documents.compactMap { document in
                    guard let location = document.data()["location"] as? GeoPoint,
                          let thumbnailUrl = document.data()["thumbnailUrl"] as? String,
                          let videoUrl = document.data()["videoUrl"] as? String else {
                        return nil
                    }
                    
                    return VideoAnnotation(
                        id: document.documentID,
                        coordinate: CLLocationCoordinate2D(
                            latitude: location.latitude,
                            longitude: location.longitude
                        ),
                        thumbnailUrl: thumbnailUrl,
                        videoUrl: videoUrl
                    )
                }
            }
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
    let thumbnailUrl: String
    let videoUrl: String
    
    init(id: String, coordinate: CLLocationCoordinate2D, thumbnailUrl: String, videoUrl: String) {
        self.id = id
        self.coordinate = coordinate
        self.thumbnailUrl = thumbnailUrl
        self.videoUrl = videoUrl
        super.init()
    }
} 