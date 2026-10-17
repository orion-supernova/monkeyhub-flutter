// MONKEYHUB PATCH 2: audio decoding without ffmpeg.
//
// Native side: android/src/whisper/mh_audio.h. Keep the codes below in sync
// with the MH_ERR_* enum there.
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:universal_io/io.dart';

import 'whisper_native.dart';

typedef _DecodeNative = Int32 Function(Pointer<Utf8> input, Pointer<Utf8> output);
typedef _DecodeDart = int Function(Pointer<Utf8> input, Pointer<Utf8> output);

/// Thrown by [decodeToWav16k] (and by `Whisper.transcribe` for non-WAV
/// input) when the audio cannot be turned into a 16 kHz mono WAV.
class WhisperDecodeException implements Exception {
  /// [code] is one of the constants below.
  const WhisperDecodeException(this.code, this.message);

  /// Null or empty path, or input and output are the same file.
  static const int invalidArguments = -1;

  /// The input is missing or unreadable.
  static const int openInput = -2;

  /// Not an audio file the OS can parse, or no audio track in it.
  static const int noAudio = -3;

  /// The OS decoder could not be created or configured for the stream.
  static const int decoder = -4;

  /// Decoding failed part-way through (corrupt or truncated file).
  static const int decode = -5;

  /// The output could not be written.
  static const int writeOutput = -6;

  /// The input decoded to zero samples.
  static const int empty = -7;

  /// Linux only: neither `gst-launch-1.0` nor `ffmpeg` could decode the
  /// input (missing, or missing the codec plugin). WAV input never needs
  /// them.
  static const int noDecoder = -10;

  /// Native result code (negative).
  final int code;

  /// Human-readable cause, for logs.
  final String message;

  @override
  String toString() => 'WhisperDecodeException($code): $message';
}

String _messageFor(int code) {
  switch (code) {
    case WhisperDecodeException.invalidArguments:
      return 'invalid arguments';
    case WhisperDecodeException.openInput:
      return 'cannot open input';
    case WhisperDecodeException.noAudio:
      return 'unsupported format or no audio track';
    case WhisperDecodeException.decoder:
      return 'audio decoder unavailable for this stream';
    case WhisperDecodeException.decode:
      return 'decoding failed';
    case WhisperDecodeException.writeOutput:
      return 'cannot write output';
    case WhisperDecodeException.empty:
      return 'no audio samples';
    case WhisperDecodeException.noDecoder:
      return 'no decoder available (install gstreamer with gst-libav, or ffmpeg)';
    default:
      return 'unknown error';
  }
}

/// Decode [inputPath] (any audio the OS can decode: AAC/m4a, MP3, CAF,
/// AIFF, WAV of any PCM/float layout, ...) into a 16 kHz mono PCM s16le
/// WAV at [outputPath], overwriting it. The work runs off the calling
/// isolate.
///
/// Uses the OS decoder: AudioToolbox on iOS/macOS, MediaCodec on Android,
/// Media Foundation on Windows. WAV is decoded natively everywhere. Linux
/// compressed input goes through `gst-launch-1.0`, then `ffmpeg`, from
/// PATH.
///
/// A file that already is a 16 kHz mono 16-bit WAV is copied as is.
/// Throws [WhisperDecodeException]; no partial output is left behind.
Future<void> decodeToWav16k(String inputPath, String outputPath) async {
  if (inputPath.isEmpty || outputPath.isEmpty || inputPath == outputPath) {
    throw WhisperDecodeException(
      WhisperDecodeException.invalidArguments,
      _messageFor(WhisperDecodeException.invalidArguments),
    );
  }
  final WavInfo? info = await readWavInfo(inputPath);
  if (info != null && info.isPcm16 && info.sampleRate == 16000 && info.channels == 1) {
    await File(inputPath).copy(outputPath);
    return;
  }

  final int code = await Isolate.run(() {
    final _DecodeDart decode = openWhisperLibrary()
        .lookupFunction<_DecodeNative, _DecodeDart>('mh_decode_to_wav16k');
    final Pointer<Utf8> input = inputPath.toNativeUtf8();
    final Pointer<Utf8> output = outputPath.toNativeUtf8();
    try {
      return decode(input, output);
    } finally {
      malloc.free(input);
      malloc.free(output);
    }
  });
  if (code == 0) {
    return;
  }
  if (code == WhisperDecodeException.noDecoder && Platform.isLinux) {
    if (await _decodeWithExternalTool(inputPath, outputPath)) {
      return;
    }
  }
  throw WhisperDecodeException(code, _messageFor(code));
}

/// Linux: GStreamer first (present on nearly every desktop; AAC needs
/// gst-libav or the fdkaac plugin), then ffmpeg.
Future<bool> _decodeWithExternalTool(String input, String output) async {
  String gstQuote(String path) =>
      '"${path.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
  final List<List<String>> commands = <List<String>>[
    <String>[
      'gst-launch-1.0',
      '-q',
      'filesrc',
      'location=${gstQuote(input)}',
      '!',
      'decodebin',
      '!',
      'audioconvert',
      '!',
      'audioresample',
      '!',
      'audio/x-raw,rate=16000,channels=1,format=S16LE',
      '!',
      'wavenc',
      '!',
      'filesink',
      'location=${gstQuote(output)}',
    ],
    <String>[
      'ffmpeg',
      '-nostdin',
      '-hide_banner',
      '-loglevel',
      'error',
      '-y',
      '-i',
      input,
      '-vn',
      '-ac',
      '1',
      '-ar',
      '16000',
      '-c:a',
      'pcm_s16le',
      '-f',
      'wav',
      output,
    ],
  ];
  for (final List<String> command in commands) {
    try {
      final ProcessResult result =
          await Process.run(command.first, command.sublist(1));
      if (result.exitCode == 0) {
        final WavInfo? info = await readWavInfo(output);
        if (info != null && info.sampleRate == 16000 && info.channels == 1) {
          return true;
        }
      }
    } on ProcessException {
      // Tool not installed; try the next one.
    }
    try {
      await File(output).delete();
    } on FileSystemException {
      // Never created.
    }
  }
  return false;
}

/// Format of a RIFF/WAVE file, from its `fmt ` chunk. Package-internal.
class WavInfo {
  const WavInfo(this.formatTag, this.channels, this.sampleRate, this.bitsPerSample);

  final int formatTag;
  final int channels;
  final int sampleRate;
  final int bitsPerSample;

  /// PCM (or WAVE_FORMAT_EXTENSIBLE, assumed PCM) 16-bit.
  bool get isPcm16 => (formatTag == 1 || formatTag == 0xFFFE) && bitsPerSample == 16;
}

/// Null when [path] is not a readable RIFF/WAVE file.
Future<WavInfo?> readWavInfo(String path) async {
  RandomAccessFile? file;
  try {
    file = await File(path).open();
    final Uint8List head = await file.read(64 * 1024);
    if (head.length < 12) {
      return null;
    }
    final ByteData data = ByteData.sublistView(head);
    String tag(int at) => String.fromCharCodes(head.sublist(at, at + 4));
    if (tag(0) != 'RIFF' || tag(8) != 'WAVE') {
      return null;
    }
    int at = 12;
    while (at + 8 <= head.length) {
      final String id = tag(at);
      final int size = data.getUint32(at + 4, Endian.little);
      if (id == 'fmt ' && size >= 16 && at + 8 + 16 <= head.length) {
        return WavInfo(
          data.getUint16(at + 8, Endian.little),
          data.getUint16(at + 10, Endian.little),
          data.getUint32(at + 12, Endian.little),
          data.getUint16(at + 22, Endian.little),
        );
      }
      at += 8 + size + (size & 1);
    }
    return null;
  } on FileSystemException {
    return null;
  } finally {
    await file?.close();
  }
}
