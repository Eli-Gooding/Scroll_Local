import firebase_admin
from firebase_admin import credentials, storage
import os
from pathlib import Path

def upload_video(bucket, video_path, destination_blob_name):
    blob = bucket.blob(destination_blob_name)
    blob.upload_from_filename(video_path)
    blob.make_public()
    return blob.public_url

def main():
    # Initialize Firebase Admin
    cred = credentials.Certificate('Scroll Local/Database/scroll-local-firebase-adminsdk-fbsvc-27d2f13818.json')
    firebase_admin.initialize_app(cred, {
        'storageBucket': 'scroll-local'
    })

    # Get bucket
    bucket = storage.bucket()
    
    # Directory containing downgraded videos
    videos_dir = Path("Scroll Local/Database/seedVideos/downgraded")
    
    # Upload each video
    for video_file in videos_dir.glob("*_downgraded.*"):
        print(f"Uploading {video_file.name}...")
        
        # Create destination path in Firebase Storage
        destination_blob_name = f"seed_videos/{video_file.name}"
        
        # Upload the video
        public_url = upload_video(bucket, str(video_file), destination_blob_name)
        print(f"Uploaded {video_file.name} to {public_url}")

if __name__ == "__main__":
    main()
