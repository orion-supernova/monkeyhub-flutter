#include "flutter_window.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <objbase.h>
#include <shobjidl_core.h>
#include <shlwapi.h>

// GDI+ uses unqualified min/max; the project defines NOMINMAX, so surface the
// std versions into the Gdiplus namespace before including its headers.
#include <algorithm>
namespace Gdiplus {
using std::max;
using std::min;
}  // namespace Gdiplus
#include <gdiplus.h>

#include <memory>
#include <optional>
#include <string>
#include <variant>
#include <vector>

#include "flutter/generated_plugin_registrant.h"
#include "resource.h"
#include "store_update.h"

// Windows 10 2004 SDK value; older SDK headers lack the name.
#ifndef WDA_EXCLUDEFROMCAPTURE
#define WDA_EXCLUDEFROMCAPTURE 0x00000011
#endif

namespace {

// Kept alive for the process lifetime (single top-level window).
ITaskbarList3* g_taskbar = nullptr;
ULONG_PTR g_gdiplus_token = 0;
std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
    g_badge_channel;
std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
    g_capture_channel;
std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
    g_launcher_icon_channel;
// The icons currently set on the window by monkeyhub/launcher_icon; owned
// here, destroyed when replaced.
HICON g_window_icon_big = nullptr;
HICON g_window_icon_small = nullptr;

// Decode PNG bytes into an HICON of px x px (alpha kept). Null on failure.
HICON IconFromPng(const std::vector<uint8_t>& png, int px) {
  using namespace Gdiplus;
  IStream* stream = SHCreateMemStream(png.data(), static_cast<UINT>(png.size()));
  if (stream == nullptr) {
    return nullptr;
  }
  HICON icon = nullptr;
  {
    Bitmap source(stream);
    if (source.GetLastStatus() == Ok) {
      Bitmap scaled(px, px, PixelFormat32bppARGB);
      Graphics g(&scaled);
      g.SetInterpolationMode(InterpolationModeHighQualityBicubic);
      g.SetPixelOffsetMode(PixelOffsetModeHalf);
      g.Clear(Color(0, 0, 0, 0));
      g.DrawImage(&source, 0, 0, px, px);
      scaled.GetHICON(&icon);
    }
  }
  stream->Release();
  return icon;
}

// Give the window its big (Alt-Tab, taskbar button) and small (title bar)
// icons. [png] empty restores the icon embedded in the exe.
bool SetWindowIcons(HWND hwnd, const std::vector<uint8_t>& png) {
  const UINT dpi = GetDpiForWindow(hwnd);
  const int big_px = GetSystemMetricsForDpi(SM_CXICON, dpi);
  const int small_px = GetSystemMetricsForDpi(SM_CXSMICON, dpi);
  HICON big_icon = nullptr;
  HICON small_icon = nullptr;
  if (png.empty()) {
    HINSTANCE instance = GetModuleHandle(nullptr);
    big_icon = static_cast<HICON>(LoadImage(
        instance, MAKEINTRESOURCE(IDI_APP_ICON), IMAGE_ICON, big_px, big_px,
        LR_DEFAULTCOLOR));
    small_icon = static_cast<HICON>(LoadImage(
        instance, MAKEINTRESOURCE(IDI_APP_ICON), IMAGE_ICON, small_px, small_px,
        LR_DEFAULTCOLOR));
  } else {
    big_icon = IconFromPng(png, big_px);
    small_icon = IconFromPng(png, small_px);
  }
  if (big_icon == nullptr || small_icon == nullptr) {
    if (big_icon != nullptr) DestroyIcon(big_icon);
    if (small_icon != nullptr) DestroyIcon(small_icon);
    return false;
  }
  SendMessage(hwnd, WM_SETICON, ICON_BIG, reinterpret_cast<LPARAM>(big_icon));
  SendMessage(hwnd, WM_SETICON, ICON_SMALL,
              reinterpret_cast<LPARAM>(small_icon));
  if (g_window_icon_big != nullptr) DestroyIcon(g_window_icon_big);
  if (g_window_icon_small != nullptr) DestroyIcon(g_window_icon_small);
  g_window_icon_big = big_icon;
  g_window_icon_small = small_icon;
  return true;
}

// Render a red count bubble as an HICON for the taskbar overlay. Caller owns
// the returned icon and must DestroyIcon it.
HICON CreateBadgeIcon(int count) {
  using namespace Gdiplus;
  const int size = 32;
  Bitmap bmp(size, size, PixelFormat32bppARGB);
  Graphics g(&bmp);
  g.SetSmoothingMode(SmoothingModeAntiAlias);
  g.Clear(Color(0, 0, 0, 0));

  SolidBrush red(Color(255, 0xE5, 0x39, 0x35));  // #E53935
  g.FillEllipse(&red, 0, 0, size - 1, size - 1);

  std::wstring label = count > 99 ? L"99+" : std::to_wstring(count);
  FontFamily family(L"Segoe UI");
  REAL font_px = label.size() > 2 ? 12.0f : 18.0f;
  Font font(&family, font_px, FontStyleBold, UnitPixel);
  SolidBrush white(Color(255, 255, 255, 255));
  StringFormat fmt;
  fmt.SetAlignment(StringAlignmentCenter);
  fmt.SetLineAlignment(StringAlignmentCenter);
  RectF rect(0, 0, static_cast<REAL>(size), static_cast<REAL>(size));
  g.DrawString(label.c_str(), -1, &font, rect, &fmt, &white);

  HICON icon = nullptr;
  bmp.GetHICON(&icon);
  return icon;
}

void UpdateTaskbarBadge(HWND hwnd, int count) {
  if (g_taskbar == nullptr) {
    return;
  }
  if (count <= 0) {
    g_taskbar->SetOverlayIcon(hwnd, nullptr, L"");
    return;
  }
  HICON icon = CreateBadgeIcon(count);
  g_taskbar->SetOverlayIcon(hwnd, icon, L"Unread");  // copies the icon
  if (icon != nullptr) {
    DestroyIcon(icon);
  }
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // monkeyhub/badge — taskbar overlay badge (mirrors the iOS/macOS app-icon
  // badge). Driven by BadgeManager's unread/request count.
  Gdiplus::GdiplusStartupInput gdiplus_input;
  Gdiplus::GdiplusStartup(&g_gdiplus_token, &gdiplus_input, nullptr);
  CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  if (SUCCEEDED(CoCreateInstance(CLSID_TaskbarList, nullptr,
                                 CLSCTX_INPROC_SERVER,
                                 IID_PPV_ARGS(&g_taskbar)))) {
    g_taskbar->HrInit();
  }
  HWND badge_hwnd = GetHandle();
  g_badge_channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "monkeyhub/badge",
          &flutter::StandardMethodCodec::GetInstance());
  g_badge_channel->SetMethodCallHandler(
      [badge_hwnd](
          const flutter::MethodCall<flutter::EncodableValue>& call,
          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
              result) {
        if (call.method_name() != "set") {
          result->NotImplemented();
          return;
        }
        int count = 0;
        const auto* args =
            std::get_if<flutter::EncodableMap>(call.arguments());
        if (args != nullptr) {
          auto it = args->find(flutter::EncodableValue("count"));
          if (it != args->end()) {
            if (const auto* v = std::get_if<int32_t>(&it->second)) {
              count = *v;
            } else if (const auto* v64 = std::get_if<int64_t>(&it->second)) {
              count = static_cast<int>(*v64);
            }
          }
        }
        UpdateTaskbarBadge(badge_hwnd, count);
        result->Success();
      });

  // monkeyhub/capture — screen-capture protection (CaptureProtection in
  // lib/privacy/capture_protection.dart). WDA_EXCLUDEFROMCAPTURE removes the
  // window from every capture path that goes through the compositor:
  // PrintScreen, Snipping Tool, Game Bar, OBS, Teams/Zoom shares. Windows 10
  // 2004+; on older builds the call fails, so fall back to WDA_MONITOR,
  // which at least turns the window black in a capture.
  HWND capture_hwnd = GetHandle();
  g_capture_channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "monkeyhub/capture",
          &flutter::StandardMethodCodec::GetInstance());
  g_capture_channel->SetMethodCallHandler(
      [capture_hwnd](
          const flutter::MethodCall<flutter::EncodableValue>& call,
          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
              result) {
        if (call.method_name() == "isCaptured") {
          result->Success(flutter::EncodableValue(false));
          return;
        }
        if (call.method_name() != "setEnabled") {
          result->NotImplemented();
          return;
        }
        bool enabled = false;
        const auto* args =
            std::get_if<flutter::EncodableMap>(call.arguments());
        if (args != nullptr) {
          auto it = args->find(flutter::EncodableValue("enabled"));
          if (it != args->end()) {
            if (const auto* v = std::get_if<bool>(&it->second)) enabled = *v;
          }
        }
        if (!enabled) {
          SetWindowDisplayAffinity(capture_hwnd, WDA_NONE);
        } else if (!SetWindowDisplayAffinity(capture_hwnd,
                                             WDA_EXCLUDEFROMCAPTURE)) {
          SetWindowDisplayAffinity(capture_hwnd, WDA_MONITOR);
        }
        result->Success();
      });

  // monkeyhub/launcher_icon — the app icon picked in Settings
  // (LauncherIconService). Sets the window's big and small icons, which is
  // what the title bar, the taskbar button and Alt-Tab draw. It cannot change
  // the exe's embedded icon, a pinned shortcut, the Start tile or, for the
  // MSIX/Store build, the package logo: those are read from disk / the
  // manifest and stay as shipped.
  HWND icon_hwnd = GetHandle();
  g_launcher_icon_channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "monkeyhub/launcher_icon",
          &flutter::StandardMethodCodec::GetInstance());
  g_launcher_icon_channel->SetMethodCallHandler(
      [icon_hwnd](
          const flutter::MethodCall<flutter::EncodableValue>& call,
          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
              result) {
        if (call.method_name() == "supportsAlternateIcons") {
          result->Success(flutter::EncodableValue(true));
          return;
        }
        if (call.method_name() != "setIconImage") {
          result->NotImplemented();
          return;
        }
        std::vector<uint8_t> png;
        const auto* args =
            std::get_if<flutter::EncodableMap>(call.arguments());
        if (args != nullptr) {
          auto it = args->find(flutter::EncodableValue("png"));
          if (it != args->end()) {
            if (const auto* bytes =
                    std::get_if<std::vector<uint8_t>>(&it->second)) {
              png = *bytes;
            }
          }
        }
        if (!SetWindowIcons(icon_hwnd, png)) {
          result->Error("bad_image", "Could not build the window icon");
          return;
        }
        result->Success();
      });

  // monkeyhub/store_update — the Microsoft Store's own update check and
  // in-place installer (lib/update/windows_store_update.dart).
  RegisterStoreUpdateChannel(flutter_controller_->engine()->messenger(),
                             GetHandle());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  g_badge_channel = nullptr;
  g_capture_channel = nullptr;
  UnregisterStoreUpdateChannel();
  if (g_taskbar != nullptr) {
    g_taskbar->Release();
    g_taskbar = nullptr;
  }
  if (g_gdiplus_token != 0) {
    Gdiplus::GdiplusShutdown(g_gdiplus_token);
    g_gdiplus_token = 0;
  }

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  // A Store answer finishing on a WinRT thread, posted here to reach Dart
  // from the platform thread.
  if (HandleStoreUpdateMessage(message, lparam)) {
    return 0;
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
