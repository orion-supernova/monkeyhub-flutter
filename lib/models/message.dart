class Message {
  Message({
    required this.id,
    required this.roomId,
    required this.authorId,
    required this.text,
    required this.createdAt,
    this.ttl,
  });

  final String id;
  final String roomId;
  final String authorId;
  final String text;
  final DateTime createdAt;
  final Duration? ttl; // copy from room.ttl if ephemeral

  bool get isEphemeral => ttl != null;

  DateTime? get expiresAt => ttl == null ? null : createdAt.add(ttl!);

  Duration timeLeft(DateTime now) {
    final exp = expiresAt;
    if (exp == null) return Duration.zero;
    return exp.difference(now);
  }

  double lifeProgress(DateTime now) {
    if (ttl == null) return 0;
    final total = ttl!.inMilliseconds;
    final elapsed = now.difference(createdAt).inMilliseconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }
}
