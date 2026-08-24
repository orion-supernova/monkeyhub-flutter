#!/usr/bin/env ruby
# Creates (or repairs) the ShareExtension target in ios/Runner.xcodeproj.
#
# The extension is what puts MonkeyHub in the iOS share sheet. It is a second
# binary with its own bundle id, its own entitlements and its own Info.plist,
# and none of that can be expressed in a Flutter project's source tree — so it
# is generated here rather than committed as ~2000 lines of pbxproj that no
# review can read and every `flutter create`-style regeneration would clobber.
#
# Safe to re-run: everything is keyed on the target's name and every file
# reference is deduped, so a second run over an already-configured project
# changes nothing and saves nothing.
#
# Usage:
#   ruby tool/setup_ios_share_extension.rb
#
# Run with the Ruby that has the xcodeproj gem (the one bundled with CocoaPods
# works):
#   GEM_HOME="$(dirname "$(dirname "$(readlink -f "$(which pod)")")")/libexec" \
#     ruby tool/setup_ios_share_extension.rb
# or simply:
#   pod install   # this script is also invoked from the Podfile post_install

require 'xcodeproj'

TARGET_NAME   = 'ShareExtension'
APP_TARGET    = 'Runner'
APP_BUNDLE_ID = 'com.walhallaa.chatTest-20241220'
# Apple requires an extension's bundle id to be prefixed by its container's.
# A mismatch is an "invalid bundle" rejection at upload time, not a build error.
EXT_BUNDLE_ID = "#{APP_BUNDLE_ID}.ShareExtension"
TEAM          = '37TC2VKVJ6'
# Share extensions run on iOS 15+ here for the same reason the app does — see
# ios/Podfile. UniformTypeIdentifiers (used by ShareViewController) needs 14.
DEPLOYMENT    = '15.0'

project_path = File.expand_path('../ios/Runner.xcodeproj', __dir__)
ios_dir      = File.expand_path('../ios', __dir__)

project = Xcodeproj::Project.open(project_path)
app = project.targets.find { |t| t.name == APP_TARGET }
unless app
  warn "[share-extension] #{APP_TARGET} target not found in #{project_path}"
  exit 1
end

changed = false

# ── The target ───────────────────────────────────────────────────────────────
target = project.targets.find { |t| t.name == TARGET_NAME }
unless target
  target = project.new_target(
    :app_extension,
    TARGET_NAME,
    :ios,
    DEPLOYMENT,
    project.products_group,
    :swift
  )
  changed = true
end

# ── Build settings ───────────────────────────────────────────────────────────
#
# The configuration LIST has to match the app's exactly (Debug, Release,
# Profile). Flutter builds Profile for `--profile`, and a target missing that
# configuration fails the build with "does not contain configuration Profile"
# rather than falling back to anything.
app_configs = app.build_configurations.map(&:name)
app_configs.each do |name|
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
    'INFOPLIST_FILE' => 'ShareExtension/Info.plist',
    'CODE_SIGN_ENTITLEMENTS' => 'ShareExtension/ShareExtension.entitlements',
    'DEVELOPMENT_TEAM' => TEAM,
    'IPHONEOS_DEPLOYMENT_TARGET' => DEPLOYMENT,
    'SWIFT_VERSION' => '5.0',
    # iPhone + iPad, matching the app. An extension the app ships on a device
    # family it does not support is an upload rejection.
    'TARGETED_DEVICE_FAMILY' => '1,2',
    # An extension is embedded in the app, never installed on its own.
    'SKIP_INSTALL' => 'YES',
    # @rpath entries an app extension needs to find the shared Swift runtime
    # inside its container. An ARRAY, not a space-joined string: xcodeproj
    # normalises multi-value settings to arrays when it writes them, so the
    # string form would compare unequal on every re-run and dirty the pbxproj
    # each `pod install`.
    'LD_RUNPATH_SEARCH_PATHS' => [
      '$(inherited)',
      '@executable_path/Frameworks',
      '@executable_path/../../Frameworks',
    ],
    # The extension links nothing from CocoaPods and must not inherit the app's
    # Pods xcconfig, which would drag the whole Flutter framework in.
    'CLANG_ENABLE_MODULES' => 'YES',
    # Bitcode has been dead since Xcode 14 and an extension carrying it fails
    # validation.
    'ENABLE_BITCODE' => 'NO',
    # Both spellings: Xcode moved this setting, and a stale Info.plist key from
    # the other one is an "unexpected key" warning on upload.
    'GENERATE_INFOPLIST_FILE' => 'NO',
  }
  wanted.each do |key, value|
    next if config.build_settings[key] == value

    config.build_settings[key] = value
    changed = true
  end
end

# ── Version numbers ──────────────────────────────────────────────────────────
#
# The extension's Info.plist spells its version as $(FLUTTER_BUILD_NAME) /
# $(FLUTTER_BUILD_NUMBER), and those come from Flutter/Generated.xcconfig —
# which only the Runner target reads. Without this the two variables expand to
# nothing, Xcode DROPS the empty keys from the built plist entirely, and App
# Store Connect rejects the upload:
#
#     CFBundleVersion ... does not match the CFBundleVersion of its containing
#     iOS application
#
# Nothing in the build fails first. `plutil -p` on the built .appex is the only
# place it shows up before the upload does.
#
# Generated.xcconfig rather than Flutter/Debug.xcconfig: the latter also pulls
# in the Pods-Runner xcconfig, which would link the entire Flutter framework
# into a process that has no engine.
generated = project.main_group['Flutter']
                   &.files
                   &.find { |f| File.basename(f.path.to_s) == 'Generated.xcconfig' }
if generated
  target.build_configurations.each do |config|
    next if config.base_configuration_reference == generated

    config.base_configuration_reference = generated
    changed = true
  end
else
  warn '[setup_ios_share_extension] Flutter/Generated.xcconfig not in the ' \
       'project — the extension will build with no version number'
end

# ── Source files ─────────────────────────────────────────────────────────────
#
# Two groups, because one file belongs to two targets. ShareGroup.swift is the
# handshake between the app and the extension — the App Group id, the inbox
# layout, the wake-up URL — and compiling it twice from one source is what
# keeps the two halves from drifting.
def group_for(project, name, path)
  project.main_group[name] || project.main_group.new_group(name, path)
end

ext_group = group_for(project, TARGET_NAME, TARGET_NAME)
shared_group = group_for(project, 'Shared', 'Shared')

def file_ref(group, basename)
  group.files.find { |f| File.basename(f.real_path.to_s) == basename } ||
    group.new_reference(basename)
end

def add_source(target, ref)
  phase = target.source_build_phase
  return false if phase.files_references.include?(ref)

  phase.add_file_reference(ref)
  true
end

# Extension-only sources. ConvexHTTP is what lets it send without the app;
# ShareComposeView + Staging are the sheet the user actually sees.
%w[
  ShareViewController.swift
  ShareComposeView.swift
  ConvexHTTP.swift
  Staging.swift
].each do |name|
  changed = true if add_source(target, file_ref(ext_group, name))
end

# Compiled into BOTH binaries. Every constant in these is one half of a
# handshake between two separately-signed processes, and the failure mode of a
# disagreement is silence rather than an error.
%w[ShareGroup.swift ShareSession.swift].each do |name|
  ref = file_ref(shared_group, name)
  changed = true if add_source(target, ref)
  changed = true if add_source(app, ref)
end

# App-only: reading the inbox back, and writing the session the extension sends
# with.
runner_group = project.main_group['Runner']
%w[ShareInbox.swift ShareCache.swift].each do |name|
  changed = true if add_source(app, file_ref(runner_group, name))
end

# The Info.plist and entitlements are referenced (so they show up in Xcode and
# so a `git mv` is visible) but never added to a build phase: they are consumed
# by build SETTINGS, and a plist in Copy Resources ships a duplicate into the
# bundle.
file_ref(ext_group, 'Info.plist')
file_ref(ext_group, 'ShareExtension.entitlements')

# ── Embedding ────────────────────────────────────────────────────────────────
#
# Without this the extension builds and is then simply absent from the .app —
# which looks exactly like "iOS is ignoring my share extension".
embed = app.copy_files_build_phases.find { |p| p.name == 'Embed App Extensions' }
unless embed
  embed = app.new_copy_files_build_phase('Embed App Extensions')
  # 13 = PlugIns. Anywhere else and iOS never discovers the extension.
  embed.symbol_dst_subfolder_spec = :plug_ins
  changed = true
end

product = target.product_reference
unless embed.files_references.include?(product)
  build_file = embed.add_file_reference(product)
  # Codesign on copy — the extension is signed with its own entitlements.
  build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  changed = true
end

unless app.dependencies.any? { |d| d.target&.uuid == target.uuid }
  app.add_dependency(target)
  changed = true
end

# Embed BEFORE Flutter's "Thin Binary" script, not after it.
#
# This is not tidiness — appending the phase (which is what Xcode does when you
# add an extension by hand, and what `new_copy_files_build_phase` does here)
# makes the build fail outright with:
#
#     error: Cycle inside Runner; building could produce unreliable results.
#
# "Thin Binary" declares `Runner.app/Info.plist` as a directory-tree input, and
# Xcode's automatic `ExtractAppIntentsMetadata` task reads the whole built
# product — so a copy INTO `Runner.app/PlugIns` scheduled after it closes a loop
# through the two CocoaPods script phases in between. Running the copy earlier
# breaks the loop, and the .appex is in place well before anything reads the
# bundle.
phases = app.build_phases
thin = phases.index { |ph| ph.respond_to?(:name) && ph.name == 'Thin Binary' }
current = phases.index(embed)
if thin && current && current > thin
  phases.move(embed, thin)
  changed = true
end

# ── Frameworks ───────────────────────────────────────────────────────────────
#
# Intents is the one that is not implicit: ShareViewController reads the
# INSendMessageIntent that a tapped suggestion arrives with.
%w[Intents.framework UIKit.framework SwiftUI.framework ImageIO.framework].each do |name|
  next if target.frameworks_build_phase.files.any? do |f|
    f.display_name == name
  end

  ref = project.frameworks_group.new_file("System/Library/Frameworks/#{name}")
  ref.source_tree = 'SDKROOT'
  target.frameworks_build_phase.add_file_reference(ref)
  changed = true
end

if changed
  project.save
  puts "[setup_ios_share_extension] configured #{TARGET_NAME} (#{EXT_BUNDLE_ID})"
else
  puts "[setup_ios_share_extension] #{TARGET_NAME} already configured"
end

missing = %w[
  ShareExtension/ShareViewController.swift
  ShareExtension/ShareComposeView.swift
  ShareExtension/ConvexHTTP.swift
  ShareExtension/Staging.swift
  ShareExtension/Info.plist
  ShareExtension/ShareExtension.entitlements
  Shared/ShareGroup.swift
  Shared/ShareSession.swift
  Runner/ShareInbox.swift
  Runner/ShareCache.swift
].reject { |rel| File.exist?(File.join(ios_dir, rel)) }
unless missing.empty?
  warn "[setup_ios_share_extension] MISSING on disk: #{missing.join(', ')}"
  exit 1
end
