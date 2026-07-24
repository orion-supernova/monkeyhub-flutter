#include "flutter_window.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <objbase.h>
#include <shobjidl_core.h>

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

#include "flutter/generated_plugin_registrant.h"

namespace {

// Kept alive for the process lifetime (single top-level window).
ITaskbarList3* g_taskbar = nullptr;
ULONG_PTR g_gdiplus_token = 0;
std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
    g_badge_channel;

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

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
