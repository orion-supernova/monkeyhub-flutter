/// The app's alert sounds, each with its asset and how it plays.
enum AlertSound {
  /// Incoming call, where the OS has no ringer of its own (web, desktop,
  /// the iOS simulator).
  ringtone('assets/audio/ringtone.mp3', 'audio/mpeg', loop: true),

  /// New message.
  ping('assets/audio/ping.mp3', 'audio/mpeg'),

  /// The caller's "their phone is ringing": one 6 s cycle, a 1 s ring
  /// then 5 s of quiet, cut to open on the ring so it starts the moment
  /// the screen says "ringing".
  ringback('assets/audio/ringback.mp3', 'audio/mpeg', loop: true, inCall: true),

  /// The caller's "they picked up".
  connected('assets/audio/connected.wav', 'audio/wav', inCall: true);

  const AlertSound(
    this.asset,
    this.mime, {
    this.loop = false,
    this.inCall = false,
  });

  final String asset;
  final String mime;
  final bool loop;

  /// Plays inside a live call: through the call's own audio session and
  /// route, never the app's media one. See `AlertSounds._ensureLoaded`.
  final bool inCall;
}
