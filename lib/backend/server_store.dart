import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/any_class_keychain.dart';
import '../env.dart';
import 'server_directory.dart';
import 'server_endpoint.dart';

/// Which backend this install talks to, and the short history of the ones it
/// has talked to before.
///
/// Sits between [Env] and every consumer of a backend URL. `env.local` still
/// carries the deployment a normal install ships pointed at; this store holds
/// the override a self-hoster set, and answers "which one is live" for the
/// Convex client, the HTTP-action URL builder and the diagnostics header.
///
/// Loaded from [load] in `main()` alongside [SettingsStore], BEFORE `runApp` —
/// the client is built from [deploymentUrl] during the first bootstrap, so a
/// value that arrives one frame late would connect to the wrong server and
/// need tearing down again.
///
/// Kept OUT of `SettingsStore` deliberately. Everything in that class is a
/// preference: getting it wrong changes how the app looks. Getting this wrong
/// changes which server holds your messages, and it is the one setting that
/// has to be readable and writable while the app is in a state where nothing
/// else works — a failed boot, an empty `env.local`, a deployment that moved.
class ServerStore extends ChangeNotifier {
  ServerStore._();
  static final ServerStore instance = ServerStore._();

  static const _kUrl = 'mh.server.url';
  static const _kSiteUrl = 'mh.server.siteUrl';
  static const _kRecent = 'mh.server.recent';

  /// Whether the stored URL was typed in rather than followed to. Its own key
  /// because it cannot be recovered from the URL: the address is identical
  /// either way — see [isPinned].
  static const _kPinned = 'mh.server.pinned';
  static const _kUnlocked = 'mh.server.toolsUnlocked';

  /// `first_unlock`, like the preferences: readable on a locked launch, so a
  /// VoIP cold start on a locked phone connects to the server this install
  /// actually uses instead of the bundled default. This is not a secret — a
  /// deployment URL is public by nature — but keeping one storage backend for
  /// everything means one failure mode to reason about instead of two.
  ///
  /// Through [AnyClassKeychain], because older builds wrote these under
  /// `unlocked` and 1.3.105's settings migration swept them into `first_unlock`
  /// behind this store's back — which read nothing, and failed every write
  /// with errSecDuplicateItem.
  final _storage = const AnyClassKeychain(
    FlutterSecureStorage(
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    ),
  );

  ServerEndpoint? _custom;
  bool _pinned = false;
  List<ServerEndpoint> _recent = const [];
  bool _loaded = false;

  /// How many past servers the picker offers. Small on purpose: this is a
  /// convenience for someone flipping between a home box and a VPS, not a
  /// history feature.
  static const int maxRecent = 5;

  bool get loaded => _loaded;

  /// The endpoint the user configured, or null when running on the bundled one.
  ServerEndpoint? get custom => _custom;

  /// Whether this install is pointed somewhere other than the shipped default.
  /// Drives the permanent badge and the accent on the settings row.
  bool get isCustom => _custom != null;

  /// Whether the user put this app on this server themselves.
  ///
  /// The one fact that separates "the operator moved everyone onto the home
  /// server" from "I typed that address into the server screen", and it is not
  /// recoverable afterwards: both end up on the same host, with the same URL,
  /// in the same field. So it is recorded at the moment the choice is made and
  /// stored beside the URL.
  ///
  /// Without it, entering a managed address by hand produced an install that
  /// wore the operator's homeserver bar, was described everywhere as a
  /// temporary arrangement it had not agreed to, and was moved off again by
  /// the next directive — an install indistinguishable from one that had been
  /// sent there, which is the opposite of what typing an address in means.
  ///
  /// A pin is only meaningful with a custom server: returning to the bundled
  /// default is not a pin, it is the absence of one.
  bool get isPinned => _pinned && _custom != null;

  /// The deployment the app shipped pointed at, or `''` when `env.local`
  /// carries no `CONVEX_URL`.
  ///
  /// Empty is a supported build: a source build with no bundled backend is
  /// exactly what a self-hoster-only distribution looks like, and the app
  /// handles it by opening on the server screen instead of failing to boot.
  String get bundledUrl => Env.convexUrl;

  /// Whether a bundled default exists to fall back to. False makes "use the
  /// default" meaningless, so the UI hides that choice entirely.
  bool get hasBundled => bundledUrl.isNotEmpty;

  /// The endpoint standing for the bundled default, or null when there isn't
  /// one. Uses [Env.convexSiteUrl] as the override so a cloud/self-host split
  /// declared in `env.local` is honoured rather than re-derived.
  ServerEndpoint? get bundled {
    if (!hasBundled) return null;
    final site = Env.convexSiteUrl;
    return ServerEndpoint(
      deploymentUrl: bundledUrl,
      siteUrlOverride: site == bundledUrl ? null : site,
    );
  }

  /// The endpoint everything actually talks to right now.
  ServerEndpoint? get active => _custom ?? bundled;

  /// The Convex deployment URL in force. `''` only when there is neither a
  /// custom server nor a bundled one — the state `_bootstrap` reads as "ask
  /// the user where to connect".
  String get deploymentUrl => active?.deploymentUrl ?? '';

  /// Origin serving HTTP actions for [deploymentUrl].
  String get siteUrl => active?.siteUrl ?? '';

  /// Host only, for the badge, the settings row and the diagnostics header.
  String get host => active?.host ?? '';

  /// What kind of backend this is: the ordinary one, the operator's home
  /// server, or somebody's own.
  ///
  /// Not the same question as [isCustom], and the difference matters. Following
  /// a directive onto the home server writes a custom URL, so `isCustom` is
  /// true there too — but a home server is a replicated copy of the primary,
  /// while a self-hosted address is a different world with different accounts.
  /// The badge, the info sheet and [ServerSwitch] all branch on this, never on
  /// `isCustom`.
  ///
  /// An address the user pinned is [ServerRole.selfHosted] whatever host it
  /// names. The role answers "how did this app come to be here", and for a
  /// pinned server the answer is "somebody chose it" — which is the same answer
  /// as for a private box, and carries the same consequences: the address is
  /// theirs to see, and nobody's directive moves them off it.
  ServerRole get role =>
      isPinned ? ServerRole.selfHosted : KnownHosts.roleOf(deploymentUrl);

  /// Whether this install has anything to say about which server it is on.
  ///
  /// False on the ordinary deployment, and false when there is no server at
  /// all — a build that has not yet been told where to connect has not
  /// connected anywhere unusual, and an empty address classifies as
  /// [ServerRole.selfHosted] only because it parses as no known host. Without
  /// this, the onboarding screen wore a badge announcing a self-hosted server
  /// whose name was the empty string.
  ///
  /// One definition rather than the same two-part condition at the badge and
  /// at the badge-style picker, which is exactly the pair that would drift.
  bool get announcesRole =>
      deploymentUrl.isNotEmpty && role != ServerRole.primary;

  /// Whether the user chose this server, as opposed to being moved to it.
  ///
  /// **This, not [isCustom], is what the UI branches on.** Following a
  /// directive onto the home server writes a custom URL, so `isCustom` is true
  /// there — but nobody picked it, it is temporary, and it is still "the
  /// server this app uses" rather than "a server you added". Reading `isCustom`
  /// is what made Settings present a homeserver follow as a self-hosting
  /// choice, complete with the address sitting in the edit field.
  ///
  /// The address is only ever shown for one of these. An operator's deployment
  /// URLs are infrastructure, not something to publish across every user's
  /// settings screen; a server someone typed in themselves is theirs to see.
  bool get isSelfHosted => role == ServerRole.selfHosted;

  /// Whether a published directive is allowed to move this install.
  ///
  /// The single condition [ServerDirectory] and [ServerSwitch.follow] ask,
  /// rather than [KnownHosts.isManaged] on the raw URL: that answers whether
  /// the ADDRESS is one of the two the operator runs, which stopped being the
  /// whole question the moment a user could type one of them in.
  ///
  /// False on an install that has no server at all — there is nothing to be
  /// moved from, and the empty address is nobody's deployment.
  bool get followsDirectives => !isSelfHosted;

  /// Previously-used custom servers, newest first. Never contains the active
  /// one — it is shown separately — and never contains the bundled default.
  List<ServerEndpoint> get recent => List.unmodifiable(_recent);

  bool _unlocked = false;

  /// Whether the server picker is offered at all.
  ///
  /// A store build hides it: App Review reads a "point the app at any server"
  /// screen, shown before sign-in, as a way around the moderation the review
  /// is checking. It stays reachable for the people who use it: debug builds,
  /// anyone already on a non-default server (so they can always get back), and
  /// anyone who opened Diagnostics through the version stamp's hidden taps,
  /// which calls [unlockTools].
  bool get showsServerTools =>
      kDebugMode || _unlocked || role != ServerRole.primary;

  /// Remembers that this install asked for the server tools.
  Future<void> unlockTools() async {
    if (_unlocked) return;
    _unlocked = true;
    notifyListeners();
    try {
      await _storage.write(key: _kUnlocked, value: '1');
    } catch (_) {/* best effort; unlocked for this run regardless */}
  }

  Future<void> load() async {
    if (_loaded) return;
    try {
      final url = await _storage.read(key: _kUrl);
      if (url != null && url.isNotEmpty) {
        final site = await _storage.read(key: _kSiteUrl);
        _custom = ServerEndpoint(
          deploymentUrl: url,
          siteUrlOverride: site == null || site.isEmpty ? null : site,
        );
        // Absent means "followed here", which is what every install written by
        // a build older than the pin holds. That is the right reading for all
        // but one of them: an install already sitting on a hand-typed managed
        // address keeps behaving as it did until the address is entered again.
        _pinned = await _storage.read(key: _kPinned) == '1';
      }
      _recent = ServerEndpoint.decodeList(await _storage.read(key: _kRecent));
      _unlocked = await _storage.read(key: _kUnlocked) == '1';
    } catch (_) {
      /* secure storage unavailable in the test harness — bundled default */
    }
    _loaded = true;
    notifyListeners();
  }

  /// Point this install at [endpoint].
  ///
  /// Storage-only: it does NOT rebuild the Convex client or tear down the
  /// session. [ServerSwitch] owns that sequence, and calls this in the middle
  /// of it. Calling this directly is what a rollback does — see
  /// [ServerSwitch.apply].
  ///
  /// [pinned] says who decided: true for an address a person entered, false
  /// for one the app was directed onto. It defaults to true because that is
  /// the safe direction — a caller that forgets leaves an install nobody may
  /// relocate, which is a smaller mistake than silently making somebody's
  /// deliberate choice followable. Only the directive paths pass false, and
  /// they say why where they do.
  Future<void> use(ServerEndpoint endpoint, {bool pinned = true}) async {
    // The pin is part of the state: arriving at the address already in force,
    // but for a different reason, is a real change.
    if (_custom == endpoint && _pinned == pinned) return;
    // The server being replaced earns a place in the history, so switching
    // back is one tap. The bundled default never does — it has its own card.
    final leaving = _custom;
    _custom = endpoint;
    _pinned = pinned;
    _recent = _rememberedAfter(leaving: leaving, arriving: endpoint);
    notifyListeners();
    await _persist();
  }

  /// Adopt the server already in force as the user's own choice.
  ///
  /// What it means to type the current address into the server screen: the app
  /// is not going anywhere — it is already here — but it stops being here
  /// because it was sent and starts being here because somebody said so. The
  /// difference shows up at the next directive, which no longer applies.
  ///
  /// Separate from [use] because there is nothing to switch: no teardown, no
  /// sign-out, no new socket. See [ServerSwitch.apply], which routes exactly
  /// that case here.
  Future<void> pin() async {
    if (_custom == null || _pinned) return;
    _pinned = true;
    notifyListeners();
    await _persist();
  }

  /// Go back to the deployment the app shipped with.
  ///
  /// Also the way off a pin: the bundled deployment is the ordinary
  /// arrangement, and an install on it follows directives like any other.
  Future<void> useBundled() async {
    if (_custom == null) return;
    final leaving = _custom;
    _custom = null;
    _pinned = false;
    _recent = _rememberedAfter(leaving: leaving, arriving: null);
    notifyListeners();
    await _persist();
  }

  /// Drop [endpoint] from the history. The active server is not in the history,
  /// so this can never disconnect anyone.
  Future<void> forget(ServerEndpoint endpoint) async {
    if (!_recent.contains(endpoint)) return;
    _recent = [..._recent]..remove(endpoint);
    notifyListeners();
    await _persist();
  }

  /// The history after a move from [leaving] to [arriving]: the departed server
  /// goes on the front, the arriving one comes off (it is the active card now),
  /// and the tail past [maxRecent] falls away.
  List<ServerEndpoint> _rememberedAfter({
    required ServerEndpoint? leaving,
    required ServerEndpoint? arriving,
  }) {
    final next = [..._recent];
    next.removeWhere((e) => e == arriving);
    // The primary and the home server are never history. They are not servers
    // anyone chose — the app moves between them on a directive — and listing
    // them under "recent" in the self-hosting picker would offer someone a
    // one-tap route onto the operator's home server, which is not a server
    // they are meant to pick.
    if (leaving != null &&
        leaving != arriving &&
        !KnownHosts.isManaged(leaving.deploymentUrl)) {
      next
        ..removeWhere((e) => e == leaving)
        ..insert(0, leaving);
    }
    return next.length > maxRecent ? next.sublist(0, maxRecent) : next;
  }

  Future<void> _persist() async {
    try {
      final c = _custom;
      if (c == null) {
        await _storage.delete(key: _kUrl);
        await _storage.delete(key: _kSiteUrl);
        await _storage.delete(key: _kPinned);
      } else {
        await _storage.write(key: _kUrl, value: c.deploymentUrl);
        final site = c.siteUrlOverride;
        if (site == null) {
          await _storage.delete(key: _kSiteUrl);
        } else {
          await _storage.write(key: _kSiteUrl, value: site);
        }
        if (_pinned) {
          await _storage.write(key: _kPinned, value: '1');
        } else {
          await _storage.delete(key: _kPinned);
        }
      }
      await _storage.write(
        key: _kRecent,
        value: ServerEndpoint.encodeList(_recent),
      );
    } on MissingPluginException {
      // No secure storage on this platform at all — the test harness, and
      // nothing else. Silent, matching how every other store treats it; a line
      // per write would drown the suite's output.
    } catch (e) {
      // In-memory state is already right, so the app behaves correctly for this
      // run and forgets the choice on relaunch. Loud, because a server choice
      // that silently fails to stick is a bewildering bug to hit.
      debugPrint('ServerStore: persisting the server choice failed: $e');
    }
  }

  /// Test seam. Resets to the bundled default without touching storage.
  @visibleForTesting
  void resetForTest() {
    _custom = null;
    _pinned = false;
    _recent = const [];
    _loaded = true;
  }

  /// Test seam. Sets the active custom server without touching storage.
  ///
  /// [pinned] defaults to false — a server arrived at, not chosen — because
  /// that is the case every existing caller means when it hands in one of the
  /// operator's addresses.
  @visibleForTesting
  void setForTest(ServerEndpoint? endpoint, {bool pinned = false}) {
    _custom = endpoint;
    _pinned = pinned;
    _loaded = true;
    notifyListeners();
  }
}
