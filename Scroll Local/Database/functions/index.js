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

    // Update the video document in Firestore with the thumbnail URL
    const videoId = path.parse(fileName).name;
    const thumbnailUrl = `https://storage.googleapis.com/${bucket.name}/${thumbFilePath}`;
    
    try {
      // Find the video document by matching the video URL
      const videoRef = admin.firestore().collection('videos')
        .where('video_url', '==', `https://storage.googleapis.com/${bucket.name}/${filePath}`)
        .limit(1);
      
      const videoSnapshot = await videoRef.get();
      if (!videoSnapshot.empty) {
        const videoDoc = videoSnapshot.docs[0];
        await videoDoc.ref.update({
          thumbnailUrl: thumbnailUrl
        });
        console.log('Updated video document with thumbnail URL');
      }
    } catch (error) {
      console.error('Error updating video document:', error);
    }

    // Clean up the temporary files.
    fs.unlinkSync(tempVideoPath);
    fs.unlinkSync(tempThumbPath);

    return null;
  }); 