/// Whether host (LAN) ICE candidates are allowed. Direct same-network paths
/// give the best call quality but make iOS show the one-time Local Network
/// permission prompt. Build with `--dart-define=CALL_ALLOW_LAN=false` to
/// restore the prompt-free behavior (srflx/relay paths only).
const bool kAllowLanCandidates =
    bool.fromEnvironment('CALL_ALLOW_LAN', defaultValue: true);
