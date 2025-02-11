#!/usr/bin/env python3
import os
import subprocess
import argparse
from pathlib import Path

def downgrade_video(input_path, output_path):
    """
    Downgrade a video by:
    1. Trimming to 2 seconds
    2. Scaling down to 2x2 pixels
    """
    cmd = [
        'ffmpeg',
        '-i', str(input_path),
        '-t', '2',  # Trim to 2 seconds
        '-vf', 'scale=360:640',  # Scale to mobile-friendly size
        '-b:v', '150k',  # Lower video bitrate
        '-maxrate', '200k',  # Maximum bitrate
        '-bufsize', '200k',  # Buffer size
        '-c:v', 'libx264',  # Use H.264 codec
        '-preset', 'fast',  # Faster encoding
        '-y',  # Overwrite output file if it exists
        str(output_path)
    ]
    
    try:
        subprocess.run(cmd, check=True, capture_output=True)
        print(f"Successfully processed: {input_path}")
    except subprocess.CalledProcessError as e:
        print(f"Error processing {input_path}: {e}")

def main():
    parser = argparse.ArgumentParser(description='Downgrade videos to minimal quality and length')
    parser.add_argument('--input_dir', required=True, help='Directory containing input videos')
    parser.add_argument('--output_dir', help='Directory for output videos (default: input_dir/downgraded)')
    
    args = parser.parse_args()
    input_dir = Path(args.input_dir)
    output_dir = Path(args.output_dir) if args.output_dir else input_dir / 'downgraded'
    
    # Create output directory if it doesn't exist
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Process all video files
    video_extensions = ['.mp4', '.mov', '.avi', '.m4v']
    for video_file in input_dir.iterdir():
        if video_file.suffix.lower() in video_extensions:
            output_path = output_dir / f"{video_file.stem}_downgraded{video_file.suffix}"
            downgrade_video(video_file, output_path)

if __name__ == '__main__':
    main()
