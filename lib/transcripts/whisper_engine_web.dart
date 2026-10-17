/// No whisper.cpp in the browser: the plugin is FFI. Web shows no transcript
/// button (see [SpeechEngine.supported]).
library;

import 'speech_engine.dart';

SpeechEngine? createWhisperEngine() => null;
