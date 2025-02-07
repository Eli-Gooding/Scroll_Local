import SwiftUI
import MapKit
import CoreLocation
import FirebaseFirestore

class ExploreViewModel: NSObject, ObservableObject {
    @Published var region = MKCoordinateRegion()
    @Published var userLocation: CLLocation?
    @Published var videoAnnotations: [VideoAnnotation] = []
    private let locationManager = CLLocationManager()
    private let db = Firestore.firestore()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        
        // Set default region (will be updated when user location is available)
        region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        )
    }
    
    func startLocationUpdates() {
        locationManager.startUpdatingLocation()
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
        let region = MKCoordinateRegion(
            center: userLocation.coordinate,
            latitudinalMeters: distanceInMeters,
            longitudinalMeters: distanceInMeters
        )
        
        let northEast = CLLocationCoordinate2D(
            latitude: region.center.latitude + (region.span.latitudeDelta / 2),
            longitude: region.center.longitude + (region.span.longitudeDelta / 2)
        )
        
        let southWest = CLLocationCoordinate2D(
            latitude: region.center.latitude - (region.span.latitudeDelta / 2),
            longitude: region.center.longitude - (region.span.longitudeDelta / 2)
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
        userLocation = location
        
        // Update map region to center on user's location with a 25-mile radius
        let distanceInMeters = 40233.6 // 25 miles in meters
        region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: distanceInMeters,
            longitudinalMeters: distanceInMeters
        )
        
        // Fetch nearby videos when location updates
        fetchNearbyVideos()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error)")
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