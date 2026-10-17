// MONKEYHUB PATCH 2: shared half of the native decoder (all platforms).
// See mh_audio.h for the file layout and error codes.
#include "mh_audio.h"

// Declarations only: DR_WAV_IMPLEMENTATION lives in main.cpp, which is
// linked into the same library on every platform.
#include "whisper.cpp/examples/dr_wav.h"

#include <algorithm>
#include <cmath>
#include <cstring>

#ifdef _WIN32
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#endif

namespace mh
{

// ---------------------------------------------------------------------------
// UTF-8 file helpers
// ---------------------------------------------------------------------------

#ifdef _WIN32
std::wstring widen(const char *utf8)
{
    if (utf8 == nullptr)
    {
        return std::wstring();
    }
    const int n = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8, -1, nullptr, 0);
    if (n <= 0)
    {
        return std::wstring();
    }
    std::wstring w((size_t)n, L'\0');
    MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8, -1, &w[0], n);
    w.resize((size_t)n - 1); // drop the terminator MultiByteToWideChar wrote
    return w;
}
#endif

FILE *fopen_utf8(const char *path, const char *mode)
{
#ifdef _WIN32
    const std::wstring wpath = widen(path);
    const std::wstring wmode = widen(mode);
    if (wpath.empty() || wmode.empty())
    {
        return nullptr;
    }
    return _wfopen(wpath.c_str(), wmode.c_str());
#else
    return fopen(path, mode);
#endif
}

void remove_utf8(const char *path)
{
#ifdef _WIN32
    const std::wstring wpath = widen(path);
    if (!wpath.empty())
    {
        _wremove(wpath.c_str());
    }
#else
    remove(path);
#endif
}

// ---------------------------------------------------------------------------
// Resampler
// ---------------------------------------------------------------------------

static const double kPi = 3.14159265358979323846;

static double bessel_i0(double x)
{
    // Power series; converges fast for the beta values used here.
    double sum = 1.0, term = 1.0;
    const double q = x * x / 4.0;
    for (int k = 1; k < 64; ++k)
    {
        term *= q / ((double)k * (double)k);
        sum += term;
        if (term < sum * 1e-12)
        {
            break;
        }
    }
    return sum;
}

static int64_t gcd64(int64_t a, int64_t b)
{
    while (b != 0)
    {
        const int64_t t = a % b;
        a = b;
        b = t;
    }
    return a;
}

Resampler::Resampler(int in_rate, int out_rate)
    : in_rate_(in_rate), out_rate_(out_rate)
{
    if (in_rate_ == out_rate_)
    {
        half_ = 0;
        L_ = 1;
        M_ = 1;
        exact_ = true;
        step_ = 1.0;
        return;
    }

    const int64_t g = gcd64(in_rate_, out_rate_);
    L_ = out_rate_ / g;
    M_ = in_rate_ / g;
    exact_ = L_ <= 1024;
    if (!exact_)
    {
        L_ = 1024;
    }
    step_ = (double)in_rate_ / (double)out_rate_;

    // Cutoff in cycles per input sample: 92% of the lower of the two
    // Nyquist frequencies (7.36 kHz for a 16 kHz output).
    const double ratio = (double)out_rate_ / (double)in_rate_;
    const double fc = 0.5 * std::min(1.0, ratio) * 0.92;
    // 16 zero crossings each side; Kaiser beta 7.86 = ~80 dB stopband.
    const double zero_crossings = 16.0;
    half_ = (int)std::ceil(zero_crossings / (2.0 * fc));
    const double beta = 7.857;
    const double i0_beta = bessel_i0(beta);
    const int taps = 2 * half_;

    table_.assign((size_t)(L_ * taps), 0.0f);
    std::vector<double> row((size_t)taps);
    for (int64_t p = 0; p < L_; ++p)
    {
        const double frac = (double)p / (double)L_;
        double sum = 0.0;
        for (int k = 0; k < taps; ++k)
        {
            // Distance (input samples) from the output instant to tap k.
            const double t = frac + (double)(half_ - 1 - k);
            const double x = 2.0 * fc * t;
            const double sinc = std::fabs(x) < 1e-9 ? 1.0 : std::sin(kPi * x) / (kPi * x);
            const double r = t / (double)half_;
            const double w = std::fabs(r) >= 1.0 ? 0.0 : bessel_i0(beta * std::sqrt(1.0 - r * r)) / i0_beta;
            row[(size_t)k] = 2.0 * fc * sinc * w;
            sum += row[(size_t)k];
        }
        // Unity DC gain on every phase (no phase-dependent ripple).
        for (int k = 0; k < taps; ++k)
        {
            table_[(size_t)(p * taps + k)] = (float)(row[(size_t)k] / sum);
        }
    }

    // Input indices before 0 read as silence.
    buf_.assign((size_t)half_, 0.0f);
    base_ = -half_;
}

void Resampler::process(const float *in, size_t n, std::vector<float> &out)
{
    if (passthrough())
    {
        out.insert(out.end(), in, in + n);
        return;
    }
    buf_.insert(buf_.end(), in, in + n);
    n_in_ += (int64_t)n;
    run(out, false);
}

void Resampler::flush(std::vector<float> &out)
{
    if (passthrough())
    {
        return;
    }
    run(out, true);
    buf_.assign((size_t)half_, 0.0f);
    base_ = -half_;
    n_out_ = 0;
    n_in_ = 0;
}

void Resampler::run(std::vector<float> &out, bool final)
{
    const int taps = 2 * half_;
    for (;;)
    {
        int64_t centre, phase;
        if (exact_)
        {
            const int64_t pos = n_out_ * M_; // in units of 1/L input samples
            centre = pos / L_;
            phase = pos % L_;
            if (final && pos >= n_in_ * L_)
            {
                break; // every output inside the input span is out
            }
        }
        else
        {
            const double t = (double)n_out_ * step_;
            centre = (int64_t)std::floor(t);
            phase = (int64_t)std::llround((t - (double)centre) * (double)L_);
            if (phase >= L_)
            {
                phase -= L_;
                centre += 1;
            }
            if (final && t >= (double)n_in_)
            {
                break;
            }
        }
        const int64_t last = centre + half_; // highest input index needed
        if (last >= n_in_)
        {
            if (!final)
            {
                break; // wait for more input
            }
            // Final flush: the missing tail reads as silence.
            const int64_t have = base_ + (int64_t)buf_.size();
            if (last >= have)
            {
                buf_.resize(buf_.size() + (size_t)(last - have + 1), 0.0f);
            }
        }
        const float *x = buf_.data() + (centre - half_ + 1 - base_);
        const float *h = table_.data() + phase * taps;
        float acc = 0.0f;
        for (int k = 0; k < taps; ++k)
        {
            acc += x[k] * h[k];
        }
        out.push_back(acc);
        ++n_out_;
    }

    // Drop input no future output can reach. Amortised: only when the
    // dead prefix is large, so the erase cost stays linear overall.
    int64_t next_centre;
    if (exact_)
    {
        next_centre = (n_out_ * M_) / L_;
    }
    else
    {
        next_centre = (int64_t)std::floor((double)n_out_ * step_);
    }
    const int64_t keep_from = next_centre - half_; // one sample of slack
    const int64_t dead = keep_from - base_;
    if (dead > 16384)
    {
        buf_.erase(buf_.begin(), buf_.begin() + dead);
        base_ += dead;
    }
}

// ---------------------------------------------------------------------------
// WAV sink
// ---------------------------------------------------------------------------

static void put_u16(unsigned char *p, uint16_t v)
{
    p[0] = (unsigned char)(v & 0xff);
    p[1] = (unsigned char)(v >> 8);
}

static void put_u32(unsigned char *p, uint32_t v)
{
    p[0] = (unsigned char)(v & 0xff);
    p[1] = (unsigned char)((v >> 8) & 0xff);
    p[2] = (unsigned char)((v >> 16) & 0xff);
    p[3] = (unsigned char)(v >> 24);
}

static bool write_header(FILE *f, uint64_t n_samples)
{
    const uint32_t data_bytes = (uint32_t)std::min<uint64_t>(n_samples * 2, 0xFFFFFFFFull - 36);
    unsigned char h[44];
    memcpy(h, "RIFF", 4);
    put_u32(h + 4, 36 + data_bytes);
    memcpy(h + 8, "WAVE", 4);
    memcpy(h + 12, "fmt ", 4);
    put_u32(h + 16, 16);              // fmt chunk size
    put_u16(h + 20, 1);               // PCM
    put_u16(h + 22, 1);               // mono
    put_u32(h + 24, kOutRate);        // sample rate
    put_u32(h + 28, kOutRate * 2);    // byte rate
    put_u16(h + 32, 2);               // block align
    put_u16(h + 34, 16);              // bits per sample
    memcpy(h + 36, "data", 4);
    put_u32(h + 40, data_bytes);
    return fwrite(h, 1, sizeof(h), f) == sizeof(h);
}

Wav16kSink::~Wav16kSink()
{
    if (file_ != nullptr)
    {
        fail();
    }
    delete rs_;
}

int Wav16kSink::open(const char *out_path)
{
    path_ = out_path;
    file_ = fopen_utf8(out_path, "wb");
    if (file_ == nullptr)
    {
        return MH_ERR_WRITE_OUTPUT;
    }
    if (!write_header(file_, 0))
    {
        fail();
        return MH_ERR_WRITE_OUTPUT;
    }
    return MH_OK;
}

int Wav16kSink::write(const std::vector<float> &samples)
{
    if (samples.empty())
    {
        return MH_OK;
    }
    pcm_.resize(samples.size());
    for (size_t i = 0; i < samples.size(); ++i)
    {
        float v = samples[i] * 32768.0f;
        v = v > 32767.0f ? 32767.0f : (v < -32768.0f ? -32768.0f : v);
        pcm_[i] = (int16_t)std::lrint(v);
    }
    // s16le on disk; every supported target is little-endian.
    if (fwrite(pcm_.data(), sizeof(int16_t), pcm_.size(), file_) != pcm_.size())
    {
        return MH_ERR_WRITE_OUTPUT;
    }
    written_ += samples.size();
    return MH_OK;
}

int Wav16kSink::push_mono(const float *mono, size_t n, int rate)
{
    if (file_ == nullptr)
    {
        return MH_ERR_WRITE_OUTPUT;
    }
    if (rate <= 0)
    {
        return MH_ERR_DECODE;
    }
    out_.clear();
    if (rs_ == nullptr || rate != rs_rate_)
    {
        if (rs_ != nullptr)
        {
            rs_->flush(out_);
            delete rs_;
        }
        rs_ = new Resampler(rate, kOutRate);
        rs_rate_ = rate;
    }
    rs_->process(mono, n, out_);
    return write(out_);
}

int Wav16kSink::push_f32(const float *in, size_t frames, int channels, int rate)
{
    if (channels <= 0)
    {
        return MH_ERR_DECODE;
    }
    if (channels == 1)
    {
        return push_mono(in, frames, rate);
    }
    mono_.resize(frames);
    const float scale = 1.0f / (float)channels;
    for (size_t i = 0; i < frames; ++i)
    {
        float s = 0.0f;
        for (int c = 0; c < channels; ++c)
        {
            s += in[i * channels + c];
        }
        mono_[i] = s * scale;
    }
    return push_mono(mono_.data(), frames, rate);
}

int Wav16kSink::push_s16(const int16_t *in, size_t frames, int channels, int rate)
{
    if (channels <= 0)
    {
        return MH_ERR_DECODE;
    }
    mono_.resize(frames);
    const float scale = 1.0f / (32768.0f * (float)channels);
    for (size_t i = 0; i < frames; ++i)
    {
        int32_t s = 0;
        for (int c = 0; c < channels; ++c)
        {
            s += in[i * channels + c];
        }
        mono_[i] = (float)s * scale;
    }
    return push_mono(mono_.data(), frames, rate);
}

int Wav16kSink::finish()
{
    if (file_ == nullptr)
    {
        return MH_ERR_WRITE_OUTPUT;
    }
    if (rs_ != nullptr)
    {
        out_.clear();
        rs_->flush(out_);
        const int rc = write(out_);
        if (rc != MH_OK)
        {
            fail();
            return rc;
        }
    }
    if (written_ == 0)
    {
        fail();
        return MH_ERR_EMPTY;
    }
    if (fseek(file_, 0, SEEK_SET) != 0 || !write_header(file_, written_))
    {
        fail();
        return MH_ERR_WRITE_OUTPUT;
    }
    const bool ok = fclose(file_) == 0;
    file_ = nullptr;
    if (!ok)
    {
        remove_utf8(path_);
        return MH_ERR_WRITE_OUTPUT;
    }
    return MH_OK;
}

void Wav16kSink::fail()
{
    if (file_ != nullptr)
    {
        fclose(file_);
        file_ = nullptr;
        remove_utf8(path_);
    }
}

// ---------------------------------------------------------------------------
// WAV input: decoded by dr_wav on every platform (PCM 8/16/24/32, float,
// A-law, mu-law, MS/IMA ADPCM), so OS decoders only ever see compressed
// containers.
// ---------------------------------------------------------------------------

static bool looks_like_wav(const char *in_path)
{
    FILE *f = fopen_utf8(in_path, "rb");
    if (f == nullptr)
    {
        return false;
    }
    unsigned char h[12];
    const size_t n = fread(h, 1, sizeof(h), f);
    fclose(f);
    return n == sizeof(h) && (memcmp(h, "RIFF", 4) == 0 || memcmp(h, "RF64", 4) == 0) &&
           memcmp(h + 8, "WAVE", 4) == 0;
}

// MH_ERR_NO_AUDIO when dr_wav cannot parse it (caller then tries the OS).
static int decode_wav(const char *in_path, Wav16kSink &sink)
{
    drwav wav;
#ifdef _WIN32
    const std::wstring wpath = widen(in_path);
    if (wpath.empty() || !drwav_init_file_w(&wav, wpath.c_str(), nullptr))
#else
    if (!drwav_init_file(&wav, in_path, nullptr))
#endif
    {
        return MH_ERR_NO_AUDIO;
    }
    if (wav.channels == 0 || wav.sampleRate == 0)
    {
        drwav_uninit(&wav);
        return MH_ERR_NO_AUDIO;
    }
    const int channels = wav.channels;
    const int rate = (int)wav.sampleRate;
    const size_t chunk = 4096;
    std::vector<float> buf(chunk * (size_t)channels);
    int rc = MH_OK;
    for (;;)
    {
        const drwav_uint64 got = drwav_read_pcm_frames_f32(&wav, chunk, buf.data());
        if (got == 0)
        {
            break;
        }
        rc = sink.push_f32(buf.data(), (size_t)got, channels, rate);
        if (rc != MH_OK)
        {
            break;
        }
    }
    drwav_uninit(&wav);
    return rc;
}

#if !defined(__APPLE__) && !defined(__ANDROID__) && !defined(_WIN32)
// Linux and other desktop Unix: no system AAC decoder to link against.
// WAV still decodes above; the Dart side handles MH_ERR_NO_DECODER by
// spawning gst-launch-1.0 or ffmpeg.
int platform_decode(const char *, Wav16kSink &)
{
    return MH_ERR_NO_DECODER;
}
#endif

} // namespace mh

extern "C" MH_EXPORT int32_t mh_decode_to_wav16k(const char *in_path, const char *out_path)
{
    if (in_path == nullptr || out_path == nullptr || in_path[0] == '\0' || out_path[0] == '\0' ||
        strcmp(in_path, out_path) == 0)
    {
        return MH_ERR_ARGS;
    }
    FILE *probe = mh::fopen_utf8(in_path, "rb");
    if (probe == nullptr)
    {
        return MH_ERR_OPEN_INPUT;
    }
    fclose(probe);

    try
    {
        mh::Wav16kSink sink;
        int rc = sink.open(out_path);
        if (rc != MH_OK)
        {
            return rc;
        }
        rc = MH_ERR_NO_AUDIO;
        if (mh::looks_like_wav(in_path))
        {
            rc = mh::decode_wav(in_path, sink);
        }
        if (rc == MH_ERR_NO_AUDIO)
        {
            rc = mh::platform_decode(in_path, sink);
        }
        if (rc != MH_OK)
        {
            sink.fail();
            return rc;
        }
        return sink.finish();
    }
    catch (...)
    {
        // bad_alloc on a huge file; never let an exception cross FFI.
        mh::remove_utf8(out_path);
        return MH_ERR_DECODE;
    }
}
