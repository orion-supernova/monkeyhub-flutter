import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import 'package:convex_flutter/src/impl/convex_client_interface.dart';
import 'package:convex_flutter/src/rust/lib.dart' show WebSocketConnectionState, SubscriptionHandle, AuthHandle;
import 'package:convex_flutter/src/connection_status.dart';
import 'package:convex_flutter/src/convex_config.dart';
import 'package:convex_flutter/src/app_lifecycle_event.dart';
import 'package:convex_flutter/src/app_lifecycle_observer.dart';

/// Web (pure Dart) implementation of Convex client.
///
/// This implementation uses the browser's native WebSocket API for web platform,
/// avoiding the need for Rust toolchain or FFI. It implements the same
/// [IConvexClient] interface as [NativeConvexClient], ensuring API compatibility
/// across all platforms.
///
/// For mobile/desktop platforms, use [NativeConvexClient] instead.
class WebConvexClient implements IConvexClient {
  /// Configuration for this client
  @override
  final ConvexConfig config;

  /// WebSocket connection to Convex backend
  web.WebSocket? _ws;

  /// Stream controller for auth state changes
  final StreamController<bool> _authStateController =
      StreamController<bool>.broadcast();

  /// Stream controller for lifecycle events
  final StreamController<AppLifecycleEvent> _lifecycleController =
      StreamController<AppLifecycleEvent>.broadcast();

  /// Stream controller for WebSocket connection state changes
  final StreamController<WebSocketConnectionState> _connectionStateController =
      StreamController<WebSocketConnectionState>.broadcast();

  /// Current connection state (cached for sync access)
  WebSocketConnectionState _currentConnectionState =
      WebSocketConnectionState.connecting;

  /// Current auth token
  String? _currentAuthToken;

  /// Lifecycle observer for app state changes
  late final AppLifecycleObserver _lifecycleObserver;

  /// Message ID counter for generating unique request IDs
  int _messageIdCounter = 0;

  /// Session ID for Convex sync protocol
  String? _sessionId;

  /// Query ID counter for subscriptions
  int _queryIdCounter = 0;

  /// Query set version counter for ModifyQuerySet messages
  int _querySetVersion = 0;

  /// Pending requests waiting for responses (query, mutation, action)
  final Map<int, Completer<String>> _pendingRequests = {};

  /// Active subscriptions
  final Map<String, _WebSubscription> _subscriptions = {};

  /// Reconnection attempt counter
  int _reconnectAttempts = 0;

  /// Maximum reconnection attempts
  static const int _maxReconnectAttempts = 10;

  /// Base reconnection delay
  static const Duration _baseReconnectDelay = Duration(seconds: 1);

  /// Timer for reconnection
  Timer? _reconnectTimer;

  /// Whether client is disposed
  bool _isDisposed = false;

  // ── monkeyhub patch ──────────────────────────────────────────────────────
  // Sockets this client has deliberately abandoned. A closing socket's
  // `onclose` fires asynchronously, long after `_ws` has been reassigned, and
  // upstream handles it with no idea which socket it came from — so the close
  // *we* caused schedules a reconnect that replaces the connection we just
  // built. See [_scheduleReconnect] and [reconnect].
  final Set<web.WebSocket> _abandoned = <web.WebSocket>{};

  /// Bumped on every `onopen`. Query ids are scoped to the connection that
  /// registered them — the server knows nothing of an id Added on a socket that
  /// has since been replaced, and answers a `Remove` for one with
  /// `Nonexistent query id`, which is a protocol error it may close the
  /// connection over. Stamping each subscription with the generation it was
  /// registered on is what makes "is this id still meaningful?" answerable.
  int _connectionGeneration = 0;

  /// Close [socket] and remember that its `onclose` is expected, so the
  /// handler doesn't mistake it for the live connection dropping.
  void _abandonSocket(web.WebSocket? socket) {
    if (socket == null) return;
    _abandoned.add(socket);
    // Whatever this socket was carrying dies with it — see
    // [_failInFlightRequests].
    if (identical(socket, _ws)) _failInFlightRequests('connection replaced');
    try {
      socket.close();
    } catch (_) {
      // Already closing or closed — the point was to stop listening to it.
    }
  }

  /// Mutations and actions written but not yet sent, oldest first.
  ///
  /// `_sendMessage` throws when the socket isn't OPEN, and a WebSocket spends
  /// its first few hundred milliseconds in CONNECTING — so at boot every call
  /// the app made before `onopen` died on `Bad state: WebSocket not connected`.
  /// That is not a hypothetical window: in a captured session twelve calls
  /// failed that way in the first millisecond, including the profile fetch the
  /// recovery gate needs and the release check, both of which then logged
  /// themselves as "skipped" and never retried.
  ///
  /// Queries and subscriptions don't need a queue — they are already recorded
  /// in [_subscriptions], and [_replaySubscriptions] registers them the moment
  /// a socket opens. Mutations and actions have no such record, so they get
  /// held here and flushed by [_flushSendQueue].
  final List<_QueuedSend> _sendQueue = <_QueuedSend>[];

  /// True when the live socket can carry a message right now.
  bool get _socketReady {
    final ws = _ws;
    return ws != null && ws.readyState == web.WebSocket.OPEN;
  }

  /// Send everything that was written while the socket was still connecting.
  void _flushSendQueue() {
    if (_sendQueue.isEmpty) return;
    final queued = List<_QueuedSend>.from(_sendQueue);
    _sendQueue.clear();
    for (final send in queued) {
      try {
        _sendMessage(send.message);
      } catch (e) {
        // The socket died between `onopen` and here. The request is still in
        // `_pendingRequests`, and it is no longer queued, so the next socket
        // loss fails it rather than leaving it to time out.
        debugPrint('ERROR: [WebConvexClient] Queued send failed: $e');
      }
    }
    debugPrint(
      '=== [WebConvexClient] Flushed ${queued.length} queued message(s) ===',
    );
  }

  /// Fail every mutation/action that was already handed to a socket we are
  /// giving up on.
  ///
  /// Convex scopes `requestId` to a connection, so a response to a request sent
  /// on a dead socket is never coming — the only thing waiting accomplishes is
  /// spending the full `operationTimeout`. Observed exactly that: a
  /// `users:updateStatus` sent one millisecond before a reconnect reported
  /// `Mutation timeout` fifteen seconds later, long after the client had
  /// rebuilt the connection and moved on.
  ///
  /// Requests still sitting in [_sendQueue] are deliberately spared: they were
  /// never transmitted, so the new socket can carry them without risking a
  /// double-execute.
  void _failInFlightRequests(String reason) {
    if (_pendingRequests.isEmpty) return;
    final queuedIds = _sendQueue.map((s) => s.requestId).toSet();
    final stranded =
        _pendingRequests.keys.where((id) => !queuedIds.contains(id)).toList();
    if (stranded.isEmpty) return;
    for (final id in stranded) {
      final completer = _pendingRequests.remove(id);
      if (completer != null && !completer.isCompleted) {
        completer.completeError(StateError('Convex request lost: $reason'));
      }
    }
    debugPrint(
      '=== [WebConvexClient] Failed ${stranded.length} in-flight request(s): $reason ===',
    );
  }
  // ── end monkeyhub patch ──────────────────────────────────────────────────

  /// Private constructor
  WebConvexClient._(this.config);

  /// Factory method to create and initialize a web client.
  ///
  /// This handles:
  /// - WebSocket connection setup
  /// - Event listener registration
  /// - Lifecycle observer setup
  static Future<WebConvexClient> create(ConvexConfig config) async {
    debugPrint('=== [WebConvexClient] Creating web client ===');

    final client = WebConvexClient._(config);

    // Setup lifecycle observer
    // Note: On web, we don't reconnect on lifecycle events because:
    // 1. Page navigation triggers lifecycle events but doesn't disconnect WebSocket
    // 2. WebSocket onclose handler already manages reconnection
    // 3. Browser tab visibility changes are the only real "background" events
    client._lifecycleObserver = AppLifecycleObserver(
      onLifecycleChange: (event) {
        client._lifecycleController.add(event);
        // Do NOT trigger reconnection on web - let WebSocket manage itself
        debugPrint('=== [WebConvexClient] Lifecycle event: ${event.name} (no action on web) ===');
      },
    );

    // Establish WebSocket connection
    await client._connect();

    debugPrint('=== [WebConvexClient] Client created successfully ===');
    return client;
  }

  /// Establishes WebSocket connection to Convex backend.
  Future<void> _connect() async {
    if (_isDisposed) return;

    debugPrint('=== [WebConvexClient] Connecting to Convex ===');

    try {
      // Convert HTTPS to WSS URL with correct Convex sync endpoint
      // Format: wss://deployment.convex.cloud/api/{version}/sync
      final wsUrl = config.deploymentUrl.replaceFirst('https', 'wss');
      final fullUrl = '$wsUrl/api/sync';

      debugPrint('=== [WebConvexClient] WebSocket URL: $fullUrl ===');

      // Update state to connecting
      _updateConnectionState(WebSocketConnectionState.connecting);

      // ── monkeyhub patch ──────────────────────────────────────────────────
      // Reassigning `_ws` used to drop the previous socket without closing it.
      // The browser keeps an unreferenced-but-open socket alive, so it stayed
      // connected, kept its server-side query set, and kept delivering
      // Transitions into `_handleMessage` — which routes purely by queryId and
      // cannot tell which connection a message arrived on. Every reconnect lap
      // leaked one, and with query ids restarting at 0 on each new socket they
      // eventually collide and cross-feed each other's subscribers.
      _abandonSocket(_ws);
      // ── end monkeyhub patch ──────────────────────────────────────────────

      // Create WebSocket connection
      _ws = web.WebSocket(fullUrl);

      // Setup event listeners
      _setupWebSocketListeners();

      debugPrint('=== [WebConvexClient] WebSocket connection initiated ===');
    } catch (e) {
      debugPrint('ERROR: [WebConvexClient] Connection failed: $e');
      _scheduleReconnect();
    }
  }

  /// Sets up WebSocket event listeners.
  void _setupWebSocketListeners() {
    final ws = _ws;
    if (ws == null) return;

    // Connection opened
    ws.onopen = (web.Event event) {
      debugPrint('=== [WebConvexClient] WebSocket opened ===');
      _reconnectAttempts = 0; // Reset reconnection counter
      _querySetVersion = 0; // Reset query set version for new connection
      _connectionGeneration++; // monkeyhub patch: invalidates old query ids
      _updateConnectionState(WebSocketConnectionState.connected);

      // Send Connect handshake (required by Convex protocol)
      _sendConnectMessage();

      // Send auth token if available
      if (_currentAuthToken != null) {
        _sendAuthMessage(_currentAuthToken!);
      }

      // monkeyhub patch: a new socket starts with an empty query set.
      _replaySubscriptions();

      // monkeyhub patch: and anything written while it was still CONNECTING is
      // waiting to go out. After the replay so the query set is rebuilt before
      // mutations start landing against it.
      _flushSendQueue();
    }.toJS;

    // Connection closed
    ws.onclose = (web.CloseEvent event) {
      final code = event.code;
      final reason = event.reason;
      final wasClean = event.wasClean;
      debugPrint('=== [WebConvexClient] WebSocket closed ===');
      debugPrint('=== [WebConvexClient] Close code: $code, reason: "$reason", wasClean: $wasClean ===');

      // ── monkeyhub patch ──────────────────────────────────────────────────
      // Only the socket we are currently using is allowed to speak for the
      // connection. Without this, closing an old socket (which `_connect` and
      // `reconnect` both do deliberately) dragged the *live* connection's
      // reported state down to `connecting` and scheduled a reconnect that
      // tore it down a second later. One outage then fed itself: every heal
      // produced the close that triggered the next heal, and every in-flight
      // one-shot query — which is what `checkConnection`/health probes are —
      // was stranded on a socket nobody was reading any more, so it could only
      // fail by timeout.
      if (_abandoned.remove(ws) || !identical(ws, _ws)) {
        debugPrint('=== [WebConvexClient] (stale socket, ignoring) ===');
        return;
      }
      // ── end monkeyhub patch ──────────────────────────────────────────────

      _updateConnectionState(WebSocketConnectionState.connecting);

      // monkeyhub patch: this socket carried away whatever it was holding.
      _failInFlightRequests('socket closed (code $code)');

      // Attempt reconnection if not disposed
      if (!_isDisposed) {
        _scheduleReconnect();
      }
    }.toJS;

    // Connection error
    ws.onerror = (web.Event event) {
      debugPrint('ERROR: [WebConvexClient] WebSocket error occurred');
      debugPrint('ERROR: [WebConvexClient] Event type: ${event.type}');
      // monkeyhub patch: a dying old socket is not evidence about the live one.
      if (!identical(ws, _ws)) return;
      _updateConnectionState(WebSocketConnectionState.connecting);
    }.toJS;

    // Message received
    ws.onmessage = (web.MessageEvent event) {
      // ── monkeyhub patch ──────────────────────────────────────────────────
      // `_handleMessage` dispatches on queryId/requestId alone. Both counters
      // are per-connection (`_querySetVersion` resets to 0 on every open), so a
      // superseded socket that is still delivering its old query set will hand
      // one subscriber another's rows, and answer requestIds this connection
      // never sent. Whatever arrives on a socket we have moved on from is not
      // ours to route.
      if (!identical(ws, _ws)) return;
      // ── end monkeyhub patch ──────────────────────────────────────────────
      final data = event.data;

      // Convert JSAny? to String
      final dataString = (data as JSString?)?.toDart;
      if (dataString != null) {
        _handleMessage(dataString);
      } else {
        debugPrint('WARNING: [WebConvexClient] Received non-string message');
      }
    }.toJS;
  }

  /// Handles incoming WebSocket messages.
  void _handleMessage(String data) {
    try {
      debugPrint('=== [WebConvexClient] RAW MESSAGE: $data ===');

      final message = jsonDecode(data) as Map<String, dynamic>;
      final type = message['type'] as String?;
      final id = message['id'] as String?;

      debugPrint('=== [WebConvexClient] Received message type: $type, id: $id ===');

      switch (type) {
        case 'Transition':
          // Query subscription updates
          _handleTransition(message);
          break;

        case 'MutationResponse':
          _handleMutationResponse(message);
          break;

        case 'ActionResponse':
          _handleActionResponse(message);
          break;

        case 'Ping':
          // Respond to server ping
          _sendPong();
          break;

        case 'FatalError':
          _handleFatalError(message);
          break;

        case 'AuthError':
          _handleAuthError(message);
          break;

        default:
          debugPrint('WARNING: [WebConvexClient] Unknown message type: $type');
      }
    } catch (e) {
      debugPrint('ERROR: [WebConvexClient] Failed to parse message: $e');
    }
  }

  /// Handles Transition messages (query subscription updates).
  void _handleTransition(Map<String, dynamic> message) {
    final modifications = message['modifications'] as List?;
    if (modifications == null) return;

    for (final mod in modifications) {
      final queryId = mod['queryId']?.toString();
      if (queryId == null) continue;

      final subscription = _subscriptions[queryId];
      if (subscription == null) continue;

      final modType = mod['type'] as String?;

      // ── monkeyhub patch ────────────────────────────────────────────────────
      // `null` is a RESULT, not an absence. Upstream skipped the delivery
      // whenever `value` was null, so any query that legitimately resolves to
      // null never completed: the subscriber was never called, the one-shot
      // `query()` completer stayed pending, and the only way out was the 15s
      // `operationTimeout`.
      //
      // This was not a corner case here — it was the single loudest bug on
      // web. `releases:latest` is the app's configured `healthCheckQuery`, and
      // it returns null whenever the channel has no release row. So the
      // connectivity probe could only ever fail, by timeout, on a socket that
      // was demonstrably healthy (the server answered `{"queryId":11,
      // "value":null}` in 130ms, and the probe "timed out" 15 seconds later).
      // ConnectionHealth read that as an outage, tore down a working socket,
      // and stranded whatever else was in flight — which produced more
      // timeouts, which produced the next teardown. `online → reconnecting →
      // stalled` with three full socket rebuilds a minute, all of it
      // self-inflicted.
      //
      // Same shape, quieter symptoms, for `calls:activeCallForUser` and
      // `groupCalls:pendingInviteForUser`: both answer null for "no call", so
      // on web their subscribers were never told, and the call UI could not
      // settle into its idle state.
      //
      // Dispatching on the modification type is what makes "absent" and "null"
      // distinguishable: only `QueryUpdated` carries a result at all, and its
      // result is whatever `value` holds — including null, which `jsonEncode`
      // renders as the string `"null"`, exactly what the native client returns
      // and what `ConvexBackend._decode` already maps back to null.
      if (modType == 'QueryUpdated') {
        subscription.onUpdate(jsonEncode(mod['value']));
        continue;
      }

      // A query that throws server-side used to be indistinguishable from one
      // that never answered: no error was routed, so the caller waited out the
      // full timeout and reported it as a connectivity failure.
      if (modType == 'QueryFailed') {
        final errorMessage =
            mod['errorMessage'] as String? ?? 'Query failed: ${subscription.name}';
        final errorData = mod['errorData'];
        subscription.onError(
          errorMessage,
          errorData == null ? null : jsonEncode(errorData),
        );
        continue;
      }

      // `QueryRemoved` is the server acknowledging our own Remove. Nothing to
      // deliver, and nothing is wrong.
      // ── end monkeyhub patch ────────────────────────────────────────────────
    }
  }

  /// Handles MutationResponse messages.
  void _handleMutationResponse(Map<String, dynamic> message) {
    _completeRequest(message, 'mutation');
  }

  /// Handles ActionResponse messages.
  void _handleActionResponse(Map<String, dynamic> message) {
    _completeRequest(message, 'action');
  }

  // ── monkeyhub patch ────────────────────────────────────────────────────────
  /// Resolve the pending mutation/action for this response.
  ///
  /// Upstream branched on `result` alone and never read `success`, which got
  /// both cases exactly backwards:
  ///
  ///  * A SUCCESSFUL void call — `{"success":true,"result":null}`, which is what
  ///    every `Future<void>` mutation returns, and most of this app's are —
  ///    was reported as the error "No result in mutation response". The app
  ///    papers over that in `ConvexBackend._isVoidResultThrow`, but only by
  ///    string-matching the message, and only after the error has already been
  ///    thrown.
  ///  * A FAILED call — `{"success":false,"result":"<error message>"}`, where
  ///    the server puts the error text in `result` — has a non-null `result`,
  ///    so it took the success branch and completed with the error string as
  ///    though it were the return value. A rejected mutation read as a
  ///    successful one on web, and (because the app normalises the void throw
  ///    above) there was no path left for it to surface as a failure at all.
  ///
  /// `success` is the field that says which of the two happened; `result` only
  /// says what came back.
  void _completeRequest(Map<String, dynamic> message, String kind) {
    final requestId = message['requestId'] as int?;
    if (requestId == null) return;

    final completer = _pendingRequests.remove(requestId);
    if (completer == null) return;

    if (message['success'] == false) {
      // `errorMessage` is the modern field; `result` carried the text on older
      // server builds. Either way the call failed and must throw.
      final error = message['errorMessage'] as String? ??
          message['result']?.toString() ??
          'Convex $kind failed';
      completer.completeError(Exception(error));
      return;
    }

    // Null is a legitimate return value for a void function, and `jsonEncode`
    // renders it as `"null"` — the same string the native client hands back.
    completer.complete(jsonEncode(message['result']));
  }
  // ── end monkeyhub patch ────────────────────────────────────────────────────

  /// Handles FatalError messages.
  void _handleFatalError(Map<String, dynamic> message) {
    final error = message['error'] as String? ?? 'Unknown fatal error';
    debugPrint('FATAL ERROR: [WebConvexClient] $error');

    // Close connection on fatal error
    _ws?.close();
  }

  /// Handles AuthError messages.
  void _handleAuthError(Map<String, dynamic> message) {
    final error = message['error'] as String? ?? 'Authentication error';
    debugPrint('AUTH ERROR: [WebConvexClient] $error');

    // Clear auth and notify
    _authStateController.add(false);
  }

  /// Sends Pong response to server Ping.
  void _sendPong() {
    try {
      _sendMessage({
        'type': 'Event',
        'eventType': 'Pong',  // Required field
        'event': null,  // Required field (can be null)
      });
      debugPrint('=== [WebConvexClient] Sent Pong ===');
    } catch (e) {
      debugPrint('ERROR: [WebConvexClient] Failed to send Pong: $e');
    }
  }

  /// Sends Connect handshake message.
  void _sendConnectMessage() {
    try {
      // Generate or reuse session ID (must be valid UUID format)
      _sessionId ??= _generateUuid();

      _sendMessage({
        'type': 'Connect',
        'sessionId': _sessionId,
        'maxObservedTimestamp': null,
        'connectionCount': _reconnectAttempts + 1,
        'lastCloseReason': null,  // Required field
        'clientTs': DateTime.now().millisecondsSinceEpoch,  // Required field
      });
      debugPrint('=== [WebConvexClient] Sent Connect handshake ===');
    } catch (e) {
      debugPrint('ERROR: [WebConvexClient] Failed to send Connect: $e');
    }
  }

  /// Generates a RFC 4122 compliant UUID v4 string.
  String _generateUuid() {
    // UUID v4 format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
    // Where 4 = version 4, y = variant bits (8, 9, A, or B)
    final random = math.Random();

    // Generate random values for each segment
    final segment1 = random.nextInt(0x100000000); // 32 bits = 8 hex chars
    final segment2 = random.nextInt(0x10000);      // 16 bits = 4 hex chars
    final segment3 = random.nextInt(0x10000);      // 16 bits = 4 hex chars (we'll set version)
    final segment4 = random.nextInt(0x10000);      // 16 bits = 4 hex chars (we'll set variant)
    final segment5a = random.nextInt(0x100000000); // 32 bits = 8 hex chars
    final segment5b = random.nextInt(0x10000);     // 16 bits = 4 hex chars

    // Set version 4 (bits 12-15 of segment3 = 0100)
    final version4 = (segment3 & 0x0FFF) | 0x4000;

    // Set variant bits (bits 14-15 of segment4 = 10)
    final variant = (segment4 & 0x3FFF) | 0x8000;

    // Combine segment5 parts into 12 hex digits
    final segment5 = '${segment5a.toRadixString(16).padLeft(8, '0')}${segment5b.toRadixString(16).padLeft(4, '0')}';

    return '${segment1.toRadixString(16).padLeft(8, '0')}-'
           '${segment2.toRadixString(16).padLeft(4, '0')}-'
           '${version4.toRadixString(16).padLeft(4, '0')}-'
           '${variant.toRadixString(16).padLeft(4, '0')}-'
           '$segment5';
  }

  /// Updates connection state and emits to stream.
  void _updateConnectionState(WebSocketConnectionState newState) {
    if (_currentConnectionState != newState) {
      debugPrint('=== [WebConvexClient] State transition: ${_currentConnectionState.name} → ${newState.name} ===');
      _currentConnectionState = newState;
      _connectionStateController.add(newState);
    }
  }

  /// Schedules a reconnection attempt with exponential backoff.
  void _scheduleReconnect() {
    if (_isDisposed) return;

    _reconnectTimer?.cancel();

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('ERROR: [WebConvexClient] Max reconnection attempts reached');
      return;
    }

    // Exponential backoff: 1s, 2s, 4s, 8s, 16s, 32s (max)
    final delay = _baseReconnectDelay * (1 << _reconnectAttempts.clamp(0, 5));
    _reconnectAttempts++;

    debugPrint('=== [WebConvexClient] Scheduling reconnect attempt $_reconnectAttempts in ${delay.inSeconds}s ===');

    _reconnectTimer = Timer(delay, () {
      debugPrint('=== [WebConvexClient] Executing reconnect attempt $_reconnectAttempts ===');
      _connect();
    });
  }

  /// Generates a unique message ID.
  int _generateMessageId() {
    return _messageIdCounter++;
  }

  /// Sends a message over WebSocket.
  void _sendMessage(Map<String, dynamic> message) {
    final ws = _ws;
    if (ws == null || ws.readyState != web.WebSocket.OPEN) {
      throw StateError('WebSocket not connected');
    }

    final messageJson = jsonEncode(message);
    debugPrint('=== [WebConvexClient] SENDING: $messageJson ===');
    ws.send(messageJson.toJS);

    debugPrint('=== [WebConvexClient] Sent message: ${message['type']} (id: ${message['id']}) ===');
  }

  // ── monkeyhub patch ────────────────────────────────────────────────────────
  /// Add one query to the server's query set, if there is a socket to add it
  /// to.
  ///
  /// Both `query()` and `subscribe()` record the query in [_subscriptions]
  /// before calling this, and [_replaySubscriptions] rebuilds the whole set
  /// from that map on every `onopen`. So a socket that isn't OPEN yet is not a
  /// failure — the registration simply happens a few hundred milliseconds
  /// later, when there is a connection to register it on. Throwing instead (the
  /// upstream behaviour, via `_sendMessage`) turned every call issued during
  /// the initial CONNECTING window into a hard `Bad state: WebSocket not
  /// connected`, which is what made a freshly loaded page come up with an empty
  /// room list and a skipped recovery gate.
  ///
  /// The version counter is rolled back on failure so the query set stays
  /// contiguous; a gap is a protocol error the server closes the connection
  /// over.
  void _registerQuery(int queryId, String name, Map<String, dynamic> args) {
    if (!_socketReady) {
      debugPrint(
        '=== [WebConvexClient] Deferring queryId=$queryId ($name) until the socket opens ===',
      );
      return;
    }

    final baseVersion = _querySetVersion;
    final newVersion = ++_querySetVersion;
    try {
      _sendMessage({
        'type': 'ModifyQuerySet',
        'baseVersion': baseVersion,
        'newVersion': newVersion,
        'modifications': [
          {
            'type': 'Add',
            'queryId': queryId,
            'udfPath': name,
            'args': [args], // Args must be array, not object
          }
        ],
      });
    } catch (e) {
      _querySetVersion = baseVersion;
      debugPrint('ERROR: [WebConvexClient] Query registration deferred: $e');
    }
  }

  /// Re-register every live subscription on a freshly opened socket.
  ///
  /// A new connection begins with an empty query set — `_querySetVersion` is
  /// reset to 0 in `onopen` for exactly that reason. Upstream never replayed
  /// the subscriptions into it, so after any reconnect the client held a map
  /// full of subscriptions the server had never been told about: `isConnected`
  /// true, callbacks intact, and nothing ever arriving again. Every consumer
  /// had to notice the silence and rebuild its own subscriptions, which is only
  /// possible if it can tell a reconnect happened at all.
  ///
  /// Query ids are safe to reuse: `_queryIdCounter` is deliberately *not* reset
  /// on open, so each id is still unique within this client and still matches
  /// the `_subscriptions` key its updates dispatch through.
  void _replaySubscriptions() {
    final live = _subscriptions.values.where((s) => s.isReplayable).toList();
    if (live.isEmpty) return;

    final modifications = <Map<String, dynamic>>[];
    for (final s in live) {
      final queryId = int.tryParse(s.id);
      if (queryId == null) continue;
      // Re-registered here, so its id is meaningful again — and a later
      // `Remove` for it is legitimate.
      s.generation = _connectionGeneration;
      modifications.add({
        'type': 'Add',
        'queryId': queryId,
        'udfPath': s.name,
        'args': [s.args],
      });
    }
    if (modifications.isEmpty) return;

    // One ModifyQuerySet for the lot: the version numbers must be contiguous,
    // and a batch keeps this atomic against a socket that dies mid-replay.
    final baseVersion = _querySetVersion;
    final newVersion = ++_querySetVersion;
    try {
      _sendMessage({
        'type': 'ModifyQuerySet',
        'baseVersion': baseVersion,
        'newVersion': newVersion,
        'modifications': modifications,
      });
      debugPrint(
        '=== [WebConvexClient] Replayed ${modifications.length} subscription(s) onto the new socket ===',
      );
    } catch (e) {
      // The socket died between `onopen` and here. Roll the version back so the
      // next attempt doesn't leave a gap the server would reject.
      _querySetVersion = baseVersion;
      debugPrint('ERROR: [WebConvexClient] Subscription replay failed: $e');
    }
  }
  // ── end monkeyhub patch ────────────────────────────────────────────────────

  // ── monkeyhub patch ────────────────────────────────────────────────────────
  /// Send a mutation/action now, or hold it until the socket opens.
  ///
  /// Unlike a query there is nothing to re-derive a mutation from later, so it
  /// waits in [_sendQueue] instead of failing. Being queued is also what marks
  /// it as never-transmitted, which is what lets [_failInFlightRequests] tell
  /// "this can safely be sent on the next socket" apart from "this may already
  /// have executed and must not be sent twice".
  /// Abandon a request the caller has stopped waiting for. Drops the queued
  /// copy too, so a message whose caller already timed out isn't delivered to
  /// the next socket with nobody left to receive the answer.
  void _forgetRequest(int requestId) {
    _pendingRequests.remove(requestId);
    _sendQueue.removeWhere((s) => s.requestId == requestId);
  }

  void _sendOrQueue(int requestId, Map<String, dynamic> message) {
    if (!_socketReady) {
      _sendQueue.add(_QueuedSend(requestId: requestId, message: message));
      debugPrint(
        '=== [WebConvexClient] Queued ${message['type']} ${message['udfPath']} until the socket opens ===',
      );
      return;
    }
    _sendMessage(message);
  }
  // ── end monkeyhub patch ────────────────────────────────────────────────────

  /// Sends authentication message.
  void _sendAuthMessage(String token) {
    try {
      // Send Authenticate message (Convex protocol)
      _sendMessage({
        'type': 'Authenticate',
        'token': token,
      });
      debugPrint('=== [WebConvexClient] Auth token sent ===');
    } catch (e) {
      debugPrint('ERROR: [WebConvexClient] Failed to send auth: $e');
    }
  }

  // ============================================================================
  // IConvexClient Implementation - Core Operations
  // ============================================================================

  @override
  Future<String> query(String name, Map<String, dynamic> args) async {
    // Queries in Convex protocol use ModifyQuerySet (like subscriptions)
    // We subscribe, wait for first result, then unsubscribe
    final queryId = _queryIdCounter++;
    final queryIdStr = queryId.toString();
    final completer = Completer<String>();

    // Create temporary subscription for one-shot query
    final subscription = _WebSubscription(
      id: queryIdStr,
      onUpdate: (value) {
        if (!completer.isCompleted) {
          completer.complete(value);
          // Auto-unsubscribe after getting result
          _unsubscribe(queryIdStr);
        }
      },
      onError: (message, value) {
        if (!completer.isCompleted) {
          completer.completeError(Exception(message));
          _subscriptions.remove(queryIdStr);
        }
      },
      // ── monkeyhub patch ────────────────────────────────────────────────────
      // A one-shot query is a subscription with a short life, and it needs the
      // same two things a long-lived one does. Replaying it means a query whose
      // socket died mid-flight is re-asked on the new connection instead of
      // hanging until `operationTimeout` — which matters more than it sounds,
      // because the app's health probe IS a one-shot query. A probe that can
      // only fail by timeout makes an outage look permanent and triggers
      // another reconnect, which strands the next probe the same way.
      name: name,
      args: args,
      generation: _connectionGeneration,
      // ── end monkeyhub patch ────────────────────────────────────────────────
    );
    _subscriptions[queryIdStr] = subscription;

    try {
      // monkeyhub patch: `_registerQuery` tolerates a socket that hasn't opened
      // yet — see there.
      _registerQuery(queryId, name, args);

      return await completer.future.timeout(
        config.operationTimeout,
        onTimeout: () {
          // monkeyhub patch: was `_subscriptions.remove`, which forgot the query
          // locally while leaving it in the server's query set for the life of
          // the connection. `_unsubscribe` retracts it properly, and declines to
          // send anything if the connection it belonged to is already gone.
          _unsubscribe(queryIdStr);
          throw TimeoutException('Query timeout: $name');
        },
      );
    } catch (e) {
      _subscriptions.remove(queryIdStr);
      rethrow;
    }
  }

  @override
  Future<String> mutation({
    required String name,
    required Map<String, dynamic> args,
  }) async {
    final requestId = _generateMessageId();
    final completer = Completer<String>();
    _pendingRequests[requestId] = completer;

    try {
      // monkeyhub patch: queued rather than thrown when the socket is still
      // connecting — see `_sendOrQueue`.
      _sendOrQueue(requestId, {
        'type': 'Mutation',
        'requestId': requestId,
        'udfPath': name,  // Use udfPath instead of name
        'args': [args],   // Args must be array, not object
      });

      return await completer.future.timeout(
        config.operationTimeout,
        onTimeout: () {
          _forgetRequest(requestId);
          throw TimeoutException('Mutation timeout: $name');
        },
      );
    } catch (e) {
      _forgetRequest(requestId);
      rethrow;
    }
  }

  @override
  Future<String> action({
    required String name,
    required Map<String, dynamic> args,
  }) async {
    final requestId = _generateMessageId();
    final completer = Completer<String>();
    _pendingRequests[requestId] = completer;

    try {
      // monkeyhub patch: see `_sendOrQueue`.
      _sendOrQueue(requestId, {
        'type': 'Action',
        'requestId': requestId,
        'udfPath': name,  // Use udfPath instead of name
        'args': [args],   // Args must be array, not object
      });

      return await completer.future.timeout(
        config.operationTimeout,
        onTimeout: () {
          _forgetRequest(requestId);
          throw TimeoutException('Action timeout: $name');
        },
      );
    } catch (e) {
      _forgetRequest(requestId);
      rethrow;
    }
  }

  @override
  Future<SubscriptionHandle> subscribe({
    required String name,
    required Map<String, dynamic> args,
    required void Function(String) onUpdate,
    required void Function(String, String?) onError,
  }) async {
    // Use incrementing query ID (Convex protocol requirement)
    final queryId = _queryIdCounter++;
    final queryIdStr = queryId.toString();

    // Create subscription record
    final subscription = _WebSubscription(
      id: queryIdStr,
      onUpdate: onUpdate,
      onError: onError,
      // monkeyhub patch: remembered so a reconnect can replay it, and stamped
      // with the connection this id is valid on.
      name: name,
      args: args,
      generation: _connectionGeneration,
    );
    _subscriptions[queryIdStr] = subscription;

    try {
      // monkeyhub patch: see `_registerQuery`.
      _registerQuery(queryId, name, args);

      debugPrint('=== [WebConvexClient] Subscription created: queryId=$queryId ===');

      // Return handle for cancellation
      return _WebSubscriptionHandle(
        onCancel: () {
          _unsubscribe(queryIdStr);
        },
      );
    } catch (e) {
      _subscriptions.remove(queryIdStr);
      rethrow;
    }
  }

  /// Unsubscribes from a subscription.
  void _unsubscribe(String queryIdStr) {
    final subscription = _subscriptions.remove(queryIdStr);
    if (subscription == null) return;

    // ── monkeyhub patch ──────────────────────────────────────────────────────
    // A query id belongs to the connection that Added it. Removing one the
    // current socket never registered makes the server raise
    // `Nonexistent query id`, which it can close the connection over — and
    // closing it strands whatever else was in flight, which produces more
    // orphaned ids, which produce more bogus Removes. Observed on the
    // deployment as a steady one-every-15s error stream (117 in three hours)
    // with the id climbing and resetting exactly when the client reconnected.
    //
    // Dropping the record locally is the whole job here: the server discarded
    // that query set when the socket went, so there is nothing left to remove.
    if (subscription.generation != _connectionGeneration) {
      debugPrint(
        '=== [WebConvexClient] Dropping stale queryId=$queryIdStr locally '
        '(registered on generation ${subscription.generation}, now $_connectionGeneration) ===',
      );
      return;
    }
    // ── end monkeyhub patch ──────────────────────────────────────────────────

    debugPrint('=== [WebConvexClient] Unsubscribing: queryId=$queryIdStr ===');

    try {
      final queryId = int.tryParse(queryIdStr);
      if (queryId == null) return;

      // Send ModifyQuerySet with Remove modification (Convex protocol)
      final baseVersion = _querySetVersion;
      final newVersion = ++_querySetVersion;

      _sendMessage({
        'type': 'ModifyQuerySet',
        'baseVersion': baseVersion,
        'newVersion': newVersion,
        'modifications': [
          {
            'type': 'Remove',
            'queryId': queryId,
          }
        ],
      });
    } catch (e) {
      debugPrint('ERROR: [WebConvexClient] Failed to send unsubscribe: $e');
    }
  }

  // ============================================================================
  // IConvexClient Implementation - Authentication
  // ============================================================================

  @override
  Future<void> setAuth({required String? token}) async {
    _currentAuthToken = token;

    if (token != null) {
      _sendAuthMessage(token);
      _authStateController.add(true);
    } else {
      _sendAuthMessage(''); // Clear auth
      _authStateController.add(false);
    }
  }

  @override
  Future<AuthHandle> setAuthWithRefresh({
    required Future<String?> Function() tokenFetcher,
    void Function(bool isAuthenticated)? onAuthChange,
  }) async {
    // TODO: Implement token refresh for web
    // For now, just fetch token once and set it
    final token = await tokenFetcher();
    await setAuth(token: token);

    if (onAuthChange != null) {
      onAuthChange(token != null);
    }

    // Return a simple auth handle (no auto-refresh yet)
    return _WebAuthHandle(
      isAuth: token != null,
      onDispose: () async {
        await setAuth(token: null);
      },
    );
  }

  @override
  Future<void> clearAuth() async {
    await setAuth(token: null);
  }

  @override
  Stream<bool> get authState => _authStateController.stream;

  @override
  bool get isAuthenticated => _currentAuthToken != null;

  // ============================================================================
  // IConvexClient Implementation - Connection Management
  // ============================================================================

  @override
  Stream<WebSocketConnectionState> get connectionState =>
      _connectionStateController.stream;

  @override
  WebSocketConnectionState get currentConnectionState => _currentConnectionState;

  @override
  bool get isConnected =>
      _currentConnectionState == WebSocketConnectionState.connected;

  @override
  @Deprecated('Use connectionState stream for real-time monitoring')
  Future<ConnectionStatus> checkConnection() async {
    if (config.healthCheckQuery == null) {
      throw StateError(
        'No health check query configured. '
        'Set healthCheckQuery in ConvexConfig or use a real query.',
      );
    }

    try {
      await query(config.healthCheckQuery!, {});
      return ConnectionStatus.connected;
    } on TimeoutException {
      return ConnectionStatus.timeout;
    } catch (e) {
      return ConnectionStatus.error;
    }
  }

  @override
  Future<bool> forceReconnect() async {
    // monkeyhub patch: on web `reconnect()` already IS a genuine teardown and
    // rebuild — it is the native one that was a health check in disguise. The
    // one behavioural difference from native is that `onopen` replays this
    // client's own `_subscriptions` map (see `_replaySubscriptions`), so
    // subscriptions survive a rebuild here and the caller need not re-register.
    return reconnect();
  }

  @override
  Future<bool> reconnect() async {
    debugPrint('=== [WebConvexClient] Manual reconnect requested ===');

    // ── monkeyhub patch ────────────────────────────────────────────────────
    // Cancel any reconnect the backoff loop already has queued. Otherwise it
    // fires a second later and replaces the socket this call is about to
    // build — the caller asked for one reconnect and got two connections, the
    // second one arriving after `reconnect()` had already returned.
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    // Close via `_abandonSocket` so the resulting `onclose` is recognised as
    // ours and doesn't schedule yet another reconnect.
    _abandonSocket(_ws);
    // ── end monkeyhub patch ────────────────────────────────────────────────
    _ws = null;

    // Reset reconnection counter for manual reconnect
    _reconnectAttempts = 0;

    // Attempt connection
    try {
      await _connect();

      // Wait a bit for connection to establish
      await Future.delayed(const Duration(seconds: 2));

      return isConnected;
    } catch (e) {
      debugPrint('ERROR: [WebConvexClient] Manual reconnect failed: $e');
      return false;
    }
  }

  // ============================================================================
  // IConvexClient Implementation - Lifecycle Management
  // ============================================================================

  @override
  Stream<AppLifecycleEvent> get lifecycleEvents => _lifecycleController.stream;

  // ============================================================================
  // IConvexClient Implementation - Resource Management
  // ============================================================================

  @override
  void dispose() {
    if (_isDisposed) return;

    debugPrint('=== [WebConvexClient] Disposing client ===');
    _isDisposed = true;

    // Cancel reconnection timer
    _reconnectTimer?.cancel();

    // Close WebSocket
    _ws?.close();
    _ws = null;

    // Dispose lifecycle observer
    _lifecycleObserver.dispose();

    // Close streams
    _authStateController.close();
    _lifecycleController.close();
    _connectionStateController.close();

    // Clear pending requests and subscriptions
    // monkeyhub patch: fail them rather than dropping them silently — a caller
    // awaiting a request on a disposed client would otherwise hang for the
    // whole `operationTimeout` waiting on a socket that no longer exists.
    _sendQueue.clear();
    _failInFlightRequests('client disposed');
    _pendingRequests.clear();
    _subscriptions.clear();

    debugPrint('=== [WebConvexClient] Client disposed ===');
  }
}

// ── monkeyhub patch ──────────────────────────────────────────────────────────
/// A mutation/action written before the socket was ready to carry it.
class _QueuedSend {
  _QueuedSend({required this.requestId, required this.message});

  final int requestId;
  final Map<String, dynamic> message;
}
// ── end monkeyhub patch ──────────────────────────────────────────────────────

/// Internal subscription record for web client.
class _WebSubscription {
  final String id;
  final void Function(String) onUpdate;
  final void Function(String, String?) onError;

  // monkeyhub patch: kept so the query set can be rebuilt on a new socket.
  // See `_replaySubscriptions`.
  final String name;
  final Map<String, dynamic> args;

  /// Which connection this query id is registered on. Query ids are only
  /// meaningful to the socket that Added them, so a `Remove` is only valid
  /// while this matches the client's current generation. See `_unsubscribe`.
  int generation;

  _WebSubscription({
    required this.id,
    required this.onUpdate,
    required this.onError,
    this.name = '',
    this.args = const {},
    this.generation = 0,
  });

  /// Whether this record carries enough to re-register itself.
  bool get isReplayable => name.isNotEmpty;
}

/// Web implementation of SubscriptionHandle.
class _WebSubscriptionHandle implements SubscriptionHandle {
  final void Function() onCancel;
  bool _isCancelled = false;

  _WebSubscriptionHandle({required this.onCancel});

  @override
  void cancel() {
    if (!_isCancelled) {
      _isCancelled = true;
      onCancel();
    }
  }

  @override
  void dispose() {
    cancel();
  }

  @override
  bool get isDisposed => _isCancelled;
}

/// Web implementation of AuthHandle.
class _WebAuthHandle implements AuthHandle {
  final bool isAuth;
  final Future<void> Function() onDispose;
  bool _isDisposed = false;

  _WebAuthHandle({
    required this.isAuth,
    required this.onDispose,
  });

  @override
  bool isAuthenticated() => isAuth && !_isDisposed;

  @override
  void dispose() {
    if (!_isDisposed) {
      _isDisposed = true;
      onDispose();
    }
  }

  @override
  bool get isDisposed => _isDisposed;
}
