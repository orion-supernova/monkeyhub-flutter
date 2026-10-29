#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include <dlfcn.h>
#include <string.h>

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  // monkeyhub/badge channel — sets the launcher badge count. Kept alive for
  // the process lifetime; cleared in dispose.
  FlMethodChannel* badge_channel;
  // monkeyhub/window channel — raises the window when a desktop notification
  // is clicked (LinuxNotifier). Same lifetime as badge_channel.
  FlMethodChannel* window_channel;
  // The one main window. Set by the first activate; a later activate (the
  // app launched again while running) presents it instead of opening another.
  GtkWindow* window;
  // The tray icon (an AppIndicator, null when no AppIndicator library is
  // installed) and its two menu items, relabelled from Dart.
  gpointer indicator;
  GtkWidget* tray_open_item;
  GtkWidget* tray_quit_item;
  // When the close button last asked Dart what to do, 0 when no question is
  // open. See window_delete_cb.
  gint64 close_pending_since;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Push the unread count to the launcher icon via the Unity LauncherEntry DBus
// protocol (honored by the Ubuntu dock, KDE, Dash-to-Dock, etc.). Listeners
// key off the app_uri in the payload; the object path is a stable hash of it.
static void update_launcher_count(int64_t count) {
  g_autoptr(GError) error = nullptr;
  g_autoptr(GDBusConnection) bus =
      g_bus_get_sync(G_BUS_TYPE_SESSION, nullptr, &error);
  if (bus == nullptr) {
    g_warning("badge: no session bus: %s", error->message);
    return;
  }

  g_autofree gchar* app_uri =
      g_strdup_printf("application://%s.desktop", APPLICATION_ID);
  g_autofree gchar* object_path = g_strdup_printf(
      "/com/canonical/unity/launcherentry/%u", g_str_hash(app_uri));

  GVariantBuilder props;
  g_variant_builder_init(&props, G_VARIANT_TYPE("a{sv}"));
  g_variant_builder_add(&props, "{sv}", "count", g_variant_new_int64(count));
  g_variant_builder_add(&props, "{sv}", "count-visible",
                        g_variant_new_boolean(count > 0));

  g_dbus_connection_emit_signal(
      bus, nullptr, object_path, "com.canonical.Unity.LauncherEntry", "Update",
      g_variant_new("(sa{sv})", app_uri, &props), &error);
  if (error != nullptr) {
    g_warning("badge: emit failed: %s", error->message);
  }
}

// Handles monkeyhub/badge method calls from Dart (BadgeManager).
static void badge_method_call_cb(FlMethodChannel* channel,
                                 FlMethodCall* method_call, gpointer user_data) {
  g_autoptr(FlMethodResponse) response = nullptr;
  if (strcmp(fl_method_call_get_name(method_call), "set") == 0) {
    int64_t count = 0;
    FlValue* args = fl_method_call_get_args(method_call);
    if (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "count");
      if (v != nullptr && fl_value_get_type(v) == FL_VALUE_TYPE_INT) {
        count = fl_value_get_int(v);
      }
    }
    update_launcher_count(count);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond(method_call, response, &error)) {
    g_warning("badge: failed to respond: %s", error->message);
  }
}

// ── System tray ─────────────────────────────────────────────────────────
//
// Closing the window hides it to the tray, Steam-style, so the Convex socket
// stays up and messages keep arriving as desktop notifications (Linux has no
// push service: a closed app hears nothing). Quit lives in the tray menu.
//
// The icon is a StatusNotifierItem through libayatana-appindicator (the old
// libappindicator as a fallback), which KDE, XFCE, Cinnamon, MATE, Budgie,
// waybar and Ubuntu's GNOME all show. It is dlopen'd rather than linked, so a
// system without it still launches — it just has no tray, and closing the
// window quits as it always did. Closing only hides when something is
// actually there to show the icon (a StatusNotifierWatcher on the bus):
// stock GNOME has none, and hiding there would leave a running app with no
// way back except launching it again.

typedef gpointer (*AppIndicatorNewFn)(const gchar*, const gchar*, int);
typedef void (*AppIndicatorSetStatusFn)(gpointer, int);
typedef void (*AppIndicatorSetMenuFn)(gpointer, GtkMenu*);
typedef void (*AppIndicatorSetTargetFn)(gpointer, GtkWidget*);
typedef void (*AppIndicatorSetTitleFn)(gpointer, const gchar*);

// From app-indicator.h, which is not included since nothing is linked.
static const int kIndicatorCategoryCommunications = 1;
static const int kIndicatorStatusActive = 1;

static gboolean tray_host_present() {
  g_autoptr(GError) error = nullptr;
  g_autoptr(GDBusConnection) bus =
      g_bus_get_sync(G_BUS_TYPE_SESSION, nullptr, &error);
  if (bus == nullptr) return FALSE;
  g_autoptr(GVariant) reply = g_dbus_connection_call_sync(
      bus, "org.freedesktop.DBus", "/org/freedesktop/DBus",
      "org.freedesktop.DBus", "NameHasOwner",
      g_variant_new("(s)", "org.kde.StatusNotifierWatcher"),
      G_VARIANT_TYPE("(b)"), G_DBUS_CALL_FLAGS_NONE, 500, nullptr, &error);
  if (reply == nullptr) return FALSE;
  gboolean has_owner = FALSE;
  g_variant_get(reply, "(b)", &has_owner);
  return has_owner;
}

// The tarball ships its icon beside the binary; the AUR package moves it
// into the icon theme, where the bare name finds it.
static gchar* tray_icon() {
  g_autofree gchar* exe = g_file_read_link("/proc/self/exe", nullptr);
  if (exe != nullptr) {
    g_autofree gchar* dir = g_path_get_dirname(exe);
    gchar* png = g_build_filename(dir, "monkeyhub.png", nullptr);
    if (g_file_test(png, G_FILE_TEST_EXISTS)) return png;
    g_free(png);
  }
  return g_strdup("monkeyhub");
}

static void tray_open_cb(GtkMenuItem* item, gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  if (self->window != nullptr) gtk_window_present(self->window);
}

static void tray_quit_cb(GtkMenuItem* item, gpointer user_data) {
  g_application_quit(G_APPLICATION(user_data));
}

static void create_tray(MyApplication* self) {
  void* lib = dlopen("libayatana-appindicator3.so.1", RTLD_LAZY | RTLD_LOCAL);
  if (lib == nullptr) lib = dlopen("libappindicator3.so.1", RTLD_LAZY | RTLD_LOCAL);
  if (lib == nullptr) return;
  auto indicator_new =
      reinterpret_cast<AppIndicatorNewFn>(dlsym(lib, "app_indicator_new"));
  auto set_status = reinterpret_cast<AppIndicatorSetStatusFn>(
      dlsym(lib, "app_indicator_set_status"));
  auto set_menu = reinterpret_cast<AppIndicatorSetMenuFn>(
      dlsym(lib, "app_indicator_set_menu"));
  auto set_target = reinterpret_cast<AppIndicatorSetTargetFn>(
      dlsym(lib, "app_indicator_set_secondary_activate_target"));
  auto set_title = reinterpret_cast<AppIndicatorSetTitleFn>(
      dlsym(lib, "app_indicator_set_title"));
  if (indicator_new == nullptr || set_status == nullptr || set_menu == nullptr) {
    return;
  }

  GtkWidget* menu = gtk_menu_new();
  self->tray_open_item = gtk_menu_item_new_with_label("Open MonkeyHub");
  self->tray_quit_item = gtk_menu_item_new_with_label("Quit MonkeyHub");
  g_signal_connect(self->tray_open_item, "activate", G_CALLBACK(tray_open_cb),
                   self);
  g_signal_connect(self->tray_quit_item, "activate", G_CALLBACK(tray_quit_cb),
                   self);
  gtk_menu_shell_append(GTK_MENU_SHELL(menu), self->tray_open_item);
  gtk_menu_shell_append(GTK_MENU_SHELL(menu), gtk_separator_menu_item_new());
  gtk_menu_shell_append(GTK_MENU_SHELL(menu), self->tray_quit_item);
  gtk_widget_show_all(menu);

  g_autofree gchar* icon = tray_icon();
  self->indicator =
      indicator_new(APPLICATION_ID, icon, kIndicatorCategoryCommunications);
  if (self->indicator == nullptr) return;
  if (set_title != nullptr) set_title(self->indicator, "MonkeyHub");
  set_menu(self->indicator, GTK_MENU(menu));
  // Middle-click (and a plain click on hosts that send Activate) opens the
  // window; the menu is the right-click.
  if (set_target != nullptr) set_target(self->indicator, self->tray_open_item);
  set_status(self->indicator, kIndicatorStatusActive);
}

// Whether a tray icon is actually on screen right now.
static gboolean tray_shown(MyApplication* self) {
  return self->indicator != nullptr && tray_host_present();
}

// What closing the window ends up doing, as Dart decided it (LinuxAppChrome):
// "hide" to the tray, "minimize", "quit", or "none" while Dart asks the user.
static void apply_close_action(MyApplication* self, const gchar* action) {
  if (g_strcmp0(action, "hide") == 0) {
    gtk_widget_hide(GTK_WIDGET(self->window));
  } else if (g_strcmp0(action, "minimize") == 0) {
    gtk_window_iconify(self->window);
  } else if (g_strcmp0(action, "quit") == 0) {
    g_application_quit(G_APPLICATION(self));
  }
}

static void close_response_cb(GObject* object, GAsyncResult* result,
                              gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  self->close_pending_since = 0;
  g_autoptr(GError) error = nullptr;
  g_autoptr(FlMethodResponse) response = fl_method_channel_invoke_method_finish(
      FL_METHOD_CHANNEL(object), result, &error);
  FlValue* value = response == nullptr
                       ? nullptr
                       : fl_method_response_get_result(response, &error);
  if (value != nullptr && fl_value_get_type(value) == FL_VALUE_TYPE_STRING) {
    apply_close_action(self, fl_value_get_string(value));
  } else {
    // Dart could not answer: the default it would have picked for a user
    // who never chose.
    apply_close_action(self, tray_shown(self) ? "hide" : "quit");
  }
}

// The window's close button. The answer depends on a setting and, the first
// time on a desktop with no tray, on a question to the user, so the window
// stays open and Dart is asked; close_response_cb carries out its answer.
static gboolean window_delete_cb(GtkWidget* widget, GdkEvent* event,
                                 gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  // Before Flutter is up there is nobody to ask: close as the template did.
  if (self->window_channel == nullptr) return FALSE;
  const gint64 now = g_get_monotonic_time();
  if (self->close_pending_since != 0) {
    // Closed again while the first question is unanswered. A few seconds on,
    // Dart is not going to answer (hung, or busy past caring): let the window
    // close, which quits. A close is never allowed to stop working.
    return now - self->close_pending_since > 3 * G_USEC_PER_SEC ? FALSE : TRUE;
  }
  self->close_pending_since = now;
  g_autoptr(FlValue) args = fl_value_new_map();
  fl_value_set_string_take(args, "tray", fl_value_new_bool(tray_shown(self)));
  fl_method_channel_invoke_method(self->window_channel, "closeRequested", args,
                                  nullptr, close_response_cb, self);
  return TRUE;
}

// Handles monkeyhub/window method calls from Dart (LinuxNotifier, LinuxTray).
//
// `present` brings the window forward after a notification click. The
// optional `token` is the xdg-activation token the notification daemon sent
// with the click: without it a Wayland compositor treats the raise as
// unsolicited and only marks the window as wanting attention.
static void window_method_call_cb(FlMethodChannel* channel,
                                  FlMethodCall* method_call,
                                  gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  GtkWindow* window = self->window;
  g_autoptr(FlMethodResponse) response = nullptr;
  if (strcmp(fl_method_call_get_name(method_call), "setTrayLabels") == 0) {
    // The menu in the app's own language. Built in English above because it
    // exists before Dart has run.
    FlValue* args = fl_method_call_get_args(method_call);
    if (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* open = fl_value_lookup_string(args, "open");
      FlValue* quit = fl_value_lookup_string(args, "quit");
      if (self->tray_open_item != nullptr && open != nullptr &&
          fl_value_get_type(open) == FL_VALUE_TYPE_STRING) {
        gtk_menu_item_set_label(GTK_MENU_ITEM(self->tray_open_item),
                                fl_value_get_string(open));
      }
      if (self->tray_quit_item != nullptr && quit != nullptr &&
          fl_value_get_type(quit) == FL_VALUE_TYPE_STRING) {
        gtk_menu_item_set_label(GTK_MENU_ITEM(self->tray_quit_item),
                                fl_value_get_string(quit));
      }
    }
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(fl_method_call_get_name(method_call), "trayAvailable") == 0) {
    response = FL_METHOD_RESPONSE(
        fl_method_success_response_new(fl_value_new_bool(tray_shown(self))));
  } else if (strcmp(fl_method_call_get_name(method_call), "hide") == 0 ||
             strcmp(fl_method_call_get_name(method_call), "minimize") == 0 ||
             strcmp(fl_method_call_get_name(method_call), "quit") == 0) {
    // Dart's answer to a close, given after asking the user.
    apply_close_action(self, fl_method_call_get_name(method_call));
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(fl_method_call_get_name(method_call), "present") == 0) {
    FlValue* args = fl_method_call_get_args(method_call);
    if (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* token = fl_value_lookup_string(args, "token");
      if (token != nullptr && fl_value_get_type(token) == FL_VALUE_TYPE_STRING) {
        gtk_window_set_startup_id(window, fl_value_get_string(token));
      }
    }
    gtk_window_present(window);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond(method_call, response, &error)) {
    g_warning("window: failed to respond: %s", error->message);
  }
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  // Launched again while already running (possibly hidden in the tray): the
  // second process handed its activate over to this one and exited. Bring
  // the existing window back rather than starting a second app.
  if (self->window != nullptr) {
    gtk_window_present(self->window);
    return;
  }
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  self->window = window;
  g_signal_connect(window, "delete-event", G_CALLBACK(window_delete_cb), self);
  create_tray(self);

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "MonkeyHub");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "MonkeyHub");
  }

  gtk_window_set_default_size(window, 1280, 720);
  // Floor the window at the width the side rail + split shell needs
  // (`Breakpoints.split` in lib/theme/layout.dart is 720). Without it the
  // window could be dragged down to phone width and the whole chrome would
  // swap to the bottom pill mid-drag. GTK sizes are logical, so this needs no
  // scaling of its own.
  GdkGeometry min_geometry = {};
  min_geometry.min_width = 760;
  min_geometry.min_height = 560;
  gtk_window_set_geometry_hints(window, nullptr, &min_geometry,
                                GDK_HINT_MIN_SIZE);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  // monkeyhub/badge — launcher badge count (mirrors iOS/macOS app-icon badge).
  FlEngine* engine = fl_view_get_engine(view);
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->badge_channel =
      fl_method_channel_new(fl_engine_get_binary_messenger(engine),
                            "monkeyhub/badge", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      self->badge_channel, badge_method_call_cb, self, nullptr);

  // monkeyhub/window — raise on notification click, tray menu labels.
  self->window_channel =
      fl_method_channel_new(fl_engine_get_binary_messenger(engine),
                            "monkeyhub/window", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      self->window_channel, window_method_call_cb, self, nullptr);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name, and take out
  // --gapplication-replace, which is ours rather than Dart's: the Linux
  // self-updater starts the new build with it, so the new process takes the
  // single-instance name from the old one instead of handing its activate to
  // the build that is about to exit.
  GPtrArray* dart_args = g_ptr_array_new();
  for (gchar** arg = *arguments + 1; *arg != nullptr; arg++) {
    if (g_strcmp0(*arg, "--gapplication-replace") == 0) {
#if GLIB_CHECK_VERSION(2, 60, 0)
      g_application_set_flags(
          application,
          static_cast<GApplicationFlags>(g_application_get_flags(application) |
                                         G_APPLICATION_REPLACE));
#endif
      continue;
    }
    g_ptr_array_add(dart_args, g_strdup(*arg));
  }
  g_ptr_array_add(dart_args, nullptr);
  self->dart_entrypoint_arguments =
      reinterpret_cast<gchar**>(g_ptr_array_free(dart_args, FALSE));

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  g_clear_object(&self->badge_channel);
  g_clear_object(&self->window_channel);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  // Single instance, not the template's NON_UNIQUE: with the window able to
  // hide in the tray, launching again must bring THAT window back, not start
  // a second app with a second socket and a second set of notifications.
  // ALLOW_REPLACEMENT lets the self-updater's new build take over (see
  // local_command_line); the old one quits on `name-lost` by default.
#if GLIB_CHECK_VERSION(2, 60, 0)
  const GApplicationFlags flags = G_APPLICATION_ALLOW_REPLACEMENT;
#else
  const GApplicationFlags flags = G_APPLICATION_FLAGS_NONE;
#endif
  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     flags, nullptr));
}
