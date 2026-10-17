// MONKEYHUB PATCH 2: Android decoder (NDK AMediaExtractor + AMediaCodec).
//
// Every API used here exists since API 21; the plugin's minSdk is 24.
// The codec's PCM (16-bit, or float when the codec chooses it) is
// downmixed and resampled to 16 kHz by the shared sink in mh_audio.cpp.
// Linked against libmediandk (android/src/whisper/CMakeLists.txt).
#if defined(__ANDROID__)

#include "mh_audio.h"

#include <media/NdkMediaCodec.h>
#include <media/NdkMediaExtractor.h>
#include <media/NdkMediaFormat.h>

#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>

#include <cstring>
#include <string>
#include <vector>

namespace mh
{

// android.media.AudioFormat encodings. "pcm-encoding" is spelled out:
// AMEDIAFORMAT_KEY_PCM_ENCODING is only declared from API 28.
static const char *kKeyPcmEncoding = "pcm-encoding";
static const int32_t kPcm16 = 2;
static const int32_t kPcm8 = 3;
static const int32_t kPcmFloat = 4;

static const int64_t kTimeoutUs = 10000;
// Consecutive empty dequeues (x kTimeoutUs) after which a codec that
// stopped producing output is treated as hung: 10 s.
static const int kMaxIdlePolls = 1000;

namespace
{
struct Resources
{
    int fd = -1;
    AMediaExtractor *ex = nullptr;
    AMediaFormat *track = nullptr;
    AMediaCodec *codec = nullptr;
    bool started = false;

    ~Resources()
    {
        if (codec != nullptr)
        {
            if (started)
            {
                AMediaCodec_stop(codec);
            }
            AMediaCodec_delete(codec);
        }
        if (track != nullptr)
        {
            AMediaFormat_delete(track);
        }
        if (ex != nullptr)
        {
            AMediaExtractor_delete(ex);
        }
        if (fd >= 0)
        {
            close(fd);
        }
    }
};
} // namespace

static void read_output_format(AMediaFormat *fmt, int32_t &rate, int32_t &channels, int32_t &encoding)
{
    int32_t v = 0;
    if (AMediaFormat_getInt32(fmt, AMEDIAFORMAT_KEY_SAMPLE_RATE, &v) && v > 0)
    {
        rate = v;
    }
    if (AMediaFormat_getInt32(fmt, AMEDIAFORMAT_KEY_CHANNEL_COUNT, &v) && v > 0)
    {
        channels = v;
    }
    if (AMediaFormat_getInt32(fmt, kKeyPcmEncoding, &v))
    {
        encoding = v;
    }
}

int platform_decode(const char *in_path, Wav16kSink &sink)
{
    Resources r;
    r.fd = open(in_path, O_RDONLY | O_CLOEXEC);
    if (r.fd < 0)
    {
        return MH_ERR_OPEN_INPUT;
    }
    struct stat st;
    if (fstat(r.fd, &st) != 0 || st.st_size <= 0)
    {
        return MH_ERR_OPEN_INPUT;
    }

    r.ex = AMediaExtractor_new();
    if (r.ex == nullptr)
    {
        return MH_ERR_DECODER;
    }
    if (AMediaExtractor_setDataSourceFd(r.ex, r.fd, 0, (off64_t)st.st_size) != AMEDIA_OK)
    {
        return MH_ERR_NO_AUDIO;
    }

    // First audio track.
    std::string mime;
    const size_t n_tracks = AMediaExtractor_getTrackCount(r.ex);
    for (size_t i = 0; i < n_tracks; ++i)
    {
        AMediaFormat *fmt = AMediaExtractor_getTrackFormat(r.ex, i);
        const char *m = nullptr;
        if (fmt != nullptr && AMediaFormat_getString(fmt, AMEDIAFORMAT_KEY_MIME, &m) && m != nullptr &&
            strncmp(m, "audio/", 6) == 0)
        {
            mime = m; // owned by fmt
            r.track = fmt;
            AMediaExtractor_selectTrack(r.ex, i);
            break;
        }
        if (fmt != nullptr)
        {
            AMediaFormat_delete(fmt);
        }
    }
    if (r.track == nullptr)
    {
        return MH_ERR_NO_AUDIO;
    }

    int32_t rate = 0, channels = 0, encoding = kPcm16;
    read_output_format(r.track, rate, channels, encoding);
    encoding = kPcm16; // the track's own encoding key (raw WAV) is not the codec's output

    r.codec = AMediaCodec_createDecoderByType(mime.c_str());
    if (r.codec == nullptr)
    {
        return MH_ERR_DECODER;
    }
    if (AMediaCodec_configure(r.codec, r.track, nullptr, nullptr, 0) != AMEDIA_OK)
    {
        return MH_ERR_DECODER;
    }
    if (AMediaCodec_start(r.codec) != AMEDIA_OK)
    {
        return MH_ERR_DECODER;
    }
    r.started = true;

    bool input_done = false;
    int idle = 0;
    std::vector<float> f32;
    std::vector<int16_t> s16;
    for (;;)
    {
        if (!input_done)
        {
            const ssize_t ii = AMediaCodec_dequeueInputBuffer(r.codec, kTimeoutUs);
            if (ii >= 0)
            {
                size_t cap = 0;
                uint8_t *buf = AMediaCodec_getInputBuffer(r.codec, (size_t)ii, &cap);
                const ssize_t n = buf == nullptr ? -1 : AMediaExtractor_readSampleData(r.ex, buf, cap);
                if (n < 0)
                {
                    AMediaCodec_queueInputBuffer(r.codec, (size_t)ii, 0, 0, 0,
                                                 AMEDIACODEC_BUFFER_FLAG_END_OF_STREAM);
                    input_done = true;
                }
                else
                {
                    const int64_t pts = AMediaExtractor_getSampleTime(r.ex);
                    AMediaCodec_queueInputBuffer(r.codec, (size_t)ii, 0, (size_t)n,
                                                 (uint64_t)(pts < 0 ? 0 : pts), 0);
                    AMediaExtractor_advance(r.ex);
                }
            }
        }

        AMediaCodecBufferInfo info;
        const ssize_t oi = AMediaCodec_dequeueOutputBuffer(r.codec, &info, kTimeoutUs);
        if (oi >= 0)
        {
            idle = 0;
            int rc = MH_OK;
            if (info.size > 0)
            {
                size_t osize = 0;
                uint8_t *ob = AMediaCodec_getOutputBuffer(r.codec, (size_t)oi, &osize);
                if (ob == nullptr || channels <= 0 || rate <= 0 ||
                    (size_t)info.offset + (size_t)info.size > osize)
                {
                    rc = MH_ERR_DECODE;
                }
                else
                {
                    const uint8_t *data = ob + info.offset;
                    if (encoding == kPcmFloat)
                    {
                        const size_t frames = (size_t)info.size / (4 * (size_t)channels);
                        f32.resize(frames * (size_t)channels);
                        memcpy(f32.data(), data, f32.size() * 4);
                        rc = sink.push_f32(f32.data(), frames, channels, rate);
                    }
                    else if (encoding == kPcm16)
                    {
                        const size_t frames = (size_t)info.size / (2 * (size_t)channels);
                        s16.resize(frames * (size_t)channels);
                        memcpy(s16.data(), data, s16.size() * 2);
                        rc = sink.push_s16(s16.data(), frames, channels, rate);
                    }
                    else if (encoding == kPcm8)
                    {
                        const size_t frames = (size_t)info.size / (size_t)channels;
                        s16.resize(frames * (size_t)channels);
                        for (size_t i = 0; i < s16.size(); ++i)
                        {
                            s16[i] = (int16_t)(((int)data[i] - 128) << 8);
                        }
                        rc = sink.push_s16(s16.data(), frames, channels, rate);
                    }
                    else
                    {
                        rc = MH_ERR_DECODE; // 24/32-bit int output: never seen from audio decoders
                    }
                }
            }
            AMediaCodec_releaseOutputBuffer(r.codec, (size_t)oi, false);
            if (rc != MH_OK)
            {
                return rc;
            }
            if (info.flags & AMEDIACODEC_BUFFER_FLAG_END_OF_STREAM)
            {
                return MH_OK;
            }
        }
        else if (oi == AMEDIACODEC_INFO_OUTPUT_FORMAT_CHANGED)
        {
            AMediaFormat *of = AMediaCodec_getOutputFormat(r.codec);
            if (of != nullptr)
            {
                read_output_format(of, rate, channels, encoding);
                AMediaFormat_delete(of);
            }
        }
        else if (oi == AMEDIACODEC_INFO_TRY_AGAIN_LATER)
        {
            if (input_done && ++idle > kMaxIdlePolls)
            {
                return MH_ERR_DECODE;
            }
        }
        else if (oi == AMEDIACODEC_INFO_OUTPUT_BUFFERS_CHANGED)
        {
            // Nothing cached: buffers are fetched per index.
        }
        else
        {
            return MH_ERR_DECODE;
        }
    }
}

} // namespace mh

#endif // __ANDROID__
