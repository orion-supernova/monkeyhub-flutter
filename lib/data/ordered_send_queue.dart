import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

/// Sends that do slow work in parallel but land strictly in the order they
/// were made: the attachment queue of [ChatRepository].
///
/// Each send is two steps. The UPLOAD runs as soon as one of [slots] is free,
/// alongside others. The POST waits for every earlier send's post to finish
/// first, so a run of photos reaches the server, and the other side, in the
/// order they were picked however their uploads happen to finish.
///
/// An upload that reports false (discarded, cancelled, failed) skips its post
/// and does not hold up the sends after it.
class OrderedSendQueue {
  OrderedSendQueue({this.slots = 3});

  /// Uploads allowed to move at once. Enough overlap to hide each one's round
  /// trip; few enough that ten photos are not ten arcs splitting one uplink.
  final int slots;

  int _busy = 0;
  final Queue<Completer<void>> _waiting = Queue();
  Future<void> _posts = Future.value();

  /// Queues one send. Completes when its post has run (or been skipped).
  ///
  /// The `catchError`s are load-bearing despite looking like belt-and-braces
  /// over steps that handle their own failures. A rejected future at the tail
  /// of a `then` chain makes every later callback skip, so one unexpected
  /// throw would silently stop every attachment for the rest of the session.
  /// Anything arriving there is a bug rather than a send failure, and a bug
  /// must not be able to wedge the queue.
  Future<void> add({
    required Future<bool> Function() upload,
    required Future<void> Function() post,
  }) {
    final uploaded = _inSlot(upload).catchError((Object e) {
      debugPrint('upload step threw (continuing): $e');
      return false;
    });
    _posts = _posts.then((_) async {
      if (await uploaded) await post();
    }).catchError((Object e) {
      debugPrint('post step threw (continuing): $e');
    });
    return _posts;
  }

  Future<T> _inSlot<T>(Future<T> Function() job) async {
    if (_busy >= slots) {
      final turn = Completer<void>();
      _waiting.add(turn);
      await turn.future;
    } else {
      _busy++;
    }
    try {
      return await job();
    } finally {
      // Hand the slot straight to the next in line, or give it back.
      if (_waiting.isNotEmpty) {
        _waiting.removeFirst().complete();
      } else {
        _busy--;
      }
    }
  }
}
