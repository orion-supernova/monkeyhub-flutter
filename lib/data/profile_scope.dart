import 'package:flutter/widgets.dart';

import '../l10n/generated/app_localizations.dart';
import 'profile_cache.dart';

/// Puts a [ProfileCache] in the tree. Dependents rebuild when profiles load or
/// change (notifications are batched, once per fetch).
class ProfileScope extends InheritedNotifier<ProfileCache> {
  const ProfileScope({
    super.key,
    required ProfileCache cache,
    required super.child,
  }) : super(notifier: cache);

  /// The nearest cache, registering a dependency; null with no scope above.
  static ProfileCache? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ProfileScope>()?.notifier;
}

/// Neutral stand-in when neither a profile nor a copy has a name.
const String kProfileNamePlaceholder = '…';

extension ProfileContext on BuildContext {
  /// The live display name of [userId].
  ///
  /// Resolution: a deleted account is the localized "Deleted account"; else
  /// the cached profile name; else [fallback] (the copy stored on the message
  /// or moment); else a neutral placeholder. With no [ProfileScope] above, or
  /// in legacy mode, this is just [fallback].
  String profileName(String userId, {String fallback = ''}) {
    final cache = ProfileScope.maybeOf(this);
    String orPlaceholder(String s) => s.isEmpty ? kProfileNamePlaceholder : s;
    if (cache == null) return orPlaceholder(fallback);
    if (cache.isDeleted(userId)) {
      return AppLocalizations.of(this).profileDeletedAccount;
    }
    return orPlaceholder(cache.nameFor(userId, fallback: fallback));
  }

  /// The live avatar blob of [userId], or [fallback].
  String? profileAvatar(String userId, {String? fallback}) {
    final cache = ProfileScope.maybeOf(this);
    if (cache == null) return fallback;
    return cache.avatarFor(userId, fallback: fallback);
  }

  /// The live `@username` of [userId], or [fallback].
  String profileUsername(String userId, {String fallback = ''}) {
    final cache = ProfileScope.maybeOf(this);
    if (cache == null) return fallback;
    return cache.usernameFor(userId, fallback: fallback);
  }
}
