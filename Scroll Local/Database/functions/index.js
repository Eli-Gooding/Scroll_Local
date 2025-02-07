const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { spawn } = require('child-process-promise');
const os = require('os');
const path = require('path');
const fs = require('fs');
const ffmpegPath = require('ffmpeg-static');

admin.initializeApp();

exports.generateThumbnail = functions
  .runWith({
    memory: '1GB',
    timeoutSeconds: 300
  })
  .storage
  .object()
  .onFinalize(async (object) => {
    const filePath = object.name;
    const contentType = object.contentType;
    const bucket = admin.storage().bucket(object.bucket);

    // Exit if this file is not a video.
    if (!contentType || !contentType.startsWith('video/')) {
      console.log('Uploaded file is not a video.');
      return null;
    }

    // Avoid processing a file that is already a thumbnail.
    if (filePath.includes('thumb_')) {
      console.log('File is already a thumbnail.');
      return null;
    }

    const fileName = path.basename(filePath);
    const tempVideoPath = path.join(os.tmpdir(), fileName);

    // Download the video from the bucket.
    await bucket.file(filePath).download({
      destination: tempVideoPath,
    });
    console.log('Video downloaded locally to:', tempVideoPath);

    // Define a temporary path for the thumbnail image.
    const thumbFileName = `thumb_${path.parse(fileName).name}.png`;
    const tempThumbPath = path.join(os.tmpdir(), thumbFileName);

    // Generate a thumbnail from the video using ffmpeg (capture 1 second into the video).
    console.log('Generating thumbnail...');
    try {
      await spawn(ffmpegPath, [
        '-i', tempVideoPath,
        '-ss', '00:00:01.000',
        '-vframes', '1',
        tempThumbPath,
      ]);
      console.log('Thumbnail generated at:', tempThumbPath);
    } catch (error) {
      console.error('Error generating thumbnail:', error);
      return null;
    }

    // Define the destination path for the thumbnail in the bucket.
    const thumbFilePath = path.join(path.dirname(filePath), thumbFileName);

    // Upload the thumbnail to the bucket.
    await bucket.upload(tempThumbPath, {
      destination: thumbFilePath,
      metadata: { contentType: 'image/png' },
    });
    console.log('Thumbnail uploaded to:', thumbFilePath);

    // Get the video URL that's stored in Firestore
    const videoUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(filePath)}?alt=media`;
    const thumbnailUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(thumbFilePath)}?alt=media`;
    
    console.log('Looking for video with URL:', videoUrl);
    console.log('Generated thumbnail URL:', thumbnailUrl);
    
    try {
      // Find the video document by matching the video URL (ignoring token and port)
      const videosRef = admin.firestore().collection('videos');
      const allVideos = await videosRef.get();
      
      // Find the video document by matching the URL pattern
      const videoDoc = allVideos.docs.find(doc => {
        const storedUrl = doc.data().video_url || '';
        // Remove the token and port from the stored URL for comparison
        const normalizedStoredUrl = storedUrl
          .replace(':443', '')
          .replace(/&token=[^&]+$/, '');
        
        console.log('Comparing URLs:');
        console.log('Normalized stored URL:', normalizedStoredUrl);
        console.log('Search URL:', videoUrl);
        
        return normalizedStoredUrl === videoUrl;
      });
      
      if (videoDoc) {
        console.log('Found video document:', videoDoc.id);
        console.log('Current video data:', videoDoc.data());
        
        await videoDoc.ref.update({
          thumbnail_url: thumbnailUrl
        });
        console.log('Updated video document with thumbnail URL:', videoDoc.id);
      } else {
        console.log('No matching video document found for URL:', videoUrl);
        console.log('Total videos in collection:', allVideos.size);
        allVideos.forEach(doc => {
          console.log('Video URL in DB:', doc.data().video_url);
        });
      }
    } catch (error) {
      console.error('Error updating video document:', error);
    }

    // Clean up the temporary files.
    fs.unlinkSync(tempVideoPath);
    fs.unlinkSync(tempThumbPath);

    return null;
  }); 