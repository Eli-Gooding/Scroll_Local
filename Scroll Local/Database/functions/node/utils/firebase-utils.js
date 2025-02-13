const admin = require('firebase-admin');

exports.findVideoDocument = async (videoUrl) => {
    console.log('Looking for video document with URL:', videoUrl);
    const videosRef = admin.firestore().collection('videos');
    const allVideos = await videosRef.get();
    console.log('Total videos in collection:', allVideos.size);
    
    const doc = allVideos.docs.find(doc => {
        const storedUrl = doc.data().video_url || '';
        const normalizedStoredUrl = storedUrl
            .replace(':443', '')
            .replace(/&token=[^&]+$/, '');
        console.log('Comparing URLs:');
        console.log('  Stored (normalized):', normalizedStoredUrl);
        console.log('  Looking for:', videoUrl);
        return normalizedStoredUrl === videoUrl;
    });
    
    if (doc) {
        console.log('Found matching document:', doc.id);
    } else {
        console.log('No matching document found');
    }
    return doc;
};

exports.getStorageUrl = (bucket, filePath) => {
    return `https://firebasestorage.googleapis.com/v0/b/${bucket}/o/${encodeURIComponent(filePath)}?alt=media`;
}; 