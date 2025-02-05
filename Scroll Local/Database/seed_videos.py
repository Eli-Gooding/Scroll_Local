import firebase_admin
from firebase_admin import credentials, firestore
import os
from datetime import datetime

# Initialize Firebase Admin
cred = credentials.Certificate('scroll-local-firebase-adminsdk-fbsvc-27d2f13818.json')
firebase_admin.initialize_app(cred)

# Get Firestore instance
db = firestore.client()

# Test user details (from LoginView.swift)
TEST_USER_EMAIL = "test@example.com"
TEST_USER_ID = "testuser123"  # We'll use this as a consistent ID

# Video metadata
SEED_VIDEOS = [
    {
        'filename': '12266486_360_640_25fps.mp4',
        'title': 'Local Coffee Shop Discovery',
        'description': 'Found this amazing hidden gem in downtown! Best coffee and pastries in the area. #coffee #local #foodie',
        'location': 'Downtown',
        'tags': ['coffee', 'local', 'foodie'],
        'category': 'Food & Drink'
    },
    {
        'filename': 'PubVid_plane.mp4',
        'title': 'Scenic Flight Over City',
        'description': 'Amazing aerial view of our beautiful city! Check out these landmarks from above. #travel #city #aerial',
        'location': 'City Center',
        'tags': ['travel', 'city', 'aerial'],
        'category': 'Travel'
    },
    {
        'filename': '12464700_1440_2560_30fps.mp4',
        'title': 'Street Festival Highlights',
        'description': 'The annual street festival is back! So much energy and amazing local performances. #festival #community #events',
        'location': 'Main Street',
        'tags': ['festival', 'community', 'events'],
        'category': 'Events'
    }
]

def create_seed_documents():
    # First, create test user document if it doesn't exist
    user_ref = db.collection('users').document(TEST_USER_ID)
    if not user_ref.get().exists:
        user_ref.set({
            'email': TEST_USER_EMAIL,
            'username': 'testuser',
            'created_at': firestore.SERVER_TIMESTAMP,
            'bio': 'Test user for local content creation',
            'location': 'Downtown Area'
        })
        print("Created test user document")

    # Create documents for each video
    for video_data in SEED_VIDEOS:
        try:
            # Create Firestore document for the video
            video_doc = {
                'user_id': TEST_USER_ID,
                'title': video_data['title'],
                'description': video_data['description'],
                'location': video_data['location'],
                'tags': video_data['tags'],
                'category': video_data['category'],
                'filename': video_data['filename'],  # Store the filename for reference
                'created_at': firestore.SERVER_TIMESTAMP,
                'views': 0,
                'helpful_count': 0,
                'not_helpful_count': 0,
                'save_count': 0,
                'comment_count': 0
            }
            
            # Add to videos collection
            doc_ref = db.collection('videos').add(video_doc)
            print(f'Successfully created Firestore document with ID: {doc_ref[1].id} for {video_data["filename"]}')
            
        except Exception as e:
            print(f'Error processing {video_data["filename"]}: {str(e)}')

if __name__ == '__main__':
    create_seed_documents() 