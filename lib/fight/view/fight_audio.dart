import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../../calls/call_service.dart';
import '../../calls/group_call_service.dart';
import '../../data/settings_store.dart';
import '../core/core.dart';
import 'fight_audio_plan.dart';

export 'fight_audio_plan.dart' show Sfx, SoundCue;
import '../../ui/foundation/caps.dart';

/// UI sounds for the fight menus and lobby.
enum FightUiSound { tick, confirm }

/// Jungle Fist's sound: effects, jingles and one music loop, on flutter_soloud.
///
/// ## Why SoLoud
/// A hit has to be heard on the frame it lands, even inside hitstop, and a
/// combo starts several overlapping voices. SoLoud mixes on a native audio
/// thread from samples already in memory; starting a voice is one synchronous
/// FFI call. just_audio (voice notes, call tones) prepares a platform player
/// per sound and lags tens to hundreds of milliseconds.
///
/// ## Audio sessions and calls (read before changing anything)
/// * SoLoud's CoreAudio backend is built with `sessionCategory =
///   ma_ios_session_category_none`, `noAudioSessionActivate` and
///   `noAudioSessionDeactivate` (flutter_soloud 3.5.4,
///   soloud_miniaudio.cpp). On iOS and macOS it therefore NEVER sets the
///   AVAudioSession category, never activates and never deactivates the
///   session. It plays through whatever session the app already has. That is
///   the property that keeps CallKit's session handling intact: nothing here
///   can reconfigure or tear down a call's `playAndRecord` session.
///   Consequence: with no call, the app's default session applies (ambient-ish,
///   so the silent switch mutes the game, which is what a game should do).
/// * The engine is created lazily by [open] (a fight screen opening) and fully
///   released by [close] (`deinit`), so nothing audio-related exists while the
///   user is not fighting.
/// * While a 1:1 or group call is live ([_callActive]) game audio is kept
///   silent: [open] is a no-op, effects are dropped, music is paused. If the
///   call ends mid-fight the engine opens/resumes by itself. Calls are never
///   ducked or competed with.
/// * Android: the engine opens its own Oboe/AAudio output stream; it does not
///   request audio focus, so it cannot steal focus from a call either.
class FightAudio implements SoundSink {
  FightAudio._() {
    _director = FightAudioDirector(
      sink: this,
      soundOn: () => SettingsStore.instance.fightSound,
      callActive: _callActive,
    );
  }

  static final FightAudio instance = FightAudio._();

  late final FightAudioDirector _director;

  /// Whether any call is live. Both services are created at app start; the
  /// `maybe` getters keep this safe in tests and before they exist.
  static bool _callActive() =>
      (CallService.maybeInstance?.inCall ?? false) || (GroupCallService.maybeInstance?.inCall ?? false);

  static const _dir = 'assets/audio/fight/';
  static const _musicFile = 'music_rooftop';
  static const _musicVolume = 0.30;
  static const _musicDucked = 0.10;

  final Map<Sfx, AudioSource> _sources = {};
  AudioSource? _music;
  SoundHandle? _musicHandle;
  Future<void>? _opening;
  bool _ready = false;
  bool _wanted = false; // open() was asked for and close() has not run
  bool _musicWanted = false;
  bool _ducked = false;
  bool _gated = false; // currently silenced by a call
  bool _listening = false;

  bool get isOpen => _ready;

  /// Lazy init + preload. Safe to call repeatedly. Does nothing when sound and
  /// music are both off, or while a call is active (it retries by itself once
  /// the call ends, see [onFrame]).
  Future<void> open() {
    _wanted = true;
    final s = SettingsStore.instance;
    if (_ready || (!s.fightSound && !s.fightMusic) || _callActive()) return Future.value();
    return _opening ??= _open().whenComplete(() => _opening = null);
  }

  Future<void> _open() async {
    try {
      final so = SoLoud.instance;
      if (!so.isInitialized) {
        // Small buffer = low latency. Android and web underrun more easily.
        await so.init(bufferSize: Caps.nativeApple ? 512 : 1024);
        so.setMaxActiveVoiceCount(24);
      }
      await Future.wait([
        for (final sfx in Sfx.values)
          if (!_sources.containsKey(sfx))
            so.loadAsset('$_dir${sfx.file}.wav').then((src) => _sources[sfx] = src),
      ]);
      if (!_wanted) {
        // close() ran while we were loading.
        await _release();
        return;
      }
      _ready = true;
      if (!_listening) {
        SettingsStore.instance.addListener(_onSettings);
        _listening = true;
      }
      if (_musicWanted) unawaited(_playMusic());
    } catch (e, st) {
      // Audio is garnish: a failed engine must never break a fight.
      debugPrint('FightAudio.open failed: $e\n$st');
      _ready = false;
    }
  }

  /// Stop the music and release the engine.
  Future<void> close() async {
    _wanted = false;
    _musicWanted = false;
    if (_listening) {
      SettingsStore.instance.removeListener(_onSettings);
      _listening = false;
    }
    final pending = _opening;
    if (pending != null) {
      try {
        await pending;
      } catch (_) {}
    }
    await _release();
    _director.reset();
  }

  Future<void> _release() async {
    _ready = false;
    final so = SoLoud.instance;
    try {
      final h = _musicHandle;
      _musicHandle = null;
      if (h != null && so.isInitialized) await so.stop(h);
      if (so.isInitialized) {
        for (final src in [..._sources.values, ?_music]) {
          await so.disposeSource(src);
        }
        so.deinit();
      }
    } catch (e) {
      debugPrint('FightAudio.close failed: $e');
    }
    _sources.clear();
    _music = null;
    _ducked = false;
    _gated = false;
  }

  void _onSettings() {
    final s = SettingsStore.instance;
    if (s.fightMusic && _musicWanted) {
      unawaited(_playMusic());
    } else {
      unawaited(_stopMusic());
    }
    // Turned on from the pause menu after opening with both off.
    if (_wanted && !_ready && (s.fightSound || s.fightMusic)) unawaited(open());
  }

  /// Plays every new event in [s].events exactly once, plus swing whooshes,
  /// round callouts and the match jingle. Cheap enough to call every frame.
  void onFrame(FightState s, {required int localPlayer}) {
    final callLive = _callActive();
    if (callLive != _gated) {
      _gated = callLive;
      if (callLive) {
        unawaited(_stopMusic());
      } else if (_wanted) {
        if (!_ready) {
          unawaited(open());
        } else if (_musicWanted) {
          unawaited(_playMusic());
        }
      }
    }
    // Runs even when not ready or silenced: the planner keeps its memory, so
    // an engine that finishes loading late does not replay the opening moves.
    _director.onFrame(s, localPlayer: localPlayer);
  }

  void ui(FightUiSound sound) {
    if (!_ready) return;
    _director.ui(sound == FightUiSound.tick ? Sfx.uiTick : Sfx.uiConfirm);
  }

  void startMusic() {
    _musicWanted = true;
    if (_ready) unawaited(_playMusic());
  }

  void stopMusic() {
    _musicWanted = false;
    unawaited(_stopMusic());
  }

  /// Quiet the music while the pause menu is up. SFX are unaffected (menus
  /// have none of their own besides the UI clicks).
  void duck(bool paused) {
    _ducked = paused;
    final h = _musicHandle;
    if (h == null || !_ready) return;
    try {
      SoLoud.instance.fadeVolume(h, paused ? _musicDucked : _musicVolume, const Duration(milliseconds: 200));
    } catch (_) {}
  }

  Future<void> _playMusic() async {
    if (!_ready || _musicHandle != null) return;
    final s = SettingsStore.instance;
    if (!s.fightMusic || _callActive()) return;
    try {
      final so = SoLoud.instance;
      _music ??= await so.loadAsset('$_dir$_musicFile.wav');
      if (!_ready || _musicHandle != null || !_musicWanted) return;
      final h = await so.play(_music!, volume: _ducked ? _musicDucked : _musicVolume, looping: true);
      so.setProtectVoice(h, true); // a combo must never steal the music's voice
      _musicHandle = h;
    } catch (e) {
      debugPrint('FightAudio music failed: $e');
    }
  }

  Future<void> _stopMusic() async {
    final h = _musicHandle;
    _musicHandle = null;
    if (h == null) return;
    try {
      if (SoLoud.instance.isInitialized) await SoLoud.instance.stop(h);
    } catch (_) {}
  }

  // SoundSink: one synchronous voice start, no awaiting on the hot path except
  // the (microtask-fast) handle for the rare pitch-shifted cue.
  @override
  void play(SoundCue cue) {
    if (!_ready) return;
    final src = _sources[cue.sfx];
    if (src == null) return;
    final so = SoLoud.instance;
    try {
      if (cue.speed == 1) {
        unawaited(so.play(src, volume: cue.volume, pan: cue.pan).then((_) {}, onError: (_) {}));
      } else {
        unawaited(so.play(src, volume: cue.volume, pan: cue.pan, paused: true).then((h) {
          so.setRelativePlaySpeed(h, cue.speed);
          so.setPause(h, false);
        }, onError: (_) {}));
      }
    } catch (_) {}
  }
}
