#include "store_update.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <shobjidl_core.h>

#include <winrt/Windows.ApplicationModel.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Services.Store.h>

#include <functional>
#include <memory>
#include <string>

namespace {

using winrt::Windows::ApplicationModel::Package;
using winrt::Windows::Foundation::AsyncStatus;
using winrt::Windows::Foundation::Collections::IVectorView;
using winrt::Windows::Services::Store::StoreContext;
using winrt::Windows::Services::Store::StorePackageUpdate;
using winrt::Windows::Services::Store::StorePackageUpdateResult;
using winrt::Windows::Services::Store::StorePackageUpdateState;

using Result = flutter::MethodResult<flutter::EncodableValue>;
using Updates = IVectorView<StorePackageUpdate>;
using UpdatesOp =
    winrt::Windows::Foundation::IAsyncOperation<Updates>;
using InstallOp = winrt::Windows::Foundation::IAsyncOperationWithProgress<
    StorePackageUpdateResult,
    winrt::Windows::Services::Store::StorePackageUpdateStatus>;

std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> g_channel;
HWND g_hwnd = nullptr;
StoreContext g_context{nullptr};

// Runs [fn] on the platform thread, via the runner window's message loop.
// If the window is already gone the work is dropped, which also drops the
// pending MethodResult: the engine is shutting down with it.
void OnPlatformThread(std::function<void()> fn) {
  auto* task = new std::function<void()>(std::move(fn));
  if (g_hwnd == nullptr ||
      !PostMessage(g_hwnd, kStoreUpdateMessage, 0,
                   reinterpret_cast<LPARAM>(task))) {
    delete task;
  }
}

// One context per process, bound to the window so the Store's install dialog
// has an owner. A desktop app must do this before any Request* call; it is
// harmless for the plain queries. Throws when the app has no Store identity
// (a dev run or a sideloaded build).
StoreContext Context() {
  if (!g_context) {
    g_context = StoreContext::GetDefault();
    g_context.as<::IInitializeWithWindow>()->Initialize(g_hwnd);
  }
  return g_context;
}

// The version of the update for this app's own package, as "1.3.134.0".
// Empty when the list holds only optional packages.
std::string MainPackageVersion(const Updates& updates) {
  const auto own = Package::Current().Id().Name();
  for (const auto& u : updates) {
    const auto id = u.Package().Id();
    if (id.Name() != own) continue;
    const auto v = id.Version();
    return std::to_string(v.Major) + "." + std::to_string(v.Minor) + "." +
           std::to_string(v.Build) + "." + std::to_string(v.Revision);
  }
  return "";
}

// Asks the Store for this app's pending updates and hands them to [then] on
// the platform thread. [then] receives nullptr when the Store couldn't say.
void FetchUpdates(std::shared_ptr<Result> result,
                  std::function<void(std::shared_ptr<Result>, Updates)> then) {
  UpdatesOp op{nullptr};
  try {
    op = Context().GetAppAndOptionalStorePackageUpdatesAsync();
  } catch (const winrt::hresult_error& e) {
    result->Error("unavailable", winrt::to_string(e.message()));
    return;
  }
  op.Completed([result, then](const UpdatesOp& done, AsyncStatus status) {
    Updates updates{nullptr};
    if (status == AsyncStatus::Completed) {
      try {
        updates = done.GetResults();
      } catch (...) {
        updates = nullptr;
      }
    }
    OnPlatformThread([result, then, updates]() { then(result, updates); });
  });
}

void HandleCheck(std::shared_ptr<Result> result) {
  FetchUpdates(result, [](std::shared_ptr<Result> r, Updates updates) {
    if (!updates) {
      r->Error("unavailable", "The Store did not answer");
      return;
    }
    flutter::EncodableMap reply;
    reply[flutter::EncodableValue("available")] =
        flutter::EncodableValue(updates.Size() > 0);
    try {
      const auto version = MainPackageVersion(updates);
      if (!version.empty()) {
        reply[flutter::EncodableValue("version")] =
            flutter::EncodableValue(version);
      }
    } catch (...) {
      // No package identity to compare against: the yes/no still stands.
    }
    r->Success(flutter::EncodableValue(reply));
  });
}

void HandleInstall(std::shared_ptr<Result> result) {
  FetchUpdates(result, [](std::shared_ptr<Result> r, Updates updates) {
    if (!updates || updates.Size() == 0) {
      r->Success(flutter::EncodableValue(false));
      return;
    }
    // Back on the platform thread here, which the Store's dialog requires.
    InstallOp op{nullptr};
    try {
      op = Context().RequestDownloadAndInstallStorePackageUpdatesAsync(updates);
    } catch (...) {
      r->Success(flutter::EncodableValue(false));
      return;
    }
    op.Completed([r](const InstallOp& done, AsyncStatus status) {
      bool installed = false;
      if (status == AsyncStatus::Completed) {
        try {
          installed = done.GetResults().OverallState() ==
                      StorePackageUpdateState::Completed;
        } catch (...) {
          installed = false;
        }
      }
      OnPlatformThread(
          [r, installed]() { r->Success(flutter::EncodableValue(installed)); });
    });
  });
}

}  // namespace

void RegisterStoreUpdateChannel(flutter::BinaryMessenger* messenger,
                                HWND hwnd) {
  g_hwnd = hwnd;
  g_channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "monkeyhub/store_update",
          &flutter::StandardMethodCodec::GetInstance());
  g_channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<Result> result) {
        // Shared rather than unique: the result rides through WinRT
        // completion handlers, which must be copyable.
        std::shared_ptr<Result> shared(std::move(result));
        if (call.method_name() == "check") {
          HandleCheck(shared);
        } else if (call.method_name() == "install") {
          HandleInstall(shared);
        } else {
          shared->NotImplemented();
        }
      });
}

bool HandleStoreUpdateMessage(UINT message, LPARAM lparam) {
  if (message != kStoreUpdateMessage) return false;
  std::unique_ptr<std::function<void()>> task(
      reinterpret_cast<std::function<void()>*>(lparam));
  if (task && *task) (*task)();
  return true;
}

void UnregisterStoreUpdateChannel() {
  g_channel = nullptr;
  g_context = nullptr;
  g_hwnd = nullptr;
}
