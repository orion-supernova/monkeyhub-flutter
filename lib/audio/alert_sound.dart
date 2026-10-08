/// The app's alert sounds, each with its asset and how it plays.
enum AlertSound {
  /// Incoming call, where the OS has no ringer of its own (web, desktop,
  /// the iOS simulator).
  ringtone('assets/audio/ringtone.mp3', 'audio/mpeg', loop: true),

  /// New message.
  ping('assets/audio/ping.mp3', 'audio/mpeg'),

  /// The caller's "their phone is ringing": 425 Hz, 1 s on, 4 s off.
  ringback('assets/audio/ringback.wav', 'audio/wav', loop: true),

  /// The caller's "they picked up".
  connected('assets/audio/connected.wav', 'audio/wav');

  const AlertSound(this.asset, this.mime, {this.loop = false});

  final String asset;
  final String mime;
  final bool loop;
}
