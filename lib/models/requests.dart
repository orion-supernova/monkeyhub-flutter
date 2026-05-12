enum RequestStatus { pending, accepted, declined }

class FriendRequest {
  FriendRequest({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.sentAt,
    this.note,
    this.status = RequestStatus.pending,
  });

  final String id;
  final String fromUserId;
  final String toUserId;
  final DateTime sentAt;
  final String? note;
  RequestStatus status;
}

class RoomInvite {
  RoomInvite({
    required this.id,
    required this.roomId,
    required this.fromUserId,
    required this.toUserId,
    required this.sentAt,
    this.status = RequestStatus.pending,
  });

  final String id;
  final String roomId;
  final String fromUserId;
  final String toUserId;
  final DateTime sentAt;
  RequestStatus status;
}
