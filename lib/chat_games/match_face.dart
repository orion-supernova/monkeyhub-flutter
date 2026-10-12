import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../backend/convex_client.dart';
import '../data/matches_store.dart';
import '../widgets/chat_list_row.dart' show MonogramAvatar;
import '../widgets/user_avatar.dart';

/// A seated player's face: their real avatar when the chat repository has
/// them cached (it does, for anyone in the room), else a monogram from the
/// name the seat carries. No status dot — at a game table "online" is what
/// the seat's own ready and away marks already say.
class MatchFace extends StatelessWidget {
  const MatchFace({
    super.key,
    required this.roomId,
    required this.userId,
    required this.name,
    required this.size,
  });

  final String roomId;
  final String userId;
  final String name;
  final double size;

  static final _api = ChatApi(ConvexBackend.instance);

  @override
  Widget build(BuildContext context) {
    final user = MatchesStore.instance.resolveUser?.call(roomId, userId);
    if (user == null) {
      return MonogramAvatar(label: name, seed: userId, size: size);
    }
    return UserAvatar(user: user, size: size, api: _api, showStatus: false);
  }
}
