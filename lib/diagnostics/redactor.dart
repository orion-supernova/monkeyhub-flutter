import 'dart:convert';

/// How much of a Convex call's payload may be recorded.
enum ArgPolicy {
  /// Values verbatim. Granted only to calls that carry nothing private.
  full,

  /// Keys and value SHAPES only: `{roomId: <str:32>, content: <str:142>}`.
  /// The default, and what makes this safe by construction.
  keysOnly,

  /// Nothing but a size summary. For payloads that are private in bulk even
  /// as shapes — message history, mostly.
  drop,
}

/// Turns Convex arguments and results into something safe to write to disk.
///
/// The reference implementation this feature is modelled on has no redaction at
/// all: it records `Authorization: Bearer <jwt>` and plaintext login passwords
/// verbatim, then renders them in a screen and copies them to the clipboard.
/// Copying that here would be materially worse than it is there. This is a
/// KIDS' chat app — it ships ephemeral rooms, view-once media and FLAG_SECURE
/// screenshot blocking precisely so that message content does not escape, and a
/// diagnostics file that quietly carries that content out through a share sheet
/// defeats every one of those features at once.
///
/// So the design inverts the usual one. There is no denylist of dangerous
/// functions to keep up to date; there is an allowlist of harmless ones, and
/// everything else — including every function anybody adds next month — is
/// [ArgPolicy.keysOnly] automatically. Being wrong then costs a less useful log
/// line, not a leak.
///
/// All three layers run BEFORE a `DiagEvent` is constructed, so no code path
/// exists on which the buffer holds a secret even briefly.
class Redactor {
  const Redactor._();

  /// Bump when the rules change; it is printed in the export header so a log
  /// can be read against the rules that produced it.
  static const String version = 'v1';

  /// Layer 1: per-function policy.
  ///
  /// `full` is granted only where the arguments and the result are both public
  /// or trivially non-identifying. Everything absent from this map is
  /// [ArgPolicy.keysOnly] — see [policyFor].
  static const Map<String, ArgPolicy> _policies = {
    // No arguments worth hiding, and the result is a public version manifest.
    'releases:latest': ArgPolicy.full,
    // userId only, and the timing of these IS the presence-churn evidence.
    'users:heartbeat': ArgPolicy.full,
    'users:updateStatus': ArgPolicy.full,
    'typing:setTyping': ArgPolicy.full,
    'typing:list': ArgPolicy.full,
    // Room/message ids and counts. Ids are opaque and the shape is the signal.
    'messages:markRoomRead': ArgPolicy.full,
    'messages:markRoomDelivered': ArgPolicy.full,
    'rooms:listRooms': ArgPolicy.keysOnly,

    // ---- Credential-equivalent. The server COMPARES these hashes, so logging
    // one is logging the password it was derived from. ----
    'auth:signup': ArgPolicy.drop,
    'auth:login': ArgPolicy.drop,
    'auth:resetPasswordWithRecoveryKey': ArgPolicy.drop,
    'auth:setRecoveryKey': ArgPolicy.drop,
    'auth:changePassword': ArgPolicy.drop,
    'socialAuth:signInWithApple': ArgPolicy.drop,
    'socialAuth:signInWithGoogle': ArgPolicy.drop,
    'socialAuth:linkApple': ArgPolicy.drop,
    'socialAuth:linkGoogle': ArgPolicy.drop,
    'family:createChildAccount': ArgPolicy.drop,
    'family:releaseDeviceByGuardianPassword': ArgPolicy.drop,
    'rooms:create': ArgPolicy.drop,
    'rooms:join': ArgPolicy.drop,
    'rooms:updatePassword': ArgPolicy.drop,

    // ---- Account-takeover codes. Short-lived, but a code in a shared log
    // file is a code somebody can still use. ----
    'family:createPairingCode': ArgPolicy.drop,
    'family:redeemPairingCode': ArgPolicy.drop,
    'family:createReleaseCode': ArgPolicy.drop,
    'family:releaseDeviceByCode': ArgPolicy.drop,

    // ---- Children's message content. ----
    'messages:send': ArgPolicy.drop,
    'messages:forwardToRoom': ArgPolicy.drop,
    // Both spellings: `messages:edit` predates the mutation (it was written
    // speculatively, and the mutation shipped as `editMessage`). The stale
    // name stays because deleting a deny-rule to tidy a table is how a
    // rename quietly starts logging message text.
    'messages:edit': ArgPolicy.drop,
    'messages:editMessage': ArgPolicy.drop,
    'friends:createDirectRequest': ArgPolicy.drop,
    'friends:appendDirectRequestMessage': ArgPolicy.drop,

    // ---- Message HISTORY in the result. The arguments are innocuous, which is
    // exactly the trap: a naive logger records the arguments and then writes
    // the entire returned conversation next to them. ----
    'messages:list': ArgPolicy.drop,
    'messages:listAfter': ArgPolicy.drop,
    'messages:listBefore': ArgPolicy.drop,
    'messages:listAround': ArgPolicy.drop,
    'messages:getThread': ArgPolicy.drop,
    'messages:getThreadPage': ArgPolicy.drop,
    'roomContent:list': ArgPolicy.drop,

    // ---- Capability URLs: a signed storage URL in a log is a live download
    // link to somebody's photo. ----
    'files:getFileUrl': ArgPolicy.drop,
    'files:generateUploadUrl': ArgPolicy.drop,

    // ---- The problem report itself, which is free text a user typed plus a
    // list of storage ids for their own screenshots. `body` is already a denied
    // key at layer 2, but the policy is stated anyway because the leak here is
    // recursive rather than obvious: every report attaches the current log, so
    // an argument recorded on this call is an argument re-sent inside the NEXT
    // report — and a second reporter's screenshot ids would ride along with it.
    'problemReports:submit': ArgPolicy.drop,

    // ---- Device-takeover: a push token lets somebody ring this handset. ----
    'voipTokens:registerDevice': ArgPolicy.drop,
    'voipTokens:setVoipToken': ArgPolicy.drop,
    'voipTokens:setFcmToken': ArgPolicy.drop,
  };

  /// Functions that MUST have an explicit policy. The test asserts this list is
  /// covered, so adding `auth:somethingNew` without deciding its policy fails
  /// the suite rather than shipping a leak.
  static const List<String> sensitivePrefixes = [
    'auth:',
    'socialAuth:',
    'family:',
    'files:',
    'voipTokens:',
    'idToken:',
    'appleTokens:',
  ];

  /// Layer 2: key names whose VALUE is never recorded, at any depth, in
  /// arguments or in results, regardless of the function's policy.
  static const Set<String> _deniedKeys = {
    // credentials
    'password', 'passwordhash', 'newpassword', 'newpasswordhash',
    'recoverykey', 'recoverykeyhash', 'recoveryphrase', 'phrase', 'mnemonic',
    'secret', 'clientsecret', 'devicesecret',
    // tokens
    'token', 'idtoken', 'identitytoken', 'accesstoken', 'refreshtoken',
    'voiptoken', 'fcmtoken', 'apnstoken', 'authorization', 'authorizationcode',
    // The session bearer, which `ConvexBackend` now attaches to EVERY
    // authenticated call — so it passes through this redactor more often than
    // anything else here. Layer 3's opaque-string rule would also catch a
    // 64-hex token, but relying on that would make the most common credential
    // in the app the one secret with no name on the list.
    'sessiontoken',
    'jwt', 'nonce', 'rawnonce',
    // codes
    'code', 'pairingcode', 'releasecode', 'otp',
    // content
    'content', 'text', 'body', 'message', 'initialmessage', 'caption',
    'transcript', 'preview',
    // identifiers and PII
    'email', 'username', 'displayname', 'name', 'peername', 'avatarurl',
    'bio', 'birthyear', 'phone', 'address',
    // capability URLs
    'url', 'downloadurl', 'uploadurl', 'signedurl', 'fileurl',
  };

  /// Layer 3: value shapes that are secrets wherever they appear, catching a
  /// credential that arrives under a key nobody predicted.
  static final RegExp _jwt = RegExp(r'eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}');
  static final RegExp _bearer = RegExp(r'Bearer\s+\S+', caseSensitive: false);
  static final RegExp _longOpaque = RegExp(r'\b[A-Za-z0-9+/_-]{40,}={0,2}\b');

  static ArgPolicy policyFor(String functionName) =>
      _policies[functionName] ?? ArgPolicy.keysOnly;

  /// Renders [args] for the call [functionName] as a string safe to persist.
  /// Returns null when there is nothing worth recording.
  static String? args(String functionName, Map<String, dynamic> args) {
    if (args.isEmpty) return null;
    switch (policyFor(functionName)) {
      case ArgPolicy.drop:
        return '<${args.length} args withheld>';
      case ArgPolicy.keysOnly:
        return _encode(_walk(args, valuesAllowed: false));
      case ArgPolicy.full:
        return _encode(_walk(args, valuesAllowed: true));
    }
  }

  /// Renders a call RESULT. Same policy table — deliberately, because for the
  /// message-history calls the arguments are innocuous and the result is the
  /// entire conversation.
  static String? result(String functionName, Object? value) {
    if (value == null) return null;
    switch (policyFor(functionName)) {
      case ArgPolicy.drop:
        return _summarise(value);
      case ArgPolicy.keysOnly:
        return _encode(_walk(value, valuesAllowed: false));
      case ArgPolicy.full:
        return _encode(_walk(value, valuesAllowed: true));
    }
  }

  /// Scrubs a free-text line (a captured `debugPrint`, an exception message).
  /// Only layer 3 applies — there are no keys to reason about.
  static String text(String raw) => _scrubText(raw);

  /// A size-only description, for [ArgPolicy.drop].
  static String _summarise(Object? v) {
    if (v is List) return '<list:${v.length} withheld>';
    if (v is Map) return '<map:${v.length} withheld>';
    if (v is String) return '<str:${v.length} withheld>';
    return '<${v.runtimeType} withheld>';
  }

  /// Recursive walk applying layers 2 and 3.
  ///
  /// Replacements are SHAPE-PRESERVING (`<str:142>`, not `***`) on purpose: it
  /// keeps the log diagnostic. "The send failed because content was
  /// `<str:0>`" is an answer; "content was ***" is not.
  static Object? _walk(
    Object? v, {
    required bool valuesAllowed,
    int depth = 0,
  }) {
    // Convex documents nest shallowly; a cycle or a pathological depth must not
    // hang the app that is already misbehaving.
    if (depth > 8) return '<deep>';

    if (v == null) return null;

    if (v is Map) {
      final out = <String, Object?>{};
      v.forEach((k, val) {
        final key = k.toString();
        if (_deniedKeys.contains(key.toLowerCase())) {
          out[key] = _shape(val);
        } else {
          out[key] = _walk(val, valuesAllowed: valuesAllowed, depth: depth + 1);
        }
      });
      return out;
    }

    if (v is List) {
      // Long lists are summarised rather than walked: a 500-message page would
      // otherwise blow the byte budget on its own even fully redacted.
      if (v.length > 12) return '<list:${v.length}>';
      return [
        for (final e in v)
          _walk(e, valuesAllowed: valuesAllowed, depth: depth + 1),
      ];
    }

    if (v is String) {
      if (!valuesAllowed) return _shape(v);
      return _scrubText(v);
    }

    // Numbers and bools carry no secrets and are frequently the whole point
    // (counts, timestamps, flags), so they survive even under keysOnly.
    return v;
  }

  static String _shape(Object? v) {
    if (v == null) return '<null>';
    if (v is String) return '<str:${v.length}>';
    if (v is List) return '<list:${v.length}>';
    if (v is Map) return '<map:${v.length}>';
    if (v is bool) return '<bool>';
    if (v is num) return '<num>';
    return '<${v.runtimeType}>';
  }

  static String _scrubText(String s) => s
      .replaceAll(_jwt, '<redacted jwt>')
      .replaceAll(_bearer, '<redacted bearer>')
      .replaceAllMapped(
        _longOpaque,
        (m) => '<redacted opaque:${m.group(0)!.length}>',
      );

  static String _encode(Object? v) {
    try {
      return jsonEncode(v);
    } catch (_) {
      // Something non-encodable slipped in. Its toString could be anything, so
      // scrub it rather than trusting it.
      return _scrubText(v.toString());
    }
  }
}
