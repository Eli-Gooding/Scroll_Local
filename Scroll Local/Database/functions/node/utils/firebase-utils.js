const admin = require('firebase-admin');

exports.findVideoDocument = async (videoUrl) => {
    const videosRef = admin.firestore().collection('videos');
    const allVideos = await videosRef.get();
    
    return allVideos.docs.find(doc => {
        const storedUrl = doc.data().video_url || '';
        const normalizedStoredUrl = storedUrl
            .replace(':443', '')
            .replace(/&token=[^&]+$/, '');
        return normalizedStoredUrl === videoUrl;
    });
};

exports.getStorageUrl = (bucket, filePath) => {
    return `https://firebasestorage.googleapis.com/v0/b/${bucket}/o/${encodeURIComponent(filePath)}?alt=media`;
}; 