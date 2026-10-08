import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';

import '../../data/settings_store.dart';
import 'media_ledger.dart';
import 'storage_kinds.dart';

/// Save to Photos: copies incoming photos and videos into the photo library
/// as they are downloaded, per the rules for each kind of chat.
///
/// Rides on the downloads that already happen rather than fetching anything of
/// its own, which is also Telegram's behaviour: what auto-download brings in
/// is what gets saved. Each blob is saved once ([LedgerEntry.saved]), however
/// often its file is evicted and fetched again.
///
/// Never asks for photo access itself. A permission prompt appearing out of
/// nowhere while someone scrolls a chat would be baffling; the toggle that
/// turns this on asks instead (see [ensureAccess]), and if access is later
/// revoked this quietly does nothing.
class GalleryAutoSave {
  GalleryAutoSave._();
  static final GalleryAutoSave instance = GalleryAutoSave._();

  bool _wants(LedgerEntry e, {required bool video, int? bytes}) {
    if (kIsWeb || !e.incoming || e.saved || e.roomId == null) return false;
    final rule = SettingsStore.instance.dataPrefs
        .saveIn(MediaLedger.instance.classOf(e));
    if (!video) return rule.photos;
    return rule.videos && (bytes == null || bytes <= rule.maxVideoBytes);
  }

  Future<void> offerPhoto(
      LedgerEntry e, Future<String?> Function() path) async {
    if (!_wants(e, video: false)) return;
    try {
      if (!await Gal.hasAccess(toAlbum: false)) return;
      final p = await path();
      if (p == null) return;
      await Gal.putImageBytes(await File(p).readAsBytes(),
          name: 'monkeyhub-${e.messageId ?? e.id}');
      MediaLedger.instance.markSaved(e.id);
    } catch (err) {
      debugPrint('auto-save photo ${e.id} failed: $err');
    }
  }

  Future<void> offerVideo(LedgerEntry e, String path) async {
    // The cheap checks first, so the common case (saving off) never touches
    // the file at all.
    if (e.kind != StorageKind.videos || !_wants(e, video: true)) return;
    try {
      final bytes = await File(path).length();
      if (!_wants(e, video: true, bytes: bytes)) return;
      if (!await Gal.hasAccess(toAlbum: false)) return;
      await Gal.putVideo(path);
      MediaLedger.instance.markSaved(e.id);
    } catch (err) {
      debugPrint('auto-save video ${e.id} failed: $err');
    }
  }

  /// Asks for photo library access, for the toggle that turns saving on.
  /// True when access is (now) granted.
  static Future<bool> ensureAccess() async {
    if (kIsWeb) return false;
    try {
      if (await Gal.hasAccess(toAlbum: false)) return true;
      return await Gal.requestAccess(toAlbum: false);
    } catch (_) {
      return false;
    }
  }
}
