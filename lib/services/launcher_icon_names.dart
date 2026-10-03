/// Maps an in-app `AppTheme.id` to the alternate-icon name used on the
/// platform side (iOS `CFBundleAlternateIcons` keys, Android `<activity-alias>`
/// `android:name` values, and the corresponding PNG filenames).
///
/// For most themes this is identity — the theme id IS the alt-icon name.
/// A couple of names are aliased because the iOS 26 simulator's alt-icon
/// subsystem silently rejected the original names: `setAlternateIconName`
/// returned success but the displayed icon stayed as the system placeholder.
/// Renaming the affected entries forces the OS to see them as brand-new
/// icons with no cached state.
///
/// The theme ids stored in `SettingsStore.manualLogoThemeId` and used by
/// `ThemeController` stay unchanged — only the platform-facing icon name
/// is rewritten.
String launcherIconNameForThemeId(String themeId) {
  switch (themeId) {
    case 'basic_daylight':
      return 'mh_daylight';
    case 'basic_forest':
      return 'mh_forest';
    // Themes without an alternate icon of their own yet borrow the nearest
    // existing one (see [kBorrowedIconThemeIds]).
    case 'paper':
      return 'vault_ivory';
    case 'dot':
      return 'basic_graphite';
    case 'bloom':
      return 'basic_rose';
    default:
      return themeId;
  }
}

/// Themes whose launcher icon is borrowed from another theme because no iOS
/// alternate icon has been generated and registered for them yet.
///
/// The icon generator skips these (rendering them would overwrite the owner's
/// PNGs), and the icon picker does not offer them as a separate choice — the
/// tile would show this theme's mark and apply someone else's.
const kBorrowedIconThemeIds = {'paper', 'dot', 'bloom'};
