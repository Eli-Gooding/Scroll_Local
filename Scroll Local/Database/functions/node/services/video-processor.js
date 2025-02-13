const { spawn } = require('child-process-promise');
const os = require('os');
const path = require('path');
const fs = require('fs');
const ffmpegPath = require('ffmpeg-static');
const OpenAI = require('openai');

exports.extractFrames = async (videoPath, positions) => {
    const frames = [];

    // First, get video duration
    const durationResult = await spawn(ffmpegPath, [
        '-i', videoPath,
        '-f', 'null',
        '-'
    ], {
        capture: ['stderr']
    });

    // Parse duration from ffmpeg output - now including milliseconds
    const durationMatch = durationResult.stderr.toString().match(/Duration: (\d{2}):(\d{2}):(\d{2})\.(\d{2})/);
    if (!durationMatch) {
        throw new Error('Could not determine video duration');
    }

    const hours = parseInt(durationMatch[1]);
    const minutes = parseInt(durationMatch[2]);
    const seconds = parseInt(durationMatch[3]);
    const milliseconds = parseInt(durationMatch[4]) * 10; // Convert centiseconds to milliseconds
    const totalSeconds = hours * 3600 + minutes * 60 + seconds + (milliseconds / 1000);

    for (const position of positions) {
        const timeInSeconds = (totalSeconds * position).toFixed(3); // Keep 3 decimal places for milliseconds
        const framePath = path.join(os.tmpdir(), `frame_${position}.jpg`);
        
        await spawn(ffmpegPath, [
            '-i', videoPath,
            '-ss', `${timeInSeconds}`,  // Now includes milliseconds
            '-vframes', '1',
            '-vf', 'scale=512:512',
            framePath
        ]);
        
        const frameBuffer = await fs.promises.readFile(framePath);
        const base64Frame = frameBuffer.toString('base64');
        frames.push(base64Frame);
        
        fs.unlinkSync(framePath);
    }
    return frames;
};

exports.generateThumbnail = async (videoPath) => {
    const thumbPath = path.join(os.tmpdir(), `thumb_${path.basename(videoPath)}.png`);
    await spawn(ffmpegPath, [
        '-i', videoPath,
        '-ss', '00:00:01.000',
        '-vframes', '1',
        thumbPath,
    ]);
    return thumbPath;
};

exports.generateEmbedding = async (text) => {
    const openai = new OpenAI({
        apiKey: process.env.OPENAI_API_KEY
    });

    const response = await openai.embeddings.create({
        model: "text-embedding-3-small",
        input: text,
        encoding_format: "float"
    });

    return response.data[0].embedding;
};

exports.getVideoDescription = async (frames, videoMetadata) => {
    const openai = new OpenAI({
        apiKey: process.env.OPENAI_API_KEY
    });

    console.log('Getting description from OpenAI...');
    const response = await openai.chat.completions.create({
        model: "gpt-4o",
        messages: [
            {
                role: "user",
                content: [
                    {
                        type: "text",
                        text: "These are three frames from a video in chronological order. " +
                             "Please describe what is happening in the video based on these frames. " +
                             "Keep the description concise, colorful, and informative. " + 
                             "Your response should be describing the video as a whole, " +
                             "not just describing each frame by itself."
                    },
                    ...frames.map(frame => ({
                        type: "image_url",
                        image_url: {
                            url: `data:image/jpeg;base64,${frame}`
                        }
                    }))
                ]
            }
        ],
        max_tokens: 300
    });

    const description = response.choices[0].message.content;
    console.log('Got description:', description);

    // Create metadata object with only defined values
    const metadata = {};
    if (videoMetadata.title) metadata.title = videoMetadata.title;
    if (videoMetadata.formattedLocation) metadata.location = videoMetadata.formattedLocation;
    if (videoMetadata.id) metadata.video_id = videoMetadata.id;

    // Generate embedding from combined metadata and description
    const textToEmbed = [
        videoMetadata.title,
        videoMetadata.formattedLocation,
        videoMetadata.id,
        description
    ].filter(Boolean).join(' | ');

    const embedding = await exports.generateEmbedding(textToEmbed);

    // Only return fields that have values
    const result = {
        description,
        embedding
    };

    // Only add embedding_metadata if we have any metadata
    if (Object.keys(metadata).length > 0) {
        result.embedding_metadata = metadata;
    }

    return result;
}; 