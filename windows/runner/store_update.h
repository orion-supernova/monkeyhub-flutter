#ifndef RUNNER_STORE_UPDATE_H_
#define RUNNER_STORE_UPDATE_H_

#include <flutter/binary_messenger.h>
#include <windows.h>

// monkeyhub/store_update: the Microsoft Store's own update check and in-place
// installer, for lib/update/windows_store_update.dart.
//
// StoreContext answers asynchronously on a thread-pool thread, while Flutter
// method results must be delivered on the platform thread. Each completion is
// posted back to the runner window as kStoreUpdateMessage, which
// FlutterWindow::MessageHandler hands to HandleStoreUpdateMessage.
constexpr UINT kStoreUpdateMessage = WM_APP + 0x5D;

void RegisterStoreUpdateChannel(flutter::BinaryMessenger* messenger,
                                HWND hwnd);

// True when [message] was ours (and has been handled).
bool HandleStoreUpdateMessage(UINT message, LPARAM lparam);

void UnregisterStoreUpdateChannel();

#endif  // RUNNER_STORE_UPDATE_H_
