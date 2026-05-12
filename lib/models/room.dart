enum RoomVisibility { public, private }

enum RoomType { standard, ephemeral }

class Room {
  Room({
    required this.id,
    required this.name,
    required this.visibility,
    required this.type,
    required this.memberIds,
    this.ttl,
    this.description,
    this.topic,
  });

  final String id;
  String name;
  String? description;
  String? topic;
  RoomVisibility visibility;
  RoomType type;
  Duration? ttl; // null unless ephemeral
  final List<String> memberIds;

  bool get isEphemeral => type == RoomType.ephemeral;
  bool get isPublic => visibility == RoomVisibility.public;
}
