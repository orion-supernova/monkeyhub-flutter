#!/usr/bin/env ruby
# Creates (or repairs) the BroadcastExtension target in ios/Runner.xcodeproj.
#
# This is the Broadcast Upload Extension: the second binary iOS runs when the
# user picks MonkeyHub in the system's screen-share picker. ReplayKit hands it
# the display's frames; it JPEG-encodes them and streams them over a unix
# socket in the shared app-group container, where flutter_webrtc's
# `FlutterBroadcastScreenCapturer` (the app side) turns them into a video
# track for the call. That is the only way past the app's own window — an
# in-process capture stops at the app's edge and dies when it is backgrounded.
#
# Generated rather than committed for the same reason its siblings are: an
# extension is bundle id, entitlements and Info.plist, none of which a Flutter
# source tree can express, and the pbxproj that results is unreviewable.
#
# Safe to re-run: everything is keyed on the target's name and every file
# reference is deduped.
#
# Usage:
#   ruby tool/setup_ios_broadcast_extension.rb
# or simply `pod install` — this script is invoked from the Podfile post_install.
#
# PROVISIONING: the extension has its own App ID
# (com.walhallaa.chatTest-20241220.BroadcastExtension) which must exist in the
# developer portal with App Groups enabled (group.com.walhallaa.monkeyhub), and
# a profile for it. Nothing here can do that; the build fails signing until it
# is done. It cannot run in the simulator.

require 'xcodeproj'

TARGET_NAME   = 'BroadcastExtension'
APP_TARGET    = 'Runner'
APP_BUNDLE_ID = 'com.walhallaa.chatTest-20241220'
EXT_BUNDLE_ID = "#{APP_BUNDLE_ID}.BroadcastExtension"
TEAM          = '37TC2VKVJ6'
DEPLOYMENT    = '15.0'

project_path = File.expand_path('../ios/Runner.xcodeproj', __dir__)
ios_dir      = File.expand_path('../ios', __dir__)

project = Xcodeproj::Project.open(project_path)
app = project.targets.find { |t| t.name == APP_TARGET }
unless app
  warn "[broadcast-extension] #{APP_TARGET} target not found in #{project_path}"
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
    'INFOPLIST_FILE' => 'BroadcastExtension/Info.plist',
    'CODE_SIGN_ENTITLEMENTS' =>
      'BroadcastExtension/BroadcastExtension.entitlements',
    'DEVELOPMENT_TEAM' => TEAM,
    'IPHONEOS_DEPLOYMENT_TARGET' => DEPLOYMENT,
    'SWIFT_VERSION' => '5.0',
    'TARGETED_DEVICE_FAMILY' => '1,2',
    'SKIP_INSTALL' => 'YES',
    'LD_RUNPATH_SEARCH_PATHS' => [
      '$(inherited)',
      '@executable_path/Frameworks',
      '@executable_path/../../Frameworks',
    ],
    'CLANG_ENABLE_MODULES' => 'YES',
    'ENABLE_BITCODE' => 'NO',
    'GENERATE_INFOPLIST_FILE' => 'NO',
  }
  wanted.each do |key, value|
    next if config.build_settings[key] == value

    config.build_settings[key] = value
    changed = true
  end
end

# ── Version numbers ──────────────────────────────────────────────────────────
# Same wiring as the notification extension: the plist spells its version as
# $(FLUTTER_BUILD_NAME)/$(FLUTTER_BUILD_NUMBER), which only expand when the
# target reads Flutter/Generated.xcconfig.
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
  warn '[setup_ios_broadcast_extension] Flutter/Generated.xcconfig not in ' \
       'the project — the extension will build with no version number'
end

# ── Source files ─────────────────────────────────────────────────────────────
def group_for(project, name, path)
  project.main_group[name] || project.main_group.new_group(name, path)
end

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

ext_group = group_for(project, TARGET_NAME, TARGET_NAME)

SOURCES = %w[
  SampleHandler.swift
  SampleUploader.swift
  SocketConnection.swift
  DarwinNotificationCenter.swift
  Atomic.swift
].freeze

SOURCES.each do |name|
  changed = true if add_source(target, file_ref(ext_group, name))
end

file_ref(ext_group, 'Info.plist')
file_ref(ext_group, 'BroadcastExtension.entitlements')

# ── Embedding ────────────────────────────────────────────────────────────────
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

phases = app.build_phases
thin = phases.index { |ph| ph.respond_to?(:name) && ph.name == 'Thin Binary' }
current = phases.index(embed)
if thin && current && current > thin
  phases.move(embed, thin)
  changed = true
end

# ── Frameworks ───────────────────────────────────────────────────────────────
# ReplayKit is the extension point; VideoToolbox/CoreImage do the JPEG.
%w[ReplayKit.framework].each do |name|
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
  puts "[setup_ios_broadcast_extension] configured #{TARGET_NAME} (#{EXT_BUNDLE_ID})"
else
  puts "[setup_ios_broadcast_extension] #{TARGET_NAME} already configured"
end

missing = (SOURCES.map { |f| "BroadcastExtension/#{f}" } +
           %w[BroadcastExtension/Info.plist
              BroadcastExtension/BroadcastExtension.entitlements])
          .reject { |rel| File.exist?(File.join(ios_dir, rel)) }
unless missing.empty?
  warn "[setup_ios_broadcast_extension] MISSING on disk: #{missing.join(', ')}"
  exit 1
end
