// MONKEYHUB PATCH 2: native audio decoder, shared declarations.
//
// mh_decode_to_wav16k() turns any audio file the OS can decode (AAC-LC in
// .m4a/MP4 is what MonkeyHub voice notes are; plain WAV of any PCM/float
// layout is decoded by dr_wav on every platform) into a 16 kHz mono PCM
// s16le WAV, the only format main.cpp's whisper reader accepts.
//
//   mh_audio.cpp            shared: WAV fast path, downmix, windowed-sinc
//                           resampler, WAV writer, the exported entry point
//   mh_decode_apple.cpp     iOS + macOS: AudioToolbox ExtAudioFile
//   mh_decode_android.cpp   Android: NDK AMediaExtractor + AMediaCodec
//   mh_decode_windows.cpp   Windows: Media Foundation IMFSourceReader
//   Linux has no native decoder: the Dart side spawns gst-launch-1.0 or
//   ffmpeg, and the native entry point returns MH_ERR_NO_DECODER.
//
// Keep the error codes in sync with WhisperDecodeException in
// lib/src/whisper_decode.dart.
#pragma once

#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <string>
#include <vector>

#if defined(__GNUC__)
#define MH_EXPORT __attribute__((visibility("default"))) __attribute__((used))
#elif defined(_MSC_VER)
#define MH_EXPORT __declspec(dllexport)
#else
#define MH_EXPORT
#endif

enum
{
    MH_OK = 0,
    MH_ERR_ARGS = -1,          // null/empty path
    MH_ERR_OPEN_INPUT = -2,    // input missing or unreadable
    MH_ERR_NO_AUDIO = -3,      // container has no audio track / unknown format
    MH_ERR_DECODER = -4,       // OS decoder could not be created or configured
    MH_ERR_DECODE = -5,        // decoding failed mid-stream
    MH_ERR_WRITE_OUTPUT = -6,  // output could not be created or written
    MH_ERR_EMPTY = -7,         // decoded zero samples
    MH_ERR_NO_DECODER = -10,   // this platform has no native decoder (Linux)
};

#ifdef __cplusplus
extern "C"
{
#endif

    // Returns MH_OK (0) or one of the negative MH_ERR_* codes. On failure
    // no partial output file is left behind. Blocking; call it off the UI
    // isolate. Paths are UTF-8 on every platform.
    MH_EXPORT int32_t mh_decode_to_wav16k(const char *in_path, const char *out_path);

#ifdef __cplusplus
}
#endif

namespace mh
{

static const int kOutRate = 16000;

// fopen with a UTF-8 path (Windows: converted to UTF-16 for _wfopen).
FILE *fopen_utf8(const char *path, const char *mode);
// remove() with a UTF-8 path.
void remove_utf8(const char *path);
#ifdef _WIN32
// UTF-8 -> UTF-16 for Win32 APIs. Empty on invalid input.
std::wstring widen(const char *utf8);
#endif

// Streaming windowed-sinc (Kaiser) resampler, mono float. Polyphase table
// for the exact rational ratio when it is small (44.1k->16k = 160/441,
// 48k->16k = 1/3, ...), otherwise 1024 nearest phases. Cutoff sits at 0.92
// of the lower Nyquist with ~80 dB stopband, so nothing above 8 kHz folds
// back into whisper's band.
class Resampler
{
public:
    Resampler(int in_rate, int out_rate);
    // Appends resampled output for `n` input samples to `out`.
    void process(const float *in, size_t n, std::vector<float> &out);
    // Pads with zeros so the last input samples come out, then resets.
    void flush(std::vector<float> &out);
    bool passthrough() const { return in_rate_ == out_rate_; }

private:
    void run(std::vector<float> &out, bool final);

    int in_rate_;
    int out_rate_;
    int half_;             // taps on each side of the centre
    int64_t L_;            // phase count (rational up-factor)
    int64_t M_;            // rational down-factor (exact mode only)
    bool exact_;           // integer position tracking
    double step_;          // input samples per output sample (inexact mode)
    std::vector<float> table_; // L_ phases x (2 * half_) taps
    std::vector<float> buf_;   // pending input, buf_[0] is input index base_
    int64_t base_ = 0;         // absolute input index of buf_[0]
    int64_t n_out_ = 0;        // output samples produced so far
    int64_t n_in_ = 0;         // input samples received so far
};

// Downmixes interleaved frames to mono, resamples to 16 kHz and writes a
// PCM s16le mono WAV. The input format may change between pushes (Android
// codecs announce it late); the resampler is rebuilt when it does.
class Wav16kSink
{
public:
    ~Wav16kSink();
    int open(const char *out_path);
    int push_f32(const float *interleaved, size_t frames, int channels, int rate);
    int push_s16(const int16_t *interleaved, size_t frames, int channels, int rate);
    // Flushes, writes the final header and closes. MH_ERR_EMPTY when no
    // sample was ever written (the file is removed then).
    int finish();
    // Closes and deletes the output.
    void fail();

private:
    int push_mono(const float *mono, size_t n, int rate);
    int write(const std::vector<float> &samples);

    FILE *file_ = nullptr;
    const char *path_ = nullptr;
    Resampler *rs_ = nullptr;
    int rs_rate_ = 0;
    uint64_t written_ = 0; // samples
    std::vector<float> mono_;
    std::vector<float> out_;
    std::vector<int16_t> pcm_;
};

// Platform decoder: decodes `in_path` into `sink`. Implemented once per
// platform file; returns MH_OK or MH_ERR_*.
int platform_decode(const char *in_path, Wav16kSink &sink);

} // namespace mh
