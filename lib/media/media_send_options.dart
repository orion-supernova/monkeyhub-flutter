import 'package:flutter/foundation.dart';

/// What a send of pictures decides besides the pictures themselves: one
/// look only, hidden under spoiler dust, full resolution.
///
/// ONE model for every way a picture leaves the app. The camera's composer
/// keeps one on its `EditorDraft`; the chat's inline photo picker keeps one
/// for its picks, and hands that same instance to the composer when a pick
/// is opened, so a switch flipped in the preview is the switch the strip
/// sends with. Two copies of these three flags is how the gallery's preview
/// ended up with none of them.
///
/// All three are decisions about the whole send, never about one picture of
/// it, exactly as view-once always was.
class MediaSendOptions extends ChangeNotifier {
  MediaSendOptions({bool hd = false}) : _hd = hd;

  bool _viewOnce = false;
  bool _spoiler = false;
  bool _hd;

  /// Burn after reading: each recipient may open it once, then the file is
  /// deleted. Captions are dropped while armed (a message's text outlives
  /// its photo).
  bool get viewOnce => _viewOnce;
  set viewOnce(bool v) {
    if (v == _viewOnce) return;
    _viewOnce = v;
    notifyListeners();
  }

  /// Sent as a spoiler: blurred under dust for everyone until tapped. Can be
  /// armed with [viewOnce]; the seal wins and this dresses the one look.
  bool get spoiler => _spoiler;
  set spoiler(bool v) {
    if (v == _spoiler) return;
    _spoiler = v;
    notifyListeners();
  }

  /// Full resolution instead of the capped default. Off at the start of
  /// every send, on every platform, and never remembered: one HD send does
  /// not make the next one HD.
  ///
  /// Off is the point. A phone camera photo is ~5 MB at full size, and a
  /// room multiplies it: every member fetches the blob from storage with no
  /// CDN in front, so one photo into a room of four is ~25 MB moved. Capped,
  /// the same photo is ~150 KB (see `kSendPhotoMaxEdge`). It used to stick
  /// once turned on, and quietly kept every later photo at full size.
  bool get hd => _hd;
  set hd(bool v) {
    if (v == _hd) return;
    _hd = v;
    notifyListeners();
  }

  /// After a send: every decision goes back off for the next one.
  void reset() {
    if (!_viewOnce && !_spoiler && !_hd) return;
    _viewOnce = false;
    _spoiler = false;
    _hd = false;
    notifyListeners();
  }
}
