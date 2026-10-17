// MONKEYHUB PATCH 2: iOS + macOS decoder (AudioToolbox ExtAudioFile).
//
// ExtAudioFile decodes the container (m4a/mp4/caf/aiff/mp3/...) and its
// built-in AudioConverter resamples to 16 kHz at max quality. Channels are
// kept as in the file and averaged by the shared sink, so the downmix is
// identical on every platform. Compiled into the pods through
// ios/Classes/mh_decode_apple.cpp and macos/Classes/mh_decode_apple.cpp.
#if defined(__APPLE__)

#include "mh_audio.h"

#include <AudioToolbox/AudioToolbox.h>
#include <CoreFoundation/CoreFoundation.h>

#include <cstring>
#include <vector>

namespace mh
{

int platform_decode(const char *in_path, Wav16kSink &sink)
{
    CFURLRef url = CFURLCreateFromFileSystemRepresentation(
        kCFAllocatorDefault, (const UInt8 *)in_path, (CFIndex)strlen(in_path), false);
    if (url == nullptr)
    {
        return MH_ERR_ARGS;
    }
    ExtAudioFileRef file = nullptr;
    OSStatus st = ExtAudioFileOpenURL(url, &file);
    CFRelease(url);
    if (st != noErr || file == nullptr)
    {
        // Unknown/corrupt container vs. an unreadable path.
        if (st == kAudioFileUnsupportedFileTypeError || st == kAudioFileUnsupportedDataFormatError ||
            st == kAudioFileInvalidFileError || st == kAudioFileNotOptimizedError)
        {
            return MH_ERR_NO_AUDIO;
        }
        return MH_ERR_OPEN_INPUT;
    }

    int rc = MH_OK;
    AudioStreamBasicDescription fileFmt;
    UInt32 size = sizeof(fileFmt);
    memset(&fileFmt, 0, sizeof(fileFmt));
    st = ExtAudioFileGetProperty(file, kExtAudioFileProperty_FileDataFormat, &size, &fileFmt);
    if (st != noErr || fileFmt.mChannelsPerFrame == 0)
    {
        ExtAudioFileDispose(file);
        return MH_ERR_NO_AUDIO;
    }

    const UInt32 channels = fileFmt.mChannelsPerFrame;
    AudioStreamBasicDescription client;
    memset(&client, 0, sizeof(client));
    client.mSampleRate = (Float64)kOutRate;
    client.mFormatID = kAudioFormatLinearPCM;
    client.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked;
    client.mChannelsPerFrame = channels;
    client.mBitsPerChannel = 32;
    client.mFramesPerPacket = 1;
    client.mBytesPerFrame = 4 * channels;
    client.mBytesPerPacket = client.mBytesPerFrame;
    st = ExtAudioFileSetProperty(file, kExtAudioFileProperty_ClientDataFormat, sizeof(client), &client);
    if (st != noErr)
    {
        ExtAudioFileDispose(file);
        return MH_ERR_DECODER;
    }

    // Best effort: max-quality sample rate conversion. Failure keeps the
    // (already decent) default converter.
    AudioConverterRef conv = nullptr;
    size = sizeof(conv);
    if (ExtAudioFileGetProperty(file, kExtAudioFileProperty_AudioConverter, &size, &conv) == noErr &&
        conv != nullptr)
    {
        UInt32 quality = kAudioConverterQuality_Max;
        AudioConverterSetProperty(conv, kAudioConverterSampleRateConverterQuality, sizeof(quality), &quality);
        CFArrayRef config = nullptr; // NULL = re-apply the converter's current settings
        ExtAudioFileSetProperty(file, kExtAudioFileProperty_ConverterConfig, sizeof(config), &config);
    }

    const UInt32 chunkFrames = 4096;
    std::vector<float> buf((size_t)chunkFrames * channels);
    for (;;)
    {
        AudioBufferList abl;
        abl.mNumberBuffers = 1;
        abl.mBuffers[0].mNumberChannels = channels;
        abl.mBuffers[0].mDataByteSize = (UInt32)(buf.size() * sizeof(float));
        abl.mBuffers[0].mData = buf.data();
        UInt32 frames = chunkFrames;
        st = ExtAudioFileRead(file, &frames, &abl);
        if (st != noErr)
        {
            rc = MH_ERR_DECODE;
            break;
        }
        if (frames == 0)
        {
            break; // EOF
        }
        rc = sink.push_f32(buf.data(), frames, (int)channels, kOutRate);
        if (rc != MH_OK)
        {
            break;
        }
    }
    ExtAudioFileDispose(file);
    return rc;
}

} // namespace mh

#endif // __APPLE__
