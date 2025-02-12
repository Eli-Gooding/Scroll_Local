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

exports.getVideoDescription = async (frames) => {
    // Initialize OpenAI client when the function is called
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
                        text: "These are three frames from a video in chronological order. Please describe what is happening in the video based on these frames. Keep the description concise but informative."
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
    console.log('Got description:', response.choices[0].message.content);
    return response.choices[0].message.content;
}; 