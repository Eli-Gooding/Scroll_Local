import cv2
import os
from openai import OpenAI
from dotenv import load_dotenv
import numpy as np
from PIL import Image
import io
import base64
import argparse

# Load environment variables
load_dotenv()

class VideoDescriber:
    def __init__(self):
        # Initialize OpenAI client with API key from environment variables
        self.client = OpenAI(api_key=os.getenv('OPENAI_API_KEY'))
        
    def extract_frames(self, video_path):
        """Extract three evenly spaced frames from the video."""
        cap = cv2.VideoCapture(video_path)
        
        # Get video properties
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        if total_frames < 3:
            raise ValueError("Video must have at least 3 frames")
            
        # Calculate frame indices to extract
        frame_indices = [
            int(total_frames * 0.25),  # First quarter
            int(total_frames * 0.5),   # Middle
            int(total_frames * 0.75)   # Third quarter
        ]
        
        frames = []
        for idx in frame_indices:
            cap.set(cv2.CAP_PROP_POS_FRAMES, idx)
            ret, frame = cap.read()
            if ret:
                # Convert BGR to RGB
                frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                # Resize to 512x512
                frame_resized = cv2.resize(frame_rgb, (512, 512))
                frames.append(frame_resized)
                
        cap.release()
        return frames
    
    def frames_to_base64(self, frames):
        """Convert frames to base64 strings."""
        base64_images = []
        for frame in frames:
            # Convert numpy array to PIL Image
            pil_image = Image.fromarray(frame)
            # Create a bytes buffer
            buffer = io.BytesIO()
            # Save as JPEG to buffer
            pil_image.save(buffer, format="JPEG")
            # Get the bytes from buffer and encode to base64
            img_str = base64.b64encode(buffer.getvalue()).decode('utf-8')
            base64_images.append(img_str)
        return base64_images
    
    def get_video_description(self, video_path):
        """Process video and get description from OpenAI."""
        try:
            # Extract frames
            frames = self.extract_frames(video_path)
            base64_frames = self.frames_to_base64(frames)
            
            # Prepare messages for OpenAI
            messages = [
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": "These are three frames from a video in chronological order. Please describe what is happening in the video based on these frames."
                        },
                        *[{
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:image/jpeg;base64,{base64_frame}"
                            }
                        } for base64_frame in base64_frames]
                    ]
                }
            ]
            
            # Get response from OpenAI
            response = self.client.chat.completions.create(
                model="gpt-4o-mini",
                messages=messages,
                max_tokens=300
            )
            
            return response.choices[0].message.content
            
        except Exception as e:
            return f"Error processing video: {str(e)}"

def main():
    # Set up argument parser
    parser = argparse.ArgumentParser(description='Generate description for a video using OpenAI Vision API')
    parser.add_argument('video_path', type=str, help='Path to the video file')
    args = parser.parse_args()

    # Verify the video file exists
    if not os.path.exists(args.video_path):
        print(f"Error: Video file not found at {args.video_path}")
        return

    describer = VideoDescriber()
    description = describer.get_video_description(args.video_path)
    print("\nVideo Description:")
    print("-----------------")
    print(description)

if __name__ == "__main__":
    main()
