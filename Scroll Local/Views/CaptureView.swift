import SwiftUI

struct CaptureView: View {
    @State private var showCamera = false
    
    var body: some View {
        NavigationView {
            VStack {
                if showCamera {
                    CameraView()
                } else {
                    // Show a loading state while preparing camera
                    ProgressView("Preparing camera...")
                        .onAppear {
                            // Small delay to ensure view is ready
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                showCamera = true
                            }
                        }
                }
            }
        }
    }
}

#Preview {
    CaptureView()
}
