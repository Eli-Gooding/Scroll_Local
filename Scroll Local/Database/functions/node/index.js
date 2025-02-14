const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { spawn } = require('child-process-promise');
const os = require('os');
const path = require('path');
const fs = require('fs');
const ffmpegPath = require('ffmpeg-static');
const { findVideoDocument, getStorageUrl } = require('./utils/firebase-utils');
const { extractFrames, generateThumbnail, getVideoDescription } = require('./services/video-processor');
const { OpenAI } = require("openai");

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
      const videoDoc = await findVideoDocument(videoUrl);
      
      if (videoDoc) {
        console.log('Found video document:', videoDoc.id);
        console.log('Current video data:', videoDoc.data());
        
        await videoDoc.ref.update({
          thumbnail_url: thumbnailUrl
        });
        console.log('Updated video document with thumbnail URL:', videoDoc.id);
      } else {
        console.log('No matching video document found for URL:', videoUrl);
        console.log('Total videos in collection:', await findVideoDocument(videoUrl));
      }
    } catch (error) {
      console.error('Error updating video document:', error);
    }

    // Clean up the temporary files.
    fs.unlinkSync(tempVideoPath);
    fs.unlinkSync(tempThumbPath);

    return null;
  });

// New video description function
exports.generateVideoDescription = functions
    .runWith({
        memory: '1GB',
        timeoutSeconds: 300,
        secrets: ["OPENAI_API_KEY"]
    })
    .storage
    .object()
    .onFinalize(async (object) => {
        if (!object.contentType?.startsWith('video/')) {
            console.log('Not a video file');
            return null;
        }

        const tempVideoPath = path.join(os.tmpdir(), path.basename(object.name));

        try {
            await admin.storage().bucket(object.bucket)
                .file(object.name)
                .download({ destination: tempVideoPath });

            const frames = await extractFrames(tempVideoPath, [0.25, 0.5, 0.75]);
            const videoUrl = getStorageUrl(object.bucket, object.name);
            const videoDoc = await findVideoDocument(videoUrl);
            
            if (videoDoc) {
                const videoData = videoDoc.data();
                const result = await getVideoDescription(frames, {
                    id: videoDoc.id,
                    title: videoData.title,
                    formattedLocation: videoData.formattedLocation
                });

                // Create update object with only defined values
                const updateData = {};
                if (result.description) updateData.ai_description = result.description;
                if (result.embedding) updateData.embedding = result.embedding;
                if (result.embedding_metadata) updateData.embedding_metadata = result.embedding_metadata;

                await videoDoc.ref.update(updateData);
                console.log('Updated video document with AI description and embedding:', videoDoc.id);
            }

            fs.unlinkSync(tempVideoPath);
            return null;
        } catch (error) {
            console.error('Error processing video:', error);
            return null;
        }
    });

// Function to generate search variations using OpenAI
async function generateSearchQueries(query, client) {
    let run;
    try {
        // Create the run first
        run = await client.createRun({
            name: "generate_search_variations",
            run_type: "llm",
            inputs: { query },
            start_time: new Date().toISOString()
        });

        const openai = new OpenAI({
            apiKey: process.env.OPENAI_API_KEY
        });

        const response = await openai.chat.completions.create({
            model: "gpt-4o-mini",
            messages: [{
                role: "system",
                content: "You are a helpful assistant that generates search variations. Return a JSON object with a 'variations' array containing 2-3 alternative search queries."
            }, {
                role: "user",
                content: `Generate 2-3 semantic search variations for: "${query}". Focus on key concepts and different ways to express the same intent.`
            }],
            response_format: { type: "json_object" },
            temperature: 0.7
        });

        // Add error checking and logging
        const content = response.choices[0].message.content;
        console.log('Search variations generated:', JSON.parse(content).variations.length);
        
        const parsed = JSON.parse(content);
        
        if (!parsed.variations || !Array.isArray(parsed.variations)) {
            console.error('Invalid response format from GPT');
            return [query]; // Return original query if variations fail
        }

        // Only try to update run if it was created successfully
        if (run) {
            await client.updateRun(run.id, {
                outputs: { variations: parsed.variations },
                status: "completed"
            });
        }

        return [query, ...parsed.variations];
    } catch (error) {
        console.error('Error generating search variations:', error);
        // Only try to update run if it was created successfully
        if (run) {
            await client.updateRun(run.id, {
                error: error.message,
                status: "failed"
            });
        }
        return [query]; // Return original query instead of throwing
    }
}

// Function to perform vector search in Firestore
async function performVectorSearch(query, location, limit) {
    const openai = new OpenAI({
        apiKey: process.env.OPENAI_API_KEY
    });

    // Generate embedding for the query
    const embeddingResponse = await openai.embeddings.create({
        model: "text-embedding-ada-002",
        input: query
    });
    const queryEmbedding = embeddingResponse.data[0].embedding;

    // Perform vector search in Firestore
    const videosRef = admin.firestore().collection('videos');
    let videoQuery = videosRef.where('embedding', '!=', null);
    
    if (location) {
        videoQuery = videoQuery.where('formattedLocation', '==', location);
    }

    const snapshot = await videoQuery.get();
    console.log(`Found ${snapshot.docs.length} total videos`);
    console.log(`Query conditions: ${location ? `location=${location}` : 'no location filter'}`);

    // Log each document's metadata without embeddings
    snapshot.docs.forEach(doc => {
        const data = doc.data();
        console.log(`Video ${doc.id}:`, {
            title: data.title || 'No title',
            hasEmbedding: !!data.embedding,
            location: data.formattedLocation || 'No location'
        });
    });
    
    // Calculate cosine similarity and sort results
    const results = snapshot.docs
        .map(doc => {
            const data = doc.data();
            if (!data.embedding) {
                console.log(`Video ${doc.id}: No embedding found`);
                return null;
            }
            
            const similarity = calculateCosineSimilarity(queryEmbedding, data.embedding);
            console.log(`Video ${doc.id}: similarity=${similarity.toFixed(4)}`);
            
            // Just return ID and similarity
            return {
                id: doc.id,
                similarity
            };
        })
        .filter(result => result !== null)
        .sort((a, b) => b.similarity - a.similarity)
        .slice(0, limit);

    console.log(`Returning ${results.length} results`);
    return results;
}

// Function to rank results using OpenAI
async function rankResults(results, originalQuery) {
    if (!results || results.length === 0) {
        return [];
    }

    const openai = new OpenAI({
        apiKey: process.env.OPENAI_API_KEY
    });

    try {
        // Format the results for GPT
        const formattedResults = results.map(r => ({
            id: r.id,
            title: r.title || 'Untitled',
            description: r.description || 'No description',
            location: r.formatted_location || 'No location'
        }));

        const response = await openai.chat.completions.create({
            model: "gpt-4o-mini",
            messages: [{
                role: "system",
                content: "You are a helpful assistant that ranks search results. Return a JSON object with a 'ranked_ids' array containing video IDs in order of relevance."
            }, {
                role: "user",
                content: `Rank these videos by relevance to the query: "${originalQuery}"\n\nVideos:\n${formattedResults.map(r => 
                    `ID: ${r.id}\nTitle: ${r.title}\nDescription: ${r.description}\nLocation: ${r.location}\n---`
                ).join('\n')}`
            }],
            response_format: { type: "json_object" },
            temperature: 0.3
        });

        const parsed = JSON.parse(response.choices[0].message.content);
        console.log('Ranking order:', parsed.ranked_ids.map(id => id.slice(0, 6) + '...').join(', '));

        if (!parsed.ranked_ids || !Array.isArray(parsed.ranked_ids)) {
            console.log('Invalid ranking response, returning original order');
            return results;
        }

        // Map ranked IDs back to full results
        const rankedResults = parsed.ranked_ids
            .map(id => results.find(r => r.id === id))
            .filter(r => r !== undefined);

        // Add any results that weren't ranked to the end
        const rankedIds = new Set(rankedResults.map(r => r.id));
        const unrankedResults = results.filter(r => !rankedIds.has(r.id));
        
        return [...rankedResults, ...unrankedResults];
    } catch (error) {
        console.error('Error ranking results:', error);
        return results; // Return original results if ranking fails
    }
}

// Utility function to calculate cosine similarity
function calculateCosineSimilarity(vecA, vecB) {
    const dotProduct = vecA.reduce((sum, a, i) => sum + a * vecB[i], 0);
    const magnitudeA = Math.sqrt(vecA.reduce((sum, a) => sum + a * a, 0));
    const magnitudeB = Math.sqrt(vecB.reduce((sum, b) => sum + b * b, 0));
    return dotProduct / (magnitudeA * magnitudeB);
}

exports.semanticVideoSearch = functions
    .runWith({
        memory: '1GB',
        timeoutSeconds: 300,
        secrets: [
            "OPENAI_API_KEY",
            "LANGSMITH_API_KEY",
            "LANGCHAIN_PROJECT"
        ]
    })
    .https.onCall(async (data, context) => {
        const { Client } = require("langsmith");
        const client = new Client({
            apiKey: process.env.LANGSMITH_API_KEY,
            projectName: process.env.LANGCHAIN_PROJECT || "scroll-local",
            tracing: true,
            environment: "production"
        });
        
        const { query, location } = data;
        let run; // Declare run outside try block
        
        try {
            // Create run trace with required run_type
            run = await client.createRun({
                name: "video_semantic_search",
                run_type: "chain",
                inputs: { query, location },
                start_time: new Date().toISOString()
            });

            // 1. Generate search variations using OpenAI
            const searchQueries = await generateSearchQueries(query, client);
            console.log('Generated search queries:', searchQueries);
            
            // 2. Perform vector search for each query
            let allResults = [];
            for (const searchQuery of searchQueries) {
                const vectorResults = await performVectorSearch(
                    searchQuery, 
                    location, 
                    5
                );
                console.log(`Results for query "${searchQuery}":`, vectorResults.length);
                if (vectorResults.length > 0) {
                    allResults = [...allResults, ...vectorResults];
                }
            }
            
            console.log('Total results before ranking:', allResults.length);
            if (allResults.length === 0) {
                return []; // Return empty array if no results found
            }

            // 3. Rank results using OpenAI
            const rankedResults = await rankResults(allResults, query);
            console.log('Results after ranking:', rankedResults.length);
            
            // Update run with results
            if (run) { // Check if run exists
                await client.updateRun(run.id, {
                    outputs: { rankedResults },
                    status: "completed"
                });
            }

            return rankedResults.slice(0, 5);
            
        } catch (error) {
            console.error('Error in semantic search:', error);
            
            // Log error to LangSmith if run exists
            if (run) {
                await client.updateRun(run.id, {
                    error: error.message,
                    status: "failed"
                });
            }
            
            throw new functions.https.HttpsError('internal', error.message);
        }
    });

// Add feedback endpoint
exports.submitSearchFeedback = functions
    .runWith({
        memory: '256MB',
        timeoutSeconds: 60
    })
    .https.onCall(async (data, context) => {
        const { searchId, isHelpful, userId } = data;
        
        try {
            await admin.firestore().collection('searchFeedback').add({
                searchId,
                isHelpful,
                userId,
                timestamp: admin.firestore.FieldValue.serverTimestamp()
            });
            
            return { success: true };
        } catch (error) {
            console.error('Error submitting feedback:', error);
            throw new functions.https.HttpsError('internal', error.message);
        }
    }); 