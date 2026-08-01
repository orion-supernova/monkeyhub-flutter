mod frb_generated;
use std::{
    collections::{BTreeMap, HashMap},
    sync::{
        atomic::{AtomicBool, AtomicU64, Ordering},
        Arc,
    },
    time::{Duration, SystemTime, UNIX_EPOCH},
};

#[cfg(debug_assertions)]
use android_logger::Config;
use convex::{
    ConvexClient,
    ConvexClientBuilder,
    FunctionResult,
    Value, // Convex client and result types
    WebSocketState as ConvexWebSocketState,
};
use flutter_rust_bridge::{frb, DartFnFuture};
use futures::{
    channel::oneshot::{self, Sender},
    pin_mut, select_biased, FutureExt, StreamExt,
};
use log::debug; // Logging for debugging purposes
#[cfg(debug_assertions)]
use log::LevelFilter;
use parking_lot::Mutex;
use base64::Engine;
use serde::Deserialize;

// Custom error type for Convex client operations, exposed to Dart.
#[derive(Debug, thiserror::Error)]
#[frb]
pub enum ClientError {
    /// An internal error within the mobile Convex client.
    #[error("InternalError: {msg}")]
    InternalError { msg: String },
    /// An application-specific error from a remote Convex backend function.
    #[error("ConvexError: {data}")]
    ConvexError { data: String },
    /// An unexpected server-side error from a remote Convex function.
    #[error("ServerError: {msg}")]
    ServerError { msg: String },
}

impl From<anyhow::Error> for ClientError {
    fn from(value: anyhow::Error) -> Self {
        Self::InternalError {
            msg: value.to_string(),
        }
    }
}

/// JWT claims structure for extracting expiration time.
#[derive(Deserialize)]
struct JwtClaims {
    exp: u64,
}

/// Decodes a JWT token and extracts the expiration timestamp.
/// Returns None if the token is malformed or doesn't contain an exp claim.
fn decode_jwt_expiry(token: &str) -> Option<u64> {
    // JWT format: header.payload.signature
    let parts: Vec<&str> = token.split('.').collect();
    if parts.len() != 3 {
        return None;
    }

    // Decode payload (second part) using URL-safe base64
    let payload = base64::engine::general_purpose::URL_SAFE_NO_PAD
        .decode(parts[1])
        .ok()?;

    let claims: JwtClaims = serde_json::from_slice(&payload).ok()?;
    Some(claims.exp)
}

/// WebSocket connection state exposed to Flutter/Dart.
///
/// This enum represents the current state of the WebSocket connection
/// to the Convex backend, allowing real-time connection monitoring.
#[derive(Debug, Clone)]
#[frb]
pub enum WebSocketConnectionState {
    /// The WebSocket is open and connected to the Convex backend.
    Connected,
    /// The WebSocket is closed and is connecting or reconnecting.
    Connecting,
}

impl From<ConvexWebSocketState> for WebSocketConnectionState {
    fn from(state: ConvexWebSocketState) -> Self {
        match state {
            ConvexWebSocketState::Connected => WebSocketConnectionState::Connected,
            ConvexWebSocketState::Connecting => WebSocketConnectionState::Connecting,
        }
    }
}

/// Trait defining the interface for handling subscription updates.
// Not directly exposed to Dart, used internally by subscribers.
pub trait QuerySubscriber: Send + Sync {
    fn on_update(&self, value: String); // Called when a new update is received
    fn on_error(&self, message: String, value: Option<String>); // Called on error with optional value
}

/// Adapter struct to implement QuerySubscriber using Dart callbacks.
pub struct CallbackSubscriber {
    on_update: Box<dyn Fn(String) + Send + Sync>, // Callback for updates
    on_error: Box<dyn Fn(String, Option<String>) + Send + Sync>, // Callback for errors
}

impl QuerySubscriber for CallbackSubscriber {
    fn on_update(&self, value: String) {
        (self.on_update)(value);
    }

    fn on_error(&self, message: String, value: Option<String>) {
        (self.on_error)(message, value);
    }
}

/// Opaque type for Dart, representing a subscription handle with cancellation.
#[frb(opaque)]
pub struct SubscriptionHandle {
    cancel_sender: Arc<Mutex<Option<Sender<()>>>>, // Sender to cancel the subscription
}

impl SubscriptionHandle {
    fn new(cancel_sender: Sender<()>) -> Self {
        SubscriptionHandle {
            cancel_sender: Arc::new(Mutex::new(Some(cancel_sender))),
        }
    }

    /// Cancels the subscription by sending a cancellation signal.
    #[frb(sync)]
    pub fn cancel(&self) {
        if let Some(sender) = self.cancel_sender.lock().take() {
            // ── monkeyhub patch ──────────────────────────────────────────────
            // Was `.unwrap()`. The receiver lives in the per-subscription task,
            // which exits on its own the moment the client's subscription
            // stream ends — which is exactly what `force_reconnect` causes. A
            // Dart-side `cancel()` after that (any screen disposing after a
            // socket rebuild) then sent on a closed channel and panicked across
            // FFI. Cancelling something already gone is not an error.
            let _ = sender.send(());
            // ── end monkeyhub patch ──────────────────────────────────────────
        }
    }
}

/// Opaque type for Dart, representing an auth session handle with lifecycle management.
/// Used to control the token refresh loop and check authentication state.
#[frb(opaque)]
pub struct AuthHandle {
    cancel_sender: Arc<Mutex<Option<Sender<()>>>>,
    is_authenticated: Arc<AtomicBool>,
}

impl AuthHandle {
    fn new(cancel_sender: Sender<()>, is_authenticated: Arc<AtomicBool>) -> Self {
        AuthHandle {
            cancel_sender: Arc::new(Mutex::new(Some(cancel_sender))),
            is_authenticated,
        }
    }

    /// Disposes the auth session, stopping the token refresh loop and clearing authentication.
    #[frb(sync)]
    pub fn dispose(&self) {
        if let Some(sender) = self.cancel_sender.lock().take() {
            let _ = sender.send(());
        }
    }

    /// Returns whether the user is currently authenticated.
    #[frb(sync)]
    pub fn is_authenticated(&self) -> bool {
        self.is_authenticated.load(Ordering::SeqCst)
    }
}

/// Adapter for Dart functions as subscribers, handling async callbacks.
pub struct CallbackSubscriberDartFn {
    on_update: Box<dyn Fn(String) -> DartFnFuture<()> + Send + Sync>, // Async update callback
    on_error: Box<dyn Fn(String, Option<String>) -> DartFnFuture<()> + Send + Sync>, // Async error callback
}

impl QuerySubscriber for CallbackSubscriberDartFn {
    fn on_update(&self, value: String) {
        let future = (self.on_update)(value);
        tokio::spawn(async move {
            let _ = future.await; // Await the future, ignoring the result
        });
    }

    fn on_error(&self, message: String, value: Option<String>) {
        let future = (self.on_error)(message, value);
        tokio::spawn(async move {
            let _ = future.await;
        });
    }
}

/// Main Convex client struct, opaque to Dart, managing connections and operations.
#[frb(opaque)]
pub struct MobileConvexClient {
    deployment_url: String,      // URL of the Convex deployment
    client_id: String,           // Client ID for authentication
    rt: tokio::runtime::Runtime, // Tokio runtime for async operations
    // ── monkeyhub patch ──────────────────────────────────────────────────────
    // Was `client: OnceCell<ConvexClient>`, which by construction could never
    // be replaced — and the `ConvexClient` behind it exposes no close,
    // reconnect or dispose. So a socket that had gone silent without closing
    // (the ordinary outcome of a phone resuming from a long sleep: the NAT
    // binding expired, or the interface changed, and nothing was ever sent to
    // find out) could only be healed by convex-rs's own detector — a 30s
    // `SERVER_INACTIVITY_THRESHOLD` measured on a MONOTONIC clock, which does
    // not advance while the device is asleep and therefore effectively
    // restarts at resume. Meanwhile every one-shot query is
    // `subscribe().next()` and parks rather than failing fast, so each probe
    // cost its full timeout and told us nothing.
    //
    // A replaceable slot is the whole fix. Dropping the last `ConvexClient`
    // clone aborts its worker, which drops the `WebSocketManager`, whose
    // `Drop` aborts the socket worker and closes the stream. See
    // [force_reconnect].
    /// Current client. `None` only between the take and the re-insert inside
    /// [force_reconnect]; racing callers block on [build_lock] and never see it.
    client: Arc<tokio::sync::RwLock<Option<ConvexClient>>>,
    /// Serialises *building*. Held across the whole of [force_reconnect], so
    /// concurrent [connected_client] callers wait and then find the fresh
    /// client rather than racing to build a second one.
    build_lock: tokio::sync::Mutex<()>,
    /// Bumped on every successful build. The state-change forwarder stamps its
    /// generation, so a dying old socket cannot emit `Connecting`/`Connected`
    /// into the app's stream after the swap.
    generation: Arc<AtomicU64>,
    // ── end monkeyhub patch ──────────────────────────────────────────────────
    // Channel sender for WebSocket state change notifications
    state_change_sender: Arc<Mutex<Option<tokio::sync::mpsc::Sender<ConvexWebSocketState>>>>,
}

/// Ceiling on a single Rust-side operation.
///
/// monkeyhub patch. Deliberately LONGER than `ConvexConfig.operationTimeout`
/// (15s) so the Dart timeout still wins in normal operation — this exists only
/// to stop a leak. Dart's `.timeout()` does not cancel the future underneath
/// it, so an op parked on a dead socket kept a `ConvexClient` clone alive, and
/// `ConvexClient::drop` only aborts the worker when the LAST clone goes. One
/// stuck mutation could therefore keep the old socket open indefinitely after a
/// rebuild had already opened a new one.
const RUST_OP_TIMEOUT: Duration = Duration::from_secs(20);

impl MobileConvexClient {
    /// Creates a new MobileConvexClient instance with the given deployment URL and client ID.
    #[frb(sync)]
    pub fn new(deployment_url: String, client_id: String) -> MobileConvexClient {
        #[cfg(debug_assertions)]
        android_logger::init_once(Config::default().with_max_level(LevelFilter::Error));
        let rt = tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .unwrap();
        MobileConvexClient {
            deployment_url,
            client_id,
            client: Arc::new(tokio::sync::RwLock::new(None)),
            build_lock: tokio::sync::Mutex::new(()),
            generation: Arc::new(AtomicU64::new(0)),
            rt,
            state_change_sender: Arc::new(Mutex::new(None)),
        }
    }

    /// Sets up WebSocket connection state change listener.
    ///
    /// Must be called BEFORE any queries/mutations to capture all state changes.
    /// The callback will be invoked whenever the WebSocket transitions between
    /// Connected and Connecting states.
    ///
    /// # Arguments
    ///
    /// * `on_state_change` - Async callback invoked when connection state changes
    ///
    /// # Example
    ///
    /// ```dart
    /// await client.onWebsocketStateChange(
    ///   onStateChange: (state) async {
    ///     print('Connection state: ${state.name}');
    ///   },
    /// );
    /// ```
    #[frb]
    pub async fn on_websocket_state_change(
        &self,
        on_state_change: impl Fn(WebSocketConnectionState) -> DartFnFuture<()> + Send + Sync + 'static,
    ) -> Result<(), ClientError> {
        println!("RUST: on_websocket_state_change() called");

        // Create tokio mpsc channel for receiving state changes from convex client.
        // monkeyhub patch: was 10. Every emitter uses `try_send`, so a full
        // channel drops state changes silently — and the Dart side caches the
        // last value it saw as `isConnected`, so a dropped `Connected` left the
        // client reporting `connecting` forever while queries worked fine.
        let (state_tx, mut state_rx) = tokio::sync::mpsc::channel::<ConvexWebSocketState>(64);
        println!("RUST: Created mpsc channel for state changes");

        // Store sender for use when initializing the client
        {
            let mut sender = self.state_change_sender.lock();
            *sender = Some(state_tx);
            println!("RUST: Stored state_tx in state_change_sender");
        }

        // Spawn task to listen for state changes and call Dart callback
        let on_state_change = Arc::new(on_state_change);
        println!("RUST: Spawning listener task for state changes");
        self.rt.spawn(async move {
            println!("RUST: Listener task started, waiting for state changes");
            while let Some(state) = state_rx.recv().await {
                println!("RUST: Received state change from channel: {:?}", state);
                let dart_state = WebSocketConnectionState::from(state);
                println!("RUST: Converted to Dart state: {:?}", dart_state);
                let callback = on_state_change.clone();
                let future = (callback)(dart_state);
                println!("RUST: Calling Dart callback");
                let _ = future.await;
                println!("RUST: Dart callback completed");
            }
            println!("RUST: Listener task exiting (channel closed)");
        });

        println!("RUST: on_websocket_state_change() returning");
        Ok(())
    }

    /// Retrieves or initializes a connected Convex client.
    ///
    /// monkeyhub patch: double-checked around [build_lock] so the common case
    /// is a read-lock and nothing else, while a concurrent build (or a
    /// [force_reconnect]) is waited out exactly once instead of racing into a
    /// second client.
    async fn connected_client(&self) -> anyhow::Result<ConvexClient> {
        if let Some(c) = self.client.read().await.as_ref() {
            return Ok(c.clone());
        }
        let _guard = self.build_lock.lock().await;
        if let Some(c) = self.client.read().await.as_ref() {
            return Ok(c.clone());
        }
        self.build_locked().await
    }

    /// Build a fresh client and install it. **Caller must hold [build_lock].**
    ///
    /// monkeyhub patch. Never holds the `RwLock` write guard across the build —
    /// that would park every reader for the whole of it.
    async fn build_locked(&self) -> anyhow::Result<ConvexClient> {
        let gen = self.generation.fetch_add(1, Ordering::SeqCst) + 1;
        let state_sender = self.state_change_sender.lock().clone();
        println!("RUST: build_locked() gen={} sender={:?}", gen, state_sender.is_some());
        let gen_sender = state_sender.map(|out| self.spawn_state_forwarder(out, gen));

        let url = self.deployment_url.clone();
        let client_id = self.client_id.to_owned();

        // Spawned on `self.rt` on purpose. `build()` calls bare `tokio::spawn`
        // internally for the client worker and the socket worker, so this pins
        // both to the runtime this struct owns rather than whatever executor
        // flutter_rust_bridge happened to run us on. That is what makes
        // abort-on-drop deterministic, and abort-on-drop is the entire
        // mechanism behind [force_reconnect].
        let fresh = self
            .rt
            .spawn(async move {
                println!("RUST: Building ConvexClient directly (no task spawn)");
                let mut builder =
                    ConvexClientBuilder::new(url.as_str()).with_client_id(&client_id);
                // Register the state change callback BEFORE building.
                if let Some(sender) = gen_sender {
                    builder = builder.with_on_state_change(sender);
                } else {
                    println!("RUST WARNING: No sender available - state changes will not be emitted");
                }
                println!("RUST: Calling builder.build() - connection will start now");
                builder.build().await
            })
            .await??;

        println!("RUST: ConvexClient built successfully (gen={})", gen);
        *self.client.write().await = Some(fresh.clone());
        Ok(fresh)
    }

    /// Tear the socket down and build a fresh client, on the same runtime and
    /// the same state channel.
    ///
    /// monkeyhub patch — the whole reason this file was touched. Dropping the
    /// last `ConvexClient` clone aborts its worker (`ConvexClient::drop` →
    /// `Arc::try_unwrap(listen_handle).abort()`), which drops the
    /// `WebSocketManager`, whose own `Drop` aborts the socket worker and closes
    /// the TCP stream. That is the only way to close this socket; the client
    /// exposes nothing else.
    ///
    /// Two things the caller must know:
    ///
    ///  * **`true` does not mean "connected".** `build()` returns as soon as
    ///    the socket worker is spawned — it does not await the handshake. It
    ///    means "a fresh client exists". Verify with a real round-trip.
    ///  * **Every existing subscription is gone.** Their streams end and the
    ///    per-subscription tasks exit through the `None` arm in
    ///    [internal_subscribe]. The Dart side owns re-registration (see
    ///    `SubscriptionRegistry`); replaying here would require Rust to hold
    ///    the Dart callbacks, which it does not.
    ///
    /// The tokio runtime is NOT dropped — only the client in the slot is
    /// replaced. Dropping a multi-thread `Runtime` from an FFI drop context
    /// blocks the calling thread and can panic outright, which is why the
    /// alternative of rebuilding the whole `MobileConvexClient` from Dart was
    /// rejected.
    #[frb]
    pub async fn force_reconnect(&self) -> Result<bool, ClientError> {
        let _guard = self.build_lock.lock().await;
        println!("RUST: force_reconnect() tearing down current client");
        // Take first, then drop with no lock held.
        let old = self.client.write().await.take();
        drop(old);
        self.build_locked().await?;
        Ok(true)
    }

    /// Wrap the app-facing state channel in a generation-stamped forwarder.
    ///
    /// monkeyhub patch. An aborted socket worker can still have a
    /// `Connecting`/`Connected` in flight; without this stamp it would land in
    /// the app's stream after the swap and be read as news about the new
    /// socket.
    fn spawn_state_forwarder(
        &self,
        out: tokio::sync::mpsc::Sender<ConvexWebSocketState>,
        gen: u64,
    ) -> tokio::sync::mpsc::Sender<ConvexWebSocketState> {
        let (tx, mut rx) = tokio::sync::mpsc::channel::<ConvexWebSocketState>(64);
        let current = self.generation.clone();
        self.rt.spawn(async move {
            while let Some(state) = rx.recv().await {
                if current.load(Ordering::SeqCst) != gen {
                    continue; // a client that is no longer ours
                }
                let _ = out.try_send(state);
            }
            // Ends when the aborted worker drops its sender.
        });
        tx
    }

    /// Snapshot the current client without building one. Used by long-lived
    /// loops that must not pin a stale client across a rebuild.
    async fn current_client(
        slot: &tokio::sync::RwLock<Option<ConvexClient>>,
    ) -> Option<ConvexClient> {
        slot.read().await.clone()
    }

    /// Executes a query on the Convex backend.
    #[frb]
    pub async fn query(
        &self,
        name: String,
        args: HashMap<String, String>,
    ) -> Result<String, ClientError> {
        let result = self.internal_query(name, args).await?;
        debug!("got the result");
        handle_direct_function_result(result)
    }

    /// Internal method for query logic.
    ///
    /// monkeyhub patch: spawned on our runtime and bounded. A one-shot query in
    /// convex-rs is `subscribe().next()`, so on a dead socket it parks rather
    /// than failing — and the clone it holds defers the worker abort that
    /// [force_reconnect] depends on. See [RUST_OP_TIMEOUT].
    async fn internal_query(
        &self,
        name: String,
        args: HashMap<String, String>,
    ) -> anyhow::Result<FunctionResult> {
        let mut client = self.connected_client().await?;
        debug!("got the client");
        self.rt
            .spawn(async move {
                tokio::time::timeout(
                    RUST_OP_TIMEOUT,
                    client.query(name.as_str(), parse_json_args(args)),
                )
                .await
            })
            .await?
            .map_err(|_| anyhow::anyhow!("QueryTimeout"))?
    }

    /// Subscribes to real-time updates from a Convex query.
    #[frb]
    pub async fn subscribe(
        &self,
        name: String,
        args: HashMap<String, String>,
        on_update: impl Fn(String) -> DartFnFuture<()> + Send + Sync + 'static,
        on_error: impl Fn(String, Option<String>) -> DartFnFuture<()> + Send + Sync + 'static,
    ) -> Result<SubscriptionHandle, ClientError> {
        let subscriber = Arc::new(CallbackSubscriberDartFn {
            on_update: Box::new(on_update),
            on_error: Box::new(on_error),
        });
        self.internal_subscribe(name, args, subscriber)
            .await
            .map_err(Into::into)
    }

    /// Internal method for subscription logic.
    async fn internal_subscribe(
        &self,
        name: String,
        args: HashMap<String, String>,
        subscriber: Arc<dyn QuerySubscriber>,
    ) -> anyhow::Result<SubscriptionHandle> {
        let mut client = self.connected_client().await?;
        debug!("New subscription");
        let mut subscription = client
            .subscribe(name.as_str(), parse_json_args(args))
            .await?;
        let (cancel_sender, cancel_receiver) = oneshot::channel::<()>();
        self.rt.spawn(async move {
            let cancel_fut = cancel_receiver.fuse();
            pin_mut!(cancel_fut);
            loop {
                select_biased! {
                    new_val = subscription.next().fuse() => {
                        let new_val = match new_val {
                            Some(val) => val,
                            None => {
                                log::warn!("Subscription stream ended for {}", &name);
                                break;
                            }
                        };
                        match new_val {
                            FunctionResult::Value(value) => {
                                debug!("Updating with {value:?}");
                                subscriber.on_update(serde_json::to_string(
                                    &serde_json::Value::from(value),
                                ).unwrap());
                            }
                            FunctionResult::ErrorMessage(message) => {
                                subscriber.on_error(message, None);
                            }
                            FunctionResult::ConvexError(error) => subscriber.on_error(
                                error.message,
                                Some(serde_json::ser::to_string(
                                    &serde_json::Value::from(error.data),
                                ).unwrap()),
                            ),
                        }
                    }
                    _ = cancel_fut => {
                        break;
                    }
                }
            }
            debug!("Subscription canceled");
        });
        Ok(SubscriptionHandle::new(cancel_sender))
    }

    /// Executes a mutation on the Convex backend.
    #[frb]
    pub async fn mutation(
        &self,
        name: String,
        args: HashMap<String, String>,
    ) -> Result<String, ClientError> {
        let result = self.internal_mutation(name, args).await?;
        handle_direct_function_result(result)
    }

    /// Internal method for mutation logic.
    async fn internal_mutation(
        &self,
        name: String,
        args: HashMap<String, String>,
    ) -> anyhow::Result<FunctionResult> {
        let mut client = self.connected_client().await?;
        // monkeyhub patch: bounded — see [RUST_OP_TIMEOUT].
        self.rt
            .spawn(async move {
                tokio::time::timeout(
                    RUST_OP_TIMEOUT,
                    client.mutation(&name, parse_json_args(args)),
                )
                .await
            })
            .await?
            .map_err(|_| anyhow::anyhow!("MutationTimeout"))?
    }

    /// Executes an action on the Convex backend.
    #[frb]
    pub async fn action(
        &self,
        name: String,
        args: HashMap<String, String>,
    ) -> Result<String, ClientError> {
        debug!("Running action: {}", name);
        let result = self.internal_action(name, args).await?;
        debug!("Got action result: {:?}", result);
        handle_direct_function_result(result)
    }

    /// Internal method for action logic.
    async fn internal_action(
        &self,
        name: String,
        args: HashMap<String, String>,
    ) -> anyhow::Result<FunctionResult> {
        let mut client = self.connected_client().await?;
        debug!("Running action: {}", name);
        // monkeyhub patch: bounded — see [RUST_OP_TIMEOUT].
        self.rt
            .spawn(async move {
                tokio::time::timeout(RUST_OP_TIMEOUT, client.action(&name, parse_json_args(args)))
                    .await
            })
            .await?
            .map_err(|_| anyhow::anyhow!("ActionTimeout"))?
    }

    /// Sets authentication token for the client.
    #[frb]
    pub async fn set_auth(&self, token: Option<String>) -> Result<(), ClientError> {
        Ok(self.internal_set_auth(token).await?)
    }

    /// Internal method for setting authentication.
    async fn internal_set_auth(&self, token: Option<String>) -> anyhow::Result<()> {
        let mut client = self.connected_client().await?;
        self.rt
            .spawn(async move { client.set_auth(token).await })
            .await
            .map_err(|e| e.into())
    }

    /// Sets authentication with automatic token refresh.
    ///
    /// The `fetch_token` callback is called:
    /// - Immediately to get the initial token
    /// - Automatically when the token is about to expire (60 seconds before expiry)
    ///
    /// The `on_auth_change` callback is called whenever auth state changes.
    ///
    /// Returns an AuthHandle that can be used to dispose the auth session.
    #[frb]
    pub async fn set_auth_with_refresh(
        &self,
        fetch_token: impl Fn() -> DartFnFuture<Option<String>> + Send + Sync + 'static,
        on_auth_change: impl Fn(bool) -> DartFnFuture<()> + Send + Sync + 'static,
    ) -> Result<AuthHandle, ClientError> {
        let is_authenticated = Arc::new(AtomicBool::new(false));
        let (cancel_sender, cancel_receiver) = oneshot::channel::<()>();

        // ── monkeyhub patch ──────────────────────────────────────────────────
        // Was `let client = self.connected_client().await?;` — a `ConvexClient`
        // clone captured for the life of the refresh loop, i.e. forever. Since
        // `ConvexClient::drop` only aborts the worker when the LAST clone goes,
        // that one capture would have kept every torn-down socket alive across
        // every [force_reconnect]. Hold the slot instead and re-read the
        // current client at each use. (monkeyhub does not call this today; the
        // trap is removed rather than left armed.)
        self.connected_client().await?; // ensure one exists before we start
        let client_slot = self.client.clone();
        // ── end monkeyhub patch ──────────────────────────────────────────────
        let is_auth_clone = is_authenticated.clone();

        let fetch_token = Arc::new(fetch_token);
        let on_auth_change = Arc::new(on_auth_change);

        // Buffer time before token expiry to trigger refresh (60 seconds)
        const REFRESH_BUFFER_SECS: u64 = 60;
        // Minimum refresh interval to prevent tight loops on errors
        const MIN_REFRESH_INTERVAL_SECS: u64 = 5;
        // Default refresh interval when JWT can't be decoded (5 minutes)
        const DEFAULT_REFRESH_INTERVAL_SECS: u64 = 300;

        // Spawn the token refresh loop
        self.rt.spawn(async move {
            let mut cancel_fut = cancel_receiver.fuse();
            let mut was_authenticated = false;

            loop {
                // Fetch token from Dart
                let fetch_token_clone = fetch_token.clone();
                let token_future = (fetch_token_clone)();

                let token_result = select_biased! {
                    _ = cancel_fut => {
                        // Cancelled - clear auth and exit
                        debug!("Auth refresh cancelled");
                        if let Some(mut client) = Self::current_client(&client_slot).await {
                            let _ = client.set_auth(None).await;
                        }
                        if was_authenticated {
                            let on_auth_change_clone = on_auth_change.clone();
                            let future = (on_auth_change_clone)(false);
                            let _ = future.await;
                        }
                        break;
                    }
                    token = token_future.fuse() => token,
                };

                let now_secs = SystemTime::now()
                    .duration_since(UNIX_EPOCH)
                    .unwrap()
                    .as_secs();

                match token_result {
                    Some(token) => {
                        // Set the token
                        if let Some(mut client) = Self::current_client(&client_slot).await {
                            client.set_auth(Some(token.clone())).await;
                        }

                        // Notify state change if needed
                        if !was_authenticated {
                            was_authenticated = true;
                            is_auth_clone.store(true, Ordering::SeqCst);
                            let on_auth_change_clone = on_auth_change.clone();
                            let future = (on_auth_change_clone)(true);
                            tokio::spawn(async move {
                                let _ = future.await;
                            });
                        }

                        // Decode expiry and schedule next refresh
                        let sleep_duration = if let Some(exp) = decode_jwt_expiry(&token) {
                            let refresh_at = exp.saturating_sub(REFRESH_BUFFER_SECS);
                            if refresh_at > now_secs {
                                Duration::from_secs(refresh_at - now_secs)
                            } else {
                                // Token already expired or about to, refresh immediately
                                Duration::from_secs(MIN_REFRESH_INTERVAL_SECS)
                            }
                        } else {
                            // Can't decode JWT, use default refresh interval
                            debug!("Could not decode JWT expiry, using default refresh interval");
                            Duration::from_secs(DEFAULT_REFRESH_INTERVAL_SECS)
                        };

                        debug!("Next token refresh in {:?}", sleep_duration);

                        // Sleep until refresh time or cancellation
                        let sleep_fut = tokio::time::sleep(sleep_duration).fuse();
                        pin_mut!(sleep_fut);
                        select_biased! {
                            _ = cancel_fut => {
                                debug!("Auth refresh cancelled during sleep");
                                if let Some(mut client) = Self::current_client(&client_slot).await {
                                    let _ = client.set_auth(None).await;
                                }
                                if was_authenticated {
                                    let on_auth_change_clone = on_auth_change.clone();
                                    let future = (on_auth_change_clone)(false);
                                    let _ = future.await;
                                }
                                break;
                            }
                            _ = sleep_fut => {
                                // Time to refresh, continue loop
                            }
                        }
                    }
                    None => {
                        // No token - clear auth
                        debug!("Token fetcher returned None, clearing auth");
                        if let Some(mut client) = Self::current_client(&client_slot).await {
                            let _ = client.set_auth(None).await;
                        }

                        if was_authenticated {
                            is_auth_clone.store(false, Ordering::SeqCst);
                            let on_auth_change_clone = on_auth_change.clone();
                            let future = (on_auth_change_clone)(false);
                            tokio::spawn(async move {
                                let _ = future.await;
                            });
                        }

                        // Exit the loop when fetch_token returns None
                        break;
                    }
                }
            }

            debug!("Auth refresh loop ended");
        });

        Ok(AuthHandle::new(cancel_sender, is_authenticated))
    }
}

/// Utility function to parse HashMap arguments into Convex Value format.
fn parse_json_args(raw_args: HashMap<String, String>) -> BTreeMap<String, Value> {
    raw_args
        .into_iter()
        .map(|(k, v)| {
            (
                k,
                Value::try_from(
                    serde_json::from_str::<serde_json::Value>(&v)
                        .expect("Invalid JSON data from FFI"),
                )
                .expect("Invalid Convex data from FFI"),
            )
        })
        .collect()
}

/// Utility function to handle and serialize FunctionResult into a string or error.
fn handle_direct_function_result(result: FunctionResult) -> Result<String, ClientError> {
    match result {
        FunctionResult::Value(v) => serde_json::to_string(&serde_json::Value::from(v))
            .map_err(|e| ClientError::InternalError { msg: e.to_string() }),
        FunctionResult::ConvexError(e) => Err(ClientError::ConvexError {
            data: serde_json::ser::to_string(&serde_json::Value::from(e.data)).unwrap(),
        }),
        FunctionResult::ErrorMessage(msg) => Err(ClientError::ServerError { msg }),
    }
}
