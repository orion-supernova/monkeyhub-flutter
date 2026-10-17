// MONKEYHUB PATCH 2: Windows decoder (Media Foundation IMFSourceReader).
//
// The source reader decodes to float (or 16-bit PCM when the decoder only
// offers that); the shared sink downmixes and resamples to 16 kHz. The
// AAC decoder MFT ships with Windows 7+ (absent only on "N" editions
// without the Media Feature Pack: MFCreateSourceReaderFromURL then fails
// and this returns MH_ERR_NO_AUDIO).
//
// Called from a Dart background isolate thread whose COM state is unknown:
// CoInitializeEx(MTA) is balanced when it succeeds (S_OK or S_FALSE), and
// RPC_E_CHANGED_MODE (thread already STA) is fine for the source reader in
// synchronous mode. MFStartup/MFShutdown are reference counted.
// Linked against mfplat, mfreadwrite, mfuuid, ole32 (windows/CMakeLists.txt).
#if defined(_WIN32)

#include "mh_audio.h"

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>

#include <mfapi.h>
#include <mferror.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <objbase.h>

#include <cstring>
#include <vector>

namespace mh
{

namespace
{
template <class T>
void safe_release(T *&p)
{
    if (p != nullptr)
    {
        p->Release();
        p = nullptr;
    }
}

struct Format
{
    UINT32 channels = 0;
    UINT32 rate = 0;
    bool is_float = false;
    UINT32 bits = 0;
};

HRESULT read_format(IMFSourceReader *reader, Format &f)
{
    IMFMediaType *cur = nullptr;
    HRESULT hr = reader->GetCurrentMediaType((DWORD)MF_SOURCE_READER_FIRST_AUDIO_STREAM, &cur);
    if (FAILED(hr))
    {
        return hr;
    }
    GUID sub = GUID_NULL;
    cur->GetGUID(MF_MT_SUBTYPE, &sub);
    f.channels = MFGetAttributeUINT32(cur, MF_MT_AUDIO_NUM_CHANNELS, 0);
    f.rate = MFGetAttributeUINT32(cur, MF_MT_AUDIO_SAMPLES_PER_SECOND, 0);
    f.bits = MFGetAttributeUINT32(cur, MF_MT_AUDIO_BITS_PER_SAMPLE, 0);
    f.is_float = IsEqualGUID(sub, MFAudioFormat_Float) != 0;
    safe_release(cur);
    if (f.channels == 0 || f.rate == 0 || (f.is_float ? f.bits != 32 : f.bits != 16))
    {
        return E_UNEXPECTED;
    }
    return S_OK;
}

HRESULT request_pcm(IMFSourceReader *reader, const GUID &subtype, UINT32 bits)
{
    IMFMediaType *pt = nullptr;
    HRESULT hr = MFCreateMediaType(&pt);
    if (FAILED(hr))
    {
        return hr;
    }
    pt->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Audio);
    pt->SetGUID(MF_MT_SUBTYPE, subtype);
    pt->SetUINT32(MF_MT_AUDIO_BITS_PER_SAMPLE, bits);
    hr = reader->SetCurrentMediaType((DWORD)MF_SOURCE_READER_FIRST_AUDIO_STREAM, nullptr, pt);
    safe_release(pt);
    return hr;
}

int decode_mf(const std::wstring &path, Wav16kSink &sink)
{
    IMFSourceReader *reader = nullptr;
    HRESULT hr = MFCreateSourceReaderFromURL(path.c_str(), nullptr, &reader);
    if (FAILED(hr))
    {
        if (hr == HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND) || hr == HRESULT_FROM_WIN32(ERROR_PATH_NOT_FOUND) ||
            hr == HRESULT_FROM_WIN32(ERROR_ACCESS_DENIED) || hr == HRESULT_FROM_WIN32(ERROR_SHARING_VIOLATION))
        {
            return MH_ERR_OPEN_INPUT;
        }
        return MH_ERR_NO_AUDIO; // MF_E_UNSUPPORTED_BYTESTREAM_TYPE and friends
    }

    int rc = MH_OK;
    reader->SetStreamSelection((DWORD)MF_SOURCE_READER_ALL_STREAMS, FALSE);
    if (FAILED(reader->SetStreamSelection((DWORD)MF_SOURCE_READER_FIRST_AUDIO_STREAM, TRUE)))
    {
        safe_release(reader);
        return MH_ERR_NO_AUDIO;
    }
    if (FAILED(request_pcm(reader, MFAudioFormat_Float, 32)) && FAILED(request_pcm(reader, MFAudioFormat_PCM, 16)))
    {
        safe_release(reader);
        return MH_ERR_DECODER;
    }
    Format fmt;
    if (FAILED(read_format(reader, fmt)))
    {
        safe_release(reader);
        return MH_ERR_DECODER;
    }

    std::vector<float> f32;
    std::vector<int16_t> s16;
    for (;;)
    {
        DWORD flags = 0;
        IMFSample *sample = nullptr;
        hr = reader->ReadSample((DWORD)MF_SOURCE_READER_FIRST_AUDIO_STREAM, 0, nullptr, &flags, nullptr, &sample);
        if (FAILED(hr))
        {
            rc = MH_ERR_DECODE;
            break;
        }
        if (flags & MF_SOURCE_READERF_CURRENTMEDIATYPECHANGED)
        {
            if (FAILED(read_format(reader, fmt)))
            {
                safe_release(sample);
                rc = MH_ERR_DECODE;
                break;
            }
        }
        if (sample != nullptr)
        {
            IMFMediaBuffer *buf = nullptr;
            if (FAILED(sample->ConvertToContiguousBuffer(&buf)))
            {
                safe_release(sample);
                rc = MH_ERR_DECODE;
                break;
            }
            BYTE *data = nullptr;
            DWORD len = 0;
            if (SUCCEEDED(buf->Lock(&data, nullptr, &len)))
            {
                const int ch = (int)fmt.channels;
                if (fmt.is_float)
                {
                    const size_t frames = (size_t)len / (4 * (size_t)ch);
                    f32.resize(frames * (size_t)ch);
                    memcpy(f32.data(), data, f32.size() * 4);
                    rc = sink.push_f32(f32.data(), frames, ch, (int)fmt.rate);
                }
                else
                {
                    const size_t frames = (size_t)len / (2 * (size_t)ch);
                    s16.resize(frames * (size_t)ch);
                    memcpy(s16.data(), data, s16.size() * 2);
                    rc = sink.push_s16(s16.data(), frames, ch, (int)fmt.rate);
                }
                buf->Unlock();
            }
            else
            {
                rc = MH_ERR_DECODE;
            }
            safe_release(buf);
            safe_release(sample);
            if (rc != MH_OK)
            {
                break;
            }
        }
        if (flags & (MF_SOURCE_READERF_ENDOFSTREAM | MF_SOURCE_READERF_ERROR))
        {
            if (flags & MF_SOURCE_READERF_ERROR)
            {
                rc = MH_ERR_DECODE;
            }
            break;
        }
    }
    safe_release(reader);
    return rc;
}
} // namespace

int platform_decode(const char *in_path, Wav16kSink &sink)
{
    const std::wstring wpath = widen(in_path);
    if (wpath.empty())
    {
        return MH_ERR_ARGS;
    }
    const HRESULT hr_co = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    const bool co_balance = SUCCEEDED(hr_co); // S_OK and S_FALSE both need CoUninitialize
    if (FAILED(hr_co) && hr_co != RPC_E_CHANGED_MODE)
    {
        return MH_ERR_DECODER;
    }
    int rc = MH_ERR_DECODER;
    if (SUCCEEDED(MFStartup(MF_VERSION, MFSTARTUP_NOSOCKET)))
    {
        rc = decode_mf(wpath, sink);
        MFShutdown();
    }
    if (co_balance)
    {
        CoUninitialize();
    }
    return rc;
}

} // namespace mh

#endif // _WIN32
