#!/usr/bin/env ruby
# Creates (or repairs) the NotificationService target in macos/Runner.xcodeproj.
#
# The Mac twin of tool/setup_ios_notification_extension.rb: the extension macOS
# wakes for a push carrying `mutable-content: 1`. It compiles the SAME source as
# the iPhone's (ios/NotificationService/NotificationService.swift and
# ios/Shared/ShareGroup.swift), so the Mac gets the sender's face, the group
# layout, the push inbox and the delivery tick without a second copy to drift.
# Platform differences live behind `#if os(macOS)` in those files.
#
# Same App ID as the iOS extension (the Mac app shares the iOS bundle id), so
# the portal capabilities (App Groups, Communication Notifications) are already
# on it; automatic signing makes the macOS profile.
#
# Safe to re-run: keyed on the target's name, file references deduped.
#
# Usage (Ruby with the xcodeproj gem, e.g. CocoaPods' own):
#   ruby tool/setup_macos_notification_extension.rb
# Also loaded from macos/Podfile's post_install.

require 'xcodeproj'

TARGET_NAME   = 'NotificationService'
APP_TARGET    = 'Runner'
APP_BUNDLE_ID = 'com.walhallaa.chatTest-20241220'
EXT_BUNDLE_ID = "#{APP_BUNDLE_ID}.NotificationService"
TEAM          = '37TC2VKVJ6'
# Communication notifications are macOS 12, which is also the app's floor.
DEPLOYMENT    = '12.0'

project_path = File.expand_path('../macos/Runner.xcodeproj', __dir__)
macos_dir    = File.expand_path('../macos', __dir__)

project = Xcodeproj::Project.open(project_path)
app = project.targets.find { |t| t.name == APP_TARGET }
unless app
  warn "[macos-notification-extension] #{APP_TARGET} target not found"
  exit 1
end

changed = false

target = project.targets.find { |t| t.name == TARGET_NAME }
unless target
  target = project.new_target(
    :app_extension, TARGET_NAME, :osx, DEPLOYMENT,
    project.products_group, :swift
  )
  changed = true
end

# Debug, Release AND Profile, matching the app; a missing one fails the build.
app.build_configurations.map(&:name).each do |name|
  next if target.build_configurations.any? { |c| c.name == name }

  base = project.build_configuration_list[name] ||
         project.build_configurations.first
  target.add_build_configuration(name, base&.type || :release)
  changed = true
end

target.build_configurations.each do |config|
  wanted = {
    'PRODUCT_NAME' => '$(TARGET_NAME)',
    'PRODUCT_BUNDLE_IDENTIFIER' => EXT_BUNDLE_ID,
    'INFOPLIST_FILE' => 'NotificationService/Info.plist',
    'CODE_SIGN_ENTITLEMENTS' =>
      'NotificationService/NotificationService.entitlements',
    'CODE_SIGN_STYLE' => 'Automatic',
    'DEVELOPMENT_TEAM' => TEAM,
    'MACOSX_DEPLOYMENT_TARGET' => DEPLOYMENT,
    'SDKROOT' => 'macosx',
    'SWIFT_VERSION' => '5.0',
    'SKIP_INSTALL' => 'YES',
    'ENABLE_HARDENED_RUNTIME' => 'YES',
    'LD_RUNPATH_SEARCH_PATHS' => [
      '$(inherited)',
      '@executable_path/../Frameworks',
      '@executable_path/../../../../Frameworks',
    ],
    'CLANG_ENABLE_MODULES' => 'YES',
    'GENERATE_INFOPLIST_FILE' => 'NO',
    # The extension links nothing from CocoaPods. On macOS the PROJECT-level
    # configs include Pods-Runner.*.xcconfig (via Flutter-Release.xcconfig), so
    # without this the extension inherits `-ObjC -framework google_sign_in_ios
    # ...`; that plugin is a static framework needing FlutterMacOS, and the
    # archive fails with undefined Flutter* symbols (1.3.145, 2026-11-08).
    # An explicit empty value overrides $(inherited).
    'OTHER_LDFLAGS' => '',
  }
  wanted.each do |key, value|
    next if config.build_settings[key] == value

    config.build_settings[key] = value
    changed = true
  end
end

# $(FLUTTER_BUILD_NAME)/$(FLUTTER_BUILD_NUMBER) in the extension's Info.plist
# come from ephemeral/Flutter-Generated.xcconfig. Without it the keys expand to
# nothing and App Store Connect rejects the upload (version mismatch with the
# container app). See the iOS script for the full story.
generated = project.files.find do |f|
  File.basename(f.path.to_s) == 'Flutter-Generated.xcconfig'
end
if generated
  target.build_configurations.each do |config|
    next if config.base_configuration_reference == generated

    config.base_configuration_reference = generated
    changed = true
  end
else
  warn '[setup_macos_notification_extension] Flutter-Generated.xcconfig not ' \
       'in the project — the extension will build with no version number'
end

def group_for(project, name, path)
  project.main_group[name] || project.main_group.new_group(name, path)
end

def file_ref(group, basename)
  group.files.find { |f| File.basename(f.path.to_s) == basename } ||
    group.new_reference(basename)
end

def add_source(target, ref)
  phase = target.source_build_phase
  return false if phase.files_references.include?(ref)

  phase.add_file_reference(ref)
  true
end

# Mac-only plist + entitlements.
ext_group = group_for(project, TARGET_NAME, TARGET_NAME)
file_ref(ext_group, 'Info.plist')
file_ref(ext_group, 'NotificationService.entitlements')

# The iOS sources, compiled here too.
ios_ext_group = group_for(project, 'iOSNotificationService', '../ios/NotificationService')
changed = true if add_source(target, file_ref(ios_ext_group, 'NotificationService.swift'))

# ShareGroup.swift in BOTH binaries: the extension stages, the app takes.
shared_group = group_for(project, 'iOSShared', '../ios/Shared')
shared = file_ref(shared_group, 'ShareGroup.swift')
changed = true if add_source(target, shared)
changed = true if add_source(app, shared)

# Embed in Contents/PlugIns, or macOS never finds it.
embed = app.copy_files_build_phases.find { |p| p.name == 'Embed App Extensions' }
unless embed
  embed = app.new_copy_files_build_phase('Embed App Extensions')
  embed.symbol_dst_subfolder_spec = :plug_ins
  changed = true
end
product = target.product_reference
unless embed.files_references.include?(product)
  build_file = embed.add_file_reference(product)
  build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  changed = true
end
unless app.dependencies.any? { |d| d.target&.uuid == target.uuid }
  app.add_dependency(target)
  changed = true
end

%w[UserNotifications.framework Intents.framework].each do |name|
  next if target.frameworks_build_phase.files.any? { |f| f.display_name == name }

  ref = project.frameworks_group.new_file("System/Library/Frameworks/#{name}")
  ref.source_tree = 'SDKROOT'
  target.frameworks_build_phase.add_file_reference(ref)
  changed = true
end

if changed
  project.save
  puts "[setup_macos_notification_extension] configured #{TARGET_NAME} (#{EXT_BUNDLE_ID})"
else
  puts "[setup_macos_notification_extension] #{TARGET_NAME} already configured"
end

missing = [
  File.join(macos_dir, 'NotificationService/Info.plist'),
  File.join(macos_dir, 'NotificationService/NotificationService.entitlements'),
  File.join(macos_dir, '../ios/NotificationService/NotificationService.swift'),
  File.join(macos_dir, '../ios/Shared/ShareGroup.swift'),
].reject { |p| File.exist?(p) }
unless missing.empty?
  warn "[setup_macos_notification_extension] MISSING on disk: #{missing.join(', ')}"
  exit 1
end
