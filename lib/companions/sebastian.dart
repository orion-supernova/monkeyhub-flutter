/// Sebastian. He reads languages, and he never tells anyone what he read.
///
/// ── The shape of this file ─────────────────────────────────────────────────
///
/// Two notifiers, on purpose, and the split is the reason the feature can be
/// fast.
///
///  * [Sebastian] itself is coarse. It changes when he is switched on, when a
///    brain arrives, when the target language changes, when a room starts or
///    stops translating. A handful of times a session. Screens listen to it.
///  * [TranslationHandle] is one per distinct piece of text, and it is what a
///    BUBBLE listens to. A translation streaming in at fifteen tokens a second
///    notifies exactly one handle, so exactly one bubble rebuilds.
///
/// A single global notifier would have been half the code and would have
/// rebuilt every visible bubble on every token of every translation — sixty
/// times a second, times however many bubbles are on screen, while the model
/// is already using the whole CPU. The transcript would have dropped frames
/// for the entire duration of a room translation, which is precisely the
/// moment it must not.
///
/// ── Scheduling ─────────────────────────────────────────────────────────────
///
/// Exactly one translation runs at a time — not a pool. On-device inference is
/// not parallel: two generations contend for the same accelerator and finish
/// later than they would in sequence, having also doubled peak memory. So the
/// only real scheduling decision is ORDER, and the answer is "whatever the
/// user is looking at". See [TranslationPriority].
library;

import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show kDebugMode, visibleForTesting;
import 'package:flutter/widgets.dart';

import '../data/settings_store.dart';
import '../models/chat_message.dart';
import '../models/enums.dart';
import 'brain_gateway.dart';
import 'brain_manager.dart';
import 'brain_spec.dart';
import 'translation/language.dart';
import 'translation/language_detector.dart';
import 'translation/translation_cache.dart';
import 'translation/translation_prompt.dart';

/// Whether a rejected candidate is printed alongside its verdict.
///
/// OFF, and it must ship that way: a translation candidate is a copy of
/// somebody's message, and printing it puts that message in logcat/syslog on a
/// real handset. Debug builds run on real handsets too, which is why this is a
/// constant somebody has to change on purpose rather than a `kDebugMode` check.
///
/// It exists because the verdict alone — `rejected (preamble)` — names the rule
/// that fired and says nothing about what the model actually produced, and a
/// prompt cannot be fixed from that.
const bool kDiagnoseRejections = false;

/// Where a single piece of text has got to.
enum TranslationState {
  /// Waiting for the worker. The bubble shows a resting shimmer.
  queued,

  /// The brain is being loaded. Its own state because of how long it takes:
  /// mapping the weights and initialising the accelerator is a ONE-OFF
  /// ~27 seconds on a phone, against well under a second for the translation
  /// that follows. Shown with the same anonymous bar, those two are
  /// indistinguishable, and the first translation of a session looks broken.
  warmingUp,

  /// Tokens are arriving, and none of them are on screen. The bubble shows the
  /// same shimmer it shows while queued, plus the caret — the state exists so
  /// the reader can see that work is happening, not so they can watch it.
  /// [TranslationHandle.text] stays null until the whole answer has passed
  /// [TranslationPrompt.verify].
  streaming,

  /// Finished, and [TranslationHandle.text] is the translation.
  done,

  /// Already in the target language — the detector said so, or the model
  /// handed it straight back. Nothing to show, and the bubble says so quietly
  /// rather than pretending to have worked.
  sameLanguage,

  /// Something went wrong. Retryable.
  failed,
}

/// How urgently a piece of text wants translating. The whole scheduler.
enum TranslationPriority {
  /// The user tapped Translate on this exact bubble, or it is on screen right
  /// now. Jumps the queue.
  visible,

  /// Just above or below the viewport. Doing these early is what makes
  /// scrolling a translated room feel like the work was already done.
  nearby,

  /// The rest of the room. Whenever there is nothing better to do.
  background,
}

/// The per-text notifier a bubble binds to.
///
/// Keyed by content, like the cache and for the same reasons — an edited
/// message gets a new handle, and the same sentence said twice shares one.
class TranslationHandle extends ChangeNotifier {
  TranslationHandle._(this.sourceText, this.roomId);

  final String sourceText;

  /// The room this was first asked about.
  ///
  /// Handles are keyed by CONTENT, so the same sentence said in two rooms
  /// shares one — this records whichever asked first. It exists for
  /// [Sebastian.forgetMissing], which needs to know whose disappearance it
  /// should be watching for.
  final String? roomId;

  TranslationState _state = TranslationState.queued;
  TranslationState get state => _state;

  String? _finalText;

  /// What to render, or null while there is nothing fit to show.
  ///
  /// Only ever the finished, VERIFIED translation. It used to also carry the
  /// sanitised prefix of a generation in flight, so a bubble filled in word by
  /// word — and that is exactly how a model's reasoning reached readers: mid
  /// stream there is no second line yet, so [TranslationPrompt.sanitize] cannot
  /// tell an announcement from the answer and passes it straight through. See
  /// [Sebastian._generate].
  String? get text => _finalText;

  String? _sourceLanguage;

  /// The detector's verdict, for the "translated from X" line. Null when it
  /// could not tell — in which case the line simply doesn't claim to know.
  String? get sourceLanguage => _sourceLanguage;

  /// Whether the reader has flipped this bubble back to the original. Lives on
  /// the handle rather than in the widget so it survives the bubble being
  /// scrolled out of the list and rebuilt.
  bool showingOriginal = false;

  /// Tokens are moving. Carries no text — see [text] — only the fact, which is
  /// what the bubble's shimmer and caret are bound to.
  void _markWorking(String? sourceLanguage) {
    if (_finalText != null) return;
    if (sourceLanguage != null) _sourceLanguage = sourceLanguage;
    if (_state == TranslationState.streaming) return;
    _state = TranslationState.streaming;
    notifyListeners();
  }

  void _finish(TranslationState state, {String? text, String? sourceLanguage}) {
    _state = state;
    if (text != null) _finalText = text;
    if (sourceLanguage != null) _sourceLanguage = sourceLanguage;
    // Belt and braces: nothing unverified can be here to begin with, but a
    // failed or already-in-this-language verdict must never leave earlier text
    // on screen looking like an answer.
    if (state == TranslationState.failed ||
        state == TranslationState.sameLanguage) {
      _finalText = null;
    }
    notifyListeners();
  }

  void _reset() {
    _state = TranslationState.queued;
    _finalText = null;
    notifyListeners();
  }
}

/// How far a room-wide translation has got, for the status bar.
@immutable
class RoomTranslationProgress {
  const RoomTranslationProgress({required this.done, required this.total});

  final int done;
  final int total;

  bool get isComplete => done >= total;
  double get fraction => total <= 0 ? 1 : (done / total).clamp(0.0, 1.0);

  static const none = RoomTranslationProgress(done: 0, total: 0);
}

class Sebastian extends ChangeNotifier {
  Sebastian._();
  static final Sebastian instance = Sebastian._();

  /// The brain he loads. Fixed — see [Companion.brainsAreUserChosen].
  BrainSpec get brain => BrainCatalog.sebastianBrain;

  // ─────────────────────────── availability ───────────────────────────

  /// Whether this build can run him at all. False on web; see
  /// [BrainGateway.isSupported].
  bool get isAvailable => BrainGateway.instance.isSupported;

  /// Whether his brain is on disk.
  bool get isInstalled => BrainManager.instance.isInstalled(brain);

  /// Whether the user has switched him on. Off by default: he costs a 328 MB
  /// download, and a feature that large should be asked for rather than
  /// assumed.
  bool get isEnabled => SettingsStore.instance.sebastianEnabled;

  /// The one question every entry point asks: can this actually happen right
  /// now, without a sheet or a download?
  bool get isReady => isAvailable && isEnabled && isInstalled;

  /// What he translates INTO.
  ///
  /// Resolution order, and each fallback exists for a case that really happens:
  /// an explicit choice in Settings; otherwise the app's own display language,
  /// which on a shared handset is the better signal; otherwise English, which
  /// is not a guess so much as the only defensible default when nothing is
  /// known.
  TranslationLanguage get targetLanguage {
    // Memoised on the two settings it derives from. This getter is read once
    // per bubble per build — [handleFor] calls it to build the key — so the
    // uncached form was a string split, a lowercase and two map lookups for
    // every message on screen, every frame. The cache key is the raw pair, so
    // it invalidates itself the moment either setting changes and needs no
    // listener of its own.
    final explicitCode = SettingsStore.instance.translationTarget;
    final appCode = SettingsStore.instance.localeCode;
    final cached = _targetCache;
    if (cached != null &&
        cached.$1 == explicitCode &&
        cached.$2 == appCode) {
      return cached.$3;
    }

    final resolved = languageForCode(explicitCode) ??
        languageForCode(appCode) ??
        languageForCode(PlatformDispatcher.instance.locale.languageCode) ??
        kTranslationLanguages.first;
    _targetCache = (explicitCode, appCode, resolved);
    return resolved;
  }

  /// (explicit setting, app locale, what they resolved to). See
  /// [targetLanguage].
  (String?, String?, TranslationLanguage)? _targetCache;

  // ─────────────────────────── handles ───────────────────────────

  final Map<String, TranslationHandle> _handles = {};

  final _HandleRegistry _registry = _HandleRegistry();

  /// Fires when a handle is CREATED or dropped — never when one changes.
  ///
  /// A bubble needs two subscriptions and this is the cheap one. It cannot
  /// listen to its own handle until that handle exists, so something has to
  /// tell it when one appears; but listening to [Sebastian] itself for that
  /// would also wake it on every room-progress tick, which in a translating
  /// room means every visible bubble rebuilding once per translated message.
  /// This notifier fires a few times per room instead of a few hundred.
  Listenable get handleRegistry => _registry;

  /// The handle for [message], or null if he has never been asked about it.
  ///
  /// Null is the resting state and the common one — the vast majority of
  /// bubbles in the vast majority of rooms — so it is deliberately cheap: one
  /// map lookup, no allocation, no work. A bubble that gets null draws exactly
  /// what it drew before this feature existed.
  TranslationHandle? handleFor(ChatMessage message) =>
      _handles[_key(message.content)];

  String _key(String content) => '${targetLanguage.code} ${content.trim()}';

  // ─────────────────────────── the queue ───────────────────────────

  /// One bucket per priority.
  ///
  /// A map per bucket rather than a list, for two properties that are both
  /// load-bearing: Dart's map literal is insertion-ordered, so equal-priority
  /// work stays first-come; and keying by the job's own key makes
  /// re-submitting something already waiting a PROMOTION rather than a
  /// duplicate. With a list, a room that re-enqueues on every message arrival
  /// would grow the queue without bound and translate the same text twice.
  final Map<TranslationPriority, Map<String, _Job>> _queues = {
    TranslationPriority.visible: <String, _Job>{},
    TranslationPriority.nearby: <String, _Job>{},
    TranslationPriority.background: <String, _Job>{},
  };

  String? _inflight;
  bool _pumping = false;

  /// Room ids the user has switched on. Persisted, so a room you translate
  /// stays translated tomorrow.
  Set<String> get translatingRooms => SettingsStore.instance.translatedRoomIds;

  bool isRoomTranslating(String roomId) => translatingRooms.contains(roomId);

  final Map<String, RoomTranslationProgress> _roomProgress = {};

  RoomTranslationProgress progressFor(String roomId) =>
      _roomProgress[roomId] ?? RoomTranslationProgress.none;

  // ─────────────────────────── entry points ───────────────────────────

  /// Translate one message, now.
  ///
  /// The single-bubble path: called from the long-press menu. Returns as soon
  /// as the job is accepted, not when it finishes — the bubble is already
  /// listening to the handle and will fill itself in.
  ///
  /// Safe to call on a message that is already translated, already queued, or
  /// not worth translating; each of those resolves without touching the model.
  void translate(
    ChatMessage message, {
    TranslationPriority priority = TranslationPriority.visible,
  }) {
    if (!isReady) return;
    if (!_isTranslatable(message)) return;

    final content = message.content;
    final key = _key(content);
    final existing = _handles[key];

    if (existing != null) {
      // Already showing a translation the reader had hidden — this is the
      // "translate" tap on a bubble flipped back to its original, which means
      // "show it again" and must not re-run the model.
      if (existing.showingOriginal &&
          existing.state != TranslationState.failed) {
        existing.showingOriginal = false;
        existing.notifyListeners();
        return;
      }
      if (existing.state == TranslationState.failed) {
        existing._reset();
      } else {
        // Queued or streaming or done — nothing to do but make sure a queued
        // one is at the front now that it has been asked for explicitly.
        _submit(key, content, priority, persist: message.expiresAt == null);
        return;
      }
    }

    final handle = TranslationHandle._(content, message.roomId);
    _handles[key] = handle;
    _trackHandle(message.roomId, key);
    // Settles the two no-model outcomes before returning, so the caller's
    // immediate read of the handle is truthful. See [_settleWithoutModel].
    if (!_settleWithoutModel(handle, content)) {
      _submit(key, content, priority, persist: message.expiresAt == null);
    }
    _registry.ping();
    notifyListeners();
  }

  /// Throws away what Sebastian said about [message] and asks again.
  ///
  /// Needed because a translation can be BAD without having failed — the model
  /// is small, and it will sometimes hand back something clumsy, truncated, or
  /// (before the checks that now catch it) nonsense. Tapping TRANSLATE again
  /// would show the cached copy of exactly that, forever: the cache cannot
  /// tell a good answer from a bad one, only a present one from an absent one.
  ///
  /// So this evicts the cache entry as well as the handle. Without that it
  /// would be a redraw rather than a retry.
  void translateAgain(ChatMessage message) {
    final key = _key(message.content);
    _handles.remove(key);
    for (final queue in _queues.values) {
      queue.remove(key);
    }
    TranslationCache.instance.remove(message.content, targetLanguage.code);
    _registry.ping();
    translate(message);
  }

  /// Flip a bubble back to what was actually said.
  void showOriginal(ChatMessage message) {
    final handle = handleFor(message);
    if (handle == null) return;
    handle.showingOriginal = true;
    handle.notifyListeners();
  }

  /// Whether the menu should offer "Show original" rather than "Translate".
  bool isShowingTranslation(ChatMessage message) {
    final h = handleFor(message);
    return h != null &&
        !h.showingOriginal &&
        (h.state == TranslationState.done ||
            h.state == TranslationState.streaming ||
            h.state == TranslationState.warmingUp ||
            h.state == TranslationState.queued);
  }

  /// Switch a whole room on.
  ///
  /// Submits everything at [TranslationPriority.background] and lets
  /// [prioritise] pull whatever is on screen to the front. Deliberately does
  /// NOT wait for or batch the work: the room is usable the whole time, and
  /// messages appear translated as they are reached.
  void startRoom(String roomId, List<ChatMessage> messages) {
    if (!isReady) return;
    SettingsStore.instance.setRoomTranslated(roomId, true);
    enqueueRoom(roomId, messages);
    notifyListeners();
  }

  /// Switch a room off.
  ///
  /// Drops its pending work but KEEPS every finished translation. Turning the
  /// room back on is then instant for everything already done, which is what
  /// makes this a toggle a person will actually use twice.
  void stopRoom(String roomId) {
    SettingsStore.instance.setRoomTranslated(roomId, false);
    for (final queue in _queues.values) {
      queue.removeWhere((_, job) => job.roomId == roomId);
    }
    _roomProgress.remove(roomId);
    notifyListeners();
  }

  /// Forgets everything Sebastian knows about messages that are no longer in
  /// [messages].
  ///
  /// ── The gap this closes ────────────────────────────────────────────────
  ///
  /// A translation outliving the message it was made from is the same leak as
  /// keeping the message itself, because it carries the same information. Two
  /// ways that happened:
  ///
  ///  * **Deletion.** Someone deletes a message — theirs or yours. It leaves
  ///    the transcript, and it leaves `messages_<roomId>.json` on the next
  ///    subscription fire, because that file is rewritten wholesale each time.
  ///    The translation stayed on disk indefinitely: [TranslationCache] is a
  ///    content-keyed LRU, so nothing evicted it until two thousand newer
  ///    translations pushed it out.
  ///  * **Memory.** [TranslationHandle] holds the plaintext ORIGINAL as well
  ///    as the translation, and pruning only ran above [_maxHandles] and only
  ///    for handles nothing was listening to. A faded ephemeral message could
  ///    keep its text in this map for the rest of the session.
  ///
  /// `expiresAt` alone could not have closed either: it says a message will
  /// fade, and says nothing about one that was deleted, edited, or has already
  /// gone. What does close both is the transcript itself — the room hands its
  /// current message list to [enqueueRoom] on every repository change, so
  /// "still there" is a fact already arriving on every tick.
  ///
  /// Runs whether or not the room is translating: a single tapped bubble in an
  /// otherwise untranslated room leaves exactly the same residue.
  void forgetMissing(String roomId, List<ChatMessage> messages) {
    final known = _roomHandles[roomId];
    // The overwhelmingly common case, and it costs one map lookup: nothing in
    // this room has ever been translated, so there is nothing to reconcile.
    if (known == null || known.isEmpty) return;

    final present = <String>{};
    for (final m in messages) {
      present.add(_key(m.content));
    }

    final gone = known.difference(present);
    if (gone.isEmpty) return;

    final code = targetLanguage.code;
    for (final key in gone) {
      known.remove(key);
      final handle = _handles.remove(key);
      if (handle == null) continue;
      // Evicts for EVERY room, not just this one — the cache is keyed by
      // content and cannot tell two rooms apart. Erring towards forgetting is
      // the right direction here: the cost of being wrong is one re-run of a
      // model that is already on the device, and the cost of the opposite is
      // keeping a copy of something somebody deleted.
      TranslationCache.instance.remove(handle.sourceText, code);
      // Not disposed — a bubble mid-teardown may still be listening, and
      // `removeListener` asserts on a disposed notifier. See [reset].
    }
    if (known.isEmpty) _roomHandles.remove(roomId);
    _registry.ping();
  }

  /// roomId → the handle keys that room is responsible for. The index that
  /// makes [forgetMissing] cheap enough to run on every repository tick.
  final Map<String, Set<String>> _roomHandles = {};

  void _trackHandle(String? roomId, String key) {
    if (roomId == null) return;
    (_roomHandles[roomId] ??= <String>{}).add(key);
  }

  /// Feeds a room's messages in, respecting whether it is switched on.
  ///
  /// Called when a room opens and again whenever its message list grows, so
  /// arriving messages in a translated room translate themselves. Cheap to
  /// call repeatedly: everything already handled short-circuits before the
  /// queue.
  void enqueueRoom(
    String roomId,
    List<ChatMessage> messages, {
    bool reconcile = true,
  }) {
    if (!isReady) return;
    // Ahead of the switched-on gate on purpose — a room nobody is translating
    // can still hold the residue of a single tapped bubble.
    //
    // [reconcile] is the caller's answer to "is this list the whole room?".
    // It is false while the transcript is showing a detached history window:
    // `ChatRepository.timelineFor` then returns a slice of old messages that
    // does not contain the live tail at all, and forgetting everything absent
    // from it would throw away every translation in the room the moment
    // somebody scrolled back far enough. Reconciliation resumes when the
    // window closes and the list means "the room" again.
    if (reconcile) forgetMissing(roomId, messages);
    if (!isRoomTranslating(roomId)) return;

    var total = 0;
    var done = 0;
    for (final message in messages) {
      if (!_isTranslatable(message)) continue;
      total++;
      final key = _key(message.content);
      final handle = _handles[key];
      if (handle != null &&
          handle.state != TranslationState.queued &&
          handle.state != TranslationState.streaming) {
        done++;
        continue;
      }
      if (handle == null) {
        final fresh = TranslationHandle._(message.content, roomId);
        _handles[key] = fresh;
        _trackHandle(roomId, key);
        // Most of a room is usually already in the reader's language, and
        // this is where that stops costing anything: those messages never
        // enter the queue, and `total` below counts real work only.
        if (_settleWithoutModel(fresh, message.content)) {
          done++;
          continue;
        }
      }
      _submit(
        key,
        message.content,
        TranslationPriority.background,
        roomId: roomId,
        persist: message.expiresAt == null,
      );
    }
    _roomProgress[roomId] = RoomTranslationProgress(done: done, total: total);
    _pruneHandles();
    _registry.ping();
    notifyListeners();
  }

  /// Drops handles nothing is watching any more.
  ///
  /// A handle is small, but a user who scrolls a busy group room for an hour
  /// with translation on would otherwise accumulate one per distinct message,
  /// forever, for the life of the process. `hasListeners` is exactly the right
  /// question: a handle with no listeners has no bubble on screen, and a
  /// bubble that comes back gets its translation from the disk cache in
  /// microseconds. Nothing is lost by forgetting it.
  ///
  /// Only ever runs when the map is already large, so the common session never
  /// pays for the sweep at all.
  void _pruneHandles() {
    if (_handles.length <= _maxHandles) return;
    _handles.removeWhere((key, handle) {
      if (handle.hasListeners) return false;
      if (_inflight == key) return false;
      if (handle.state == TranslationState.queued ||
          handle.state == TranslationState.streaming) {
        return false;
      }
      handle.dispose();
      for (final keys in _roomHandles.values) {
        keys.remove(key);
      }
      return true;
    });
  }

  static const int _maxHandles = 400;

  /// Recorded by a bubble as it builds, promoted after the frame.
  ///
  /// ── Why this is the visibility signal and not the scroll offset ─────────
  ///
  /// The transcript is a `ListView.builder`, so the rows that get BUILT are
  /// very nearly the rows on screen — the framework already solved this
  /// problem, exactly, including cache extent. Deriving the same answer from
  /// `pixels / maxScrollExtent` would be an estimate over variable-height rows
  /// that is wrong for albums, link cards and anything that just changed
  /// height because a translation landed in it.
  ///
  /// It records and never notifies, because it is called from `build`. The
  /// promotion happens in a post-frame callback, which is what keeps a bubble
  /// reporting itself from rebuilding the bubble that reported.
  void noteOnScreen(ChatMessage message) {
    if (!isReady) return;
    _onScreen.add(_key(message.content));
    if (_flushScheduled) return;
    _flushScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _flushScheduled = false;
      if (_onScreen.isEmpty) return;
      final keys = Set<String>.from(_onScreen);
      _onScreen.clear();
      var moved = false;
      for (final key in keys) {
        final job = _queues[TranslationPriority.background]!.remove(key) ??
            _queues[TranslationPriority.nearby]!.remove(key);
        if (job != null) {
          _queues[TranslationPriority.visible]![key] = job;
          moved = true;
        }
      }
      if (moved) _pump();
    });
  }

  final Set<String> _onScreen = {};
  bool _flushScheduled = false;

  /// Answers what can be answered without waking the model, right now.
  ///
  /// ── Why this is synchronous, and why that matters ──────────────────────
  ///
  /// Two of the three possible outcomes need no inference at all: the text is
  /// already in the reader's language, or it was translated before. Both were
  /// originally decided inside [_run], one queue-hop later — which was wrong
  /// twice over.
  ///
  /// It was wrong for the ROOM: `enqueueRoom` put every translatable message
  /// in the queue and only discovered on arrival that most of them needed
  /// nothing, so the progress bar counted work that did not exist and the
  /// worker walked a queue that was mostly no-ops.
  ///
  /// And it was wrong for the BUBBLE, in a way that made a visible feature
  /// dead code: the room screen reads the handle immediately after calling
  /// [translate] to decide whether to say "already in Türkçe", and a verdict
  /// that arrives a queue-hop later is always still `queued` when it looks.
  /// That toast could never fire.
  ///
  /// Returns true when the handle is finished and nothing should be queued.
  bool _settleWithoutModel(TranslationHandle handle, String content) {
    final target = targetLanguage;

    // Free — one pass over the runes. See [LanguageDetector].
    //
    // Two questions, two thresholds, deliberately. `detect` answers "roughly
    // what is this" for the caption; [LanguageDetector.isDefinitely] answers
    // "is there nothing to do here", and that one has to be very sure. A
    // Turkish message carrying an English phrase used to satisfy the first and
    // was reported as already-in-English — the feature silently declining to
    // work, which is worse than any translation it could have produced.
    final detected = LanguageDetector.detect(content);
    if (LanguageDetector.isDefinitely(content, target.code)) {
      handle._finish(TranslationState.sameLanguage, sourceLanguage: detected);
      return true;
    }

    // Also free ONCE the cache is in memory. Before that it is a disk read, so
    // this declines rather than blocking, and [_run] picks it up properly a
    // moment later. The cache loads on the first translation of a session, so
    // the miss here is at most one message deep.
    if (TranslationCache.instance.isLoaded) {
      final cached = TranslationCache.instance.get(content, target.code);
      if (cached != null) {
        handle._finish(
          TranslationState.done,
          text: cached,
          sourceLanguage: detected,
        );
        return true;
      }
    }
    return false;
  }

  /// Everything that has to be true before a message is worth a model run.
  ///
  /// Ordered cheapest-first, which matters: this runs over every message in a
  /// room on every list rebuild.
  bool _isTranslatable(ChatMessage message) {
    if (message.content.trim().isEmpty) return false;
    // A system notice is generated by this app and is already localised by it.
    // Translating "Zeynep joined the room" with a language model would be
    // slower, worse, and would fight the ARB file.
    if (message.type == MessageType.system) return false;
    // A poll's prompt, a checklist's title: these render inside interactive
    // cards this feature does not draw into. Excluded rather than mangled.
    if (message.type != MessageType.text && message.type != MessageType.url) {
      return false;
    }
    return LanguageDetector.isWorthTranslating(message.content);
  }

  void _submit(
    String key,
    String content,
    TranslationPriority priority, {
    String? roomId,
    required bool persist,
  }) {
    if (_inflight == key) return;

    // Promote rather than duplicate: a key already waiting at a lower priority
    // is moved up, and one already waiting at this priority or higher is left
    // where it is.
    for (final p in TranslationPriority.values) {
      final existing = _queues[p]![key];
      if (existing == null) continue;
      if (p.index <= priority.index) return;
      _queues[p]!.remove(key);
      break;
    }

    _queues[priority]![key] =
        _Job(key: key, content: content, roomId: roomId, persist: persist);
    _pump();
  }

  /// The worker. Runs one job, yields, runs the next.
  ///
  /// A plain loop rather than an isolate. The generation itself already
  /// crosses to native and streams back asynchronously, so the Dart side
  /// spends its time awaiting rather than computing — an isolate would add a
  /// copy of every chunk and buy nothing.
  Future<void> _pump() async {
    if (_pumping) return;
    _pumping = true;
    try {
      while (true) {
        final job = _take();
        if (job == null) break;
        _inflight = job.key;
        try {
          await _run(job);
        } catch (e) {
          debugPrint('Sebastian job failed: $e');
          _handles[job.key]?._finish(TranslationState.failed);
        } finally {
          _inflight = null;
          if (job.roomId != null) _bumpProgress(job.roomId!);
        }
        // Hand the frame back between jobs. Without this a hundred queued
        // messages run as one uninterrupted burst and the transcript freezes
        // for the duration — the exact opposite of what the priority buckets
        // are for.
        await Future<void>.delayed(Duration.zero);
      }
    } finally {
      _pumping = false;
    }
  }

  _Job? _take() {
    for (final p in TranslationPriority.values) {
      final queue = _queues[p]!;
      if (queue.isEmpty) continue;
      final key = queue.keys.first;
      return queue.remove(key);
    }
    return null;
  }

  Future<void> _run(_Job job) async {
    final handle = _handles[job.key];
    if (handle == null) return;
    final target = targetLanguage;

    // Steps 1 and 2 repeat what [_settleWithoutModel] already tried
    // synchronously, and they are not dead code: that fast path declines when
    // the disk cache has not been read yet, which is exactly the state the
    // first translation of a session is in. This is where that one lands.
    //
    // ── 1. Already known?
    await TranslationCache.instance.ensureLoaded();
    final cached = TranslationCache.instance.get(job.content, target.code);
    if (cached != null) {
      handle._finish(
        TranslationState.done,
        text: cached,
        sourceLanguage: LanguageDetector.detect(job.content),
      );
      return;
    }

    // ── 2. Already in the right language?
    // The cheap check, and the one that carries the whole room-translate case.
    final detected = LanguageDetector.detect(job.content);
    if (LanguageDetector.isDefinitely(job.content, target.code)) {
      handle._finish(TranslationState.sameLanguage, sourceLanguage: detected);
      return;
    }

    // ── 3. Ask, and keep asking until something passes the contract.
    final result = await _ask(job, handle, target, detected);
    if (result == null) {
      handle._finish(TranslationState.failed);
      return;
    }

    // The model handed the text back unchanged — which the prompt explicitly
    // asks it to do when the text is already in the target language. Reported
    // as such rather than as a translation, so the bubble doesn't show two
    // identical copies of the same sentence.
    if (result.trim() == job.content.trim()) {
      handle._finish(TranslationState.sameLanguage, sourceLanguage: detected);
      return;
    }

    // Not written down when the message it belongs to fades — see
    // [_Job.persist].
    if (job.persist) {
      TranslationCache.instance.put(job.content, target.code, result);
    }
    handle._finish(
      TranslationState.done,
      text: result,
      sourceLanguage: detected,
    );
  }

  /// The retry ladder. Returns the first candidate that passes the contract,
  /// or null when every rung has been tried.
  ///
  /// ── Why a ladder rather than one attempt and a shrug ───────────────────
  ///
  /// A 0.6B model does not reliably do only what it was told, so a single
  /// attempt is a coin flip dressed up as a feature. What made the old version
  /// worse than a coin flip is that the flip was WEIGHTED and then repeated:
  /// generation was fully greedy (see [LoadedBrain.generate]), so a message
  /// that failed failed identically every time it was asked, including when the
  /// reader tapped "translate again".
  ///
  /// Three rungs, each differing from the last in a way that could plausibly
  /// change the answer:
  ///
  ///  1. **Greedy, with the worked examples.** The right sampler for a task
  ///     whose answer is determined by its input, and the prompt most likely to
  ///     produce a bare translation.
  ///  2. **Sampled, terse.** A different draw AND a different prompt. When the
  ///     first pass rambles it is usually because the model latched onto the
  ///     framing rather than the content, so the second one takes the framing
  ///     away and stops asking for the same tokens.
  ///  3. **CPU.** Only when the accelerator has not already been ruled out.
  ///     Output that is not language at all is the signature of a backend the
  ///     device cannot service — see [BrainGateway.demoteToCpu] — and no amount
  ///     of resampling fixes that.
  ///
  /// The rungs are tried in order and stop at the first pass, so the common
  /// case still costs exactly one generation.
  Future<String?> _ask(
    _Job job,
    TranslationHandle handle,
    TranslationLanguage target,
    String? detected,
  ) async {
    TranslationRejection? last;

    for (var rung = 0; rung < _rungs.length; rung++) {
      final settings = _rungs[rung];

      // The CPU rung is not a resample, it is a different machine.
      if (settings.demoteFirst) {
        // Only worth demoting for a failure that looks like the accelerator.
        // A model answering in the wrong language is answering, and it will
        // answer just as wrongly on the CPU — where it will also take several
        // times as long to do it.
        if (last != TranslationRejection.tokenSoup &&
            last != TranslationRejection.markup) {
          return null;
        }
        // False when the fast path was already ruled out on a previous
        // message, in which case there is nothing left to try.
        if (!await BrainGateway.instance.demoteToCpu()) return null;
      }

      final candidate = await _generate(
        job,
        handle,
        target,
        detected,
        terse: settings.terse,
        topK: settings.topK,
        topP: settings.topP,
        temperature: settings.temperature,
        randomSeed: settings.randomSeed,
      );
      _evalAttempts = rung + 1;

      if (candidate == null) {
        last = TranslationRejection.empty;
        continue;
      }

      last = TranslationPrompt.verify(
        candidate,
        source: job.content,
        target: target,
      );
      if (last == null) return candidate;
      if (kDebugMode) {
        // The verdict, never the text. This is somebody's message, and the
        // whole promise of the feature is that it does not get written down
        // anywhere it did not have to be — `BrainGateway` refuses the plugin's
        // verbose level for the same reason.
        debugPrint('Sebastian: rung $rung rejected (${last.name})');
        // The exception, and it is opt-in and off. A verdict alone says which
        // rule fired and nothing about why, which is not enough to fix a
        // prompt with — so this exists for the one situation where somebody is
        // debugging their own build against their own messages. Flip it in a
        // local checkout; never commit it true.
        // ignore: dead_code
        if (kDiagnoseRejections) {
          debugPrint('  candidate: $candidate');
        }
      }
    }
    return null;
  }

  /// The three attempts, in order. Each differs from the one before it in
  /// exactly one dimension, so a failure at rung N says something about rung
  /// N-1 rather than confounding two changes at once.
  static const List<_Rung> _rungs = [
    // Greedy, with the worked examples. The right sampler for a task whose
    // answer is determined by its input.
    _Rung(topK: 1, topP: null, temperature: 0.2, randomSeed: 1, terse: false),
    // A genuinely different DRAW, and a shorter prompt. Top-k of 1 collapses
    // the distribution onto the argmax, so anything narrower than this would
    // re-run the identical computation and reproduce the identical failure —
    // which is exactly what "translate again" used to do.
    _Rung(topK: 40, topP: 0.9, temperature: 0.7, randomSeed: 2, terse: true),
    // A different MACHINE, back on the prompt that works. Reached only for
    // output that was not language at all.
    _Rung(
      topK: 1,
      topP: null,
      temperature: 0.2,
      randomSeed: 1,
      terse: false,
      demoteFirst: true,
    ),
  ];

  /// One pass at translating [job], on whatever backend is currently in force.
  ///
  /// Returns the sanitised candidate, or null when the attempt produced nothing
  /// at all. It does NOT decide whether the candidate is any good — that is
  /// [TranslationPrompt.verify]'s job, and keeping the two apart is what lets
  /// the ladder above react to WHY something failed.
  ///
  /// ── Why nothing is rendered while this runs ────────────────────────────
  ///
  /// This used to sanitise the growing buffer after every token and push the
  /// result into the bubble, so a translation typed itself in. It read well
  /// when it worked and it was the direct cause of the failure everybody
  /// actually saw: [TranslationPrompt.sanitize] can only strip an announcement
  /// that occupies a whole line, and mid-stream there is no second line yet —
  /// so "Okay, the user wants me to translate this…" is not a preamble the
  /// sanitiser can recognise, it is simply the text so far, and it went to the
  /// screen. No prefix-based contract fixes that in general, because the third
  /// token can change how the first two should be read.
  ///
  /// So the bubble now shows the waiting shimmer for the whole generation and
  /// the text arrives once, verified. Chat messages are short; the difference
  /// is a fraction of a second, and what it buys is that nothing unvetted can
  /// reach a reader.
  Future<String?> _generate(
    _Job job,
    TranslationHandle handle,
    TranslationLanguage target,
    String? detected, {
    required bool terse,
    required int topK,
    required double? topP,
    required double temperature,
    required int randomSeed,
  }) async {
    // Announced before `open`, not after: loading the weights and starting the
    // accelerator is where the seconds go, and a bubble that says nothing for
    // that long has already lost the reader. Only when the brain is not
    // already resident — the second translation of a session must not claim to
    // be waking anyone up, and a CPU retry must say so again because it
    // reloads.
    if (BrainGateway.instance.residentBrain?.id != brain.id) {
      handle._finish(TranslationState.warmingUp, sourceLanguage: detected);
    } else {
      // Tokens are moving even though none of them are on screen. The state is
      // what drives the shimmer and the caret, so the bubble still reads as
      // work happening rather than as a stall.
      handle._markWorking(detected);
    }
    final loaded = await BrainGateway.instance.open(brain);
    if (loaded == null) return null;

    final limit = TranslationPrompt.chunkLimitFor(brain, target, brain.family);
    final chunks = TranslationPrompt.chunk(job.content, limit);
    // The retry drops the examples along with the instruction line: if the
    // first pass produced an example rather than a translation, showing it the
    // same examples again is the one change guaranteed not to help.
    final system = TranslationPrompt.system(target, withExamples: !terse);
    final out = StringBuffer();

    for (var i = 0; i < chunks.length; i++) {
      final piece = chunks[i];
      final raw = StringBuffer();
      await for (final token in loaded.generate(
        TranslationPrompt.build(
          piece,
          target,
          family: brain.family,
          terse: terse,
        ),
        systemInstruction: system,
        temperature: temperature,
        topK: topK,
        topP: topP,
        randomSeed: randomSeed,
        // Generous next to the input, because some language pairs genuinely
        // expand — and a cap that truncates mid-sentence produces a confident
        // half-translation, which is worse than a failure.
        maxOutputTokens: _outputBudget(piece),
        stopAt: _rambleGuard(piece),
      )) {
        raw.write(token);
      }
      final clean = TranslationPrompt.sanitize(
        raw.toString(),
        source: piece,
        target: target,
      );
      if (clean == null) return null;
      if (i > 0) out.write('\n');
      out.write(clean);
    }

    final result = out.toString().trim();
    return result.isEmpty ? null : result;
  }

  /// Room for the translation to be longer than the original, with a floor for
  /// very short messages (where a fixed ratio would cap a three-word answer at
  /// nothing) and a ceiling so a runaway generation cannot hold the queue.
  int _outputBudget(String source) {
    final estimate = (source.length / 3).ceil();
    return (estimate * 2).clamp(96, 768);
  }

  /// Stops generation the moment the answer is clearly complete-and-then-some.
  ///
  /// Worth far more than it looks. Left alone, a small model that has finished
  /// translating a one-line message will often carry on — a second attempt, a
  /// note about a word choice, occasionally an unrelated paragraph — and every
  /// token of that is queue time the next message is waiting for.
  ///
  /// Three tests, all shaped to be impossible to trip on a genuine translation:
  ///
  ///  * a blank line, when the source had none. Chat messages that are one
  ///    paragraph translate to one paragraph.
  ///  * running well past a plausible length for the input.
  ///  * the model starting to explain itself. This one is new, and it is the
  ///    one that stops a reasoning model burning the entire token budget: a
  ///    run that has produced text and then opens a `(Note:` or a `Translation:`
  ///    has said everything it is going to say that anyone wants.
  ///
  /// The explanation test deliberately waits for some output first. A model that
  /// opens with `Translation:` is about to answer; one that writes it after
  /// forty characters is about to annotate.
  bool Function(String) _rambleGuard(String source) {
    final sourceHasBlankLine = source.contains('\n\n');
    final ceiling = (source.length * 3).clamp(160, 4000);
    return (soFar) {
      if (!sourceHasBlankLine && soFar.contains('\n\n')) return true;
      if (soFar.length > ceiling) return true;
      // The model has started another fenced exercise instead of finishing
      // this one. See [TranslationPrompt.opensAnotherBlock] — checked here,
      // against the RAW stream, because the sanitiser strips the fence and
      // would hide it.
      if (TranslationPrompt.opensAnotherBlock(soFar)) return true;
      return soFar.length > 40 && _annotationOpener.hasMatch(soFar);
    };
  }

  /// The shapes a model uses to start talking ABOUT its answer.
  ///
  /// Anchored to a line start or an opening bracket so an ordinary sentence
  /// containing "note" is untouched, and matched case-insensitively because
  /// small models are inconsistent about capitalising their own furniture.
  static final RegExp _annotationOpener = RegExp(
    r'(?:^|\n)\s*(?:\(|\[)?(?:note|n\.b\.|literally|lit\.|explanation'
    r'|translation|alternatively|or:)\b',
    caseSensitive: false,
    multiLine: true,
  );

  /// One translation, start to finish, with the ladder's own bookkeeping
  /// exposed. For the golden-set benchmark and nothing else.
  ///
  /// Deliberately bypasses the queue and the cache. Both are correct in the app
  /// — a cached answer is the right answer to show — and both are exactly wrong
  /// in a benchmark, where a second run of the same corpus would score the
  /// first run's results and report that nothing had changed. What it does NOT
  /// bypass is [_ask]: the point of the number is that it describes the
  /// pipeline that ships.
  ///
  /// Returns null text when every rung was refused, which is the same thing the
  /// bubble shows as a failure.
  @visibleForTesting
  Future<({String? text, int attempts})> runOnce(
    String text,
    TranslationLanguage target,
  ) async {
    final handle = TranslationHandle._(text, null);
    final job = _Job(key: 'eval', content: text, persist: false);
    _evalAttempts = 0;
    final result = await _ask(
      job,
      handle,
      target,
      LanguageDetector.detect(text),
    );
    return (text: result, attempts: _evalAttempts);
  }

  /// Rungs spent on the most recent [runOnce]. Only ever written by [_ask], and
  /// only meaningful immediately after one call — this is a benchmark counter,
  /// not state the app reads.
  int _evalAttempts = 0;

  void _bumpProgress(String roomId) {
    final current = _roomProgress[roomId];
    if (current == null) return;
    _roomProgress[roomId] = RoomTranslationProgress(
      done: (current.done + 1).clamp(0, current.total),
      total: current.total,
    );
    notifyListeners();
  }

  // ─────────────────────────── lifecycle ───────────────────────────

  /// Forgets every translation and drops the loaded brain.
  ///
  /// Called when the target language changes (the handles are keyed by the old
  /// one and would never be read again), when Sebastian is switched off, and
  /// when his brain is deleted.
  Future<void> reset({bool clearCache = false}) async {
    for (final queue in _queues.values) {
      queue.clear();
    }
    // Dropped, NOT disposed. A bubble that is on screen right now is an
    // active listener on its handle, and `ChangeNotifier.removeListener`
    // asserts if the notifier was already disposed — so disposing here would
    // crash in debug the moment those bubbles rebuilt and let go. Letting the
    // map's reference die is enough: the registry ping below rebuilds every
    // bubble with a null handle, they drop their listeners on the way out, and
    // the objects are collected.
    //
    // [_pruneHandles] disposes safely because it only ever touches handles
    // with no listeners at all.
    _handles.clear();
    _roomHandles.clear();
    _roomProgress.clear();
    _registry.ping();
    if (clearCache) await TranslationCache.instance.clear();
    await BrainGateway.instance.unload();
    notifyListeners();
  }

  /// Releases the weights without forgetting anything.
  ///
  /// Called when a translating room closes. The brain is several hundred
  /// megabytes of resident memory, and a chat app that keeps it warm forever
  /// is a chat app the OS starts killing in the background.
  ///
  /// Declines while there is still work, which covers two real sequences that
  /// would otherwise unload a brain somebody is using:
  ///
  ///  * Room A → room B, both translating. Flutter disposes the outgoing
  ///    screen AFTER the incoming one is built, so A's dispose would land on
  ///    the brain B has just started using.
  ///  * Leaving a room mid-translation. The in-flight job holds the model.
  Future<void> releaseBrain() async {
    if (_inflight != null) return;
    for (final queue in _queues.values) {
      if (queue.isNotEmpty) return;
    }
    await BrainGateway.instance.unload();
  }
}

/// [ChangeNotifier.notifyListeners] is protected, so the registry needs a type
/// of its own to expose a ping. Deliberately not [ValueNotifier]: there is no
/// value, only the fact that the set changed.
class _HandleRegistry extends ChangeNotifier {
  void ping() => notifyListeners();
}

class _Job {
  const _Job({
    required this.key,
    required this.content,
    required this.persist,
    this.roomId,
  });

  final String key;
  final String content;

  /// Which room's progress bar this job counts towards, or null for a
  /// one-off tap.
  final String? roomId;

  /// Whether the finished translation may be written to the disk cache.
  ///
  /// False for a message that expires. An ephemeral room's entire promise is
  /// that what was said there stops existing, and a cache that quietly kept a
  /// translated copy of it — in the clear, in application support, outliving
  /// the message by however long the LRU holds — would break that promise on
  /// the app's own disk. The translation still happens and still shows; it
  /// simply is not written down, so it dies with the bubble.
  ///
  /// Read off [ChatMessage.expiresAt] rather than off the room, because that
  /// is the field that actually decides whether this text fades, and it is
  /// carried by the message the caller already has.
  final bool persist;
}

/// One attempt's decoding settings. See [Sebastian._rungs].
class _Rung {
  const _Rung({
    required this.topK,
    required this.topP,
    required this.temperature,
    required this.randomSeed,
    required this.terse,
    this.demoteFirst = false,
  });

  final int topK;
  final double? topP;
  final double temperature;
  final int randomSeed;

  /// Drops the worked examples from the turn — see [TranslationPrompt.build].
  final bool terse;

  /// Whether to move to the CPU before this attempt.
  final bool demoteFirst;
}
