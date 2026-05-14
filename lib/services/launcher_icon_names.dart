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
    default:
      return themeId;
  }
}
