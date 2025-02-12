const { spawn } = require('child-process-promise');
const os = require('os');
const path = require('path');
const fs = require('fs');
const ffmpegPath = require('ffmpeg-static');
const OpenAI = require('openai');

exports.extractFrames = async (videoPath, positions) => {
    const frames = [];
    for (const position of positions) {
        const framePath = path.join(os.tmpdir(), `frame_${position}.jpg`);
        await spawn(ffmpegPath, [
            '-i', videoPath,
            '-ss', `${position * 100}%`,
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

    const response = await openai.chat.completions.create({
        model: "gpt-4-vision-preview",
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
    return response.choices[0].message.content;
}; 