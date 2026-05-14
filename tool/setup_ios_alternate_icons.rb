#!/usr/bin/env ruby
# Adds every PNG under ios/Runner/AlternateIcons/ to the Runner target's
# resources build phase, so iOS alternate icons declared in Info.plist's
# CFBundleAlternateIcons actually ship in the .app bundle.
#
# Safe to re-run after regenerating PNGs — entries are dedup'd.
#
# Usage:
#   ruby tool/setup_ios_alternate_icons.rb
#
# Run with the Ruby that has the xcodeproj gem (the one bundled with
# CocoaPods works):
#   /opt/homebrew/Cellar/cocoapods/*/libexec/bin/bundle exec ruby tool/setup_ios_alternate_icons.rb
# or simply:
#   pod install   # this script is also invoked from the Podfile post_install

require 'xcodeproj'

project_path = File.expand_path('../ios/Runner.xcodeproj', __dir__)
icons_dir    = File.expand_path('../ios/Runner/AlternateIcons', __dir__)

unless File.directory?(icons_dir)
  warn "AlternateIcons directory not found at #{icons_dir} — nothing to do."
  exit 0
end

project = Xcodeproj::Project.open(project_path)
target  = project.targets.find { |t| t.name == 'Runner' }
unless target
  warn "Runner target not found in #{project_path}"
  exit 1
end

# Locate (or create) a group at Runner/AlternateIcons that mirrors the on-disk
# folder. We give the group a `path` so Xcode resolves files relatively.
runner_group = project.main_group['Runner']
icons_group  = runner_group['AlternateIcons']
unless icons_group
  icons_group = runner_group.new_group('AlternateIcons', 'AlternateIcons')
end

# Resources build phase — where the PNGs need to live so they're copied into
# the app bundle root.
resources_phase = target.resources_build_phase

# Already-tracked AlternateIcons file paths (relative to project), so we can
# skip re-adding and prune deletions.
existing_refs = icons_group.files.to_a
existing_paths = existing_refs.map { |r| r.real_path.to_s }

disk_pngs = Dir.glob(File.join(icons_dir, '*.png')).sort

added = 0
disk_pngs.each do |png|
  next if existing_paths.include?(File.expand_path(png))

  rel = File.basename(png)
  file_ref = icons_group.new_reference(rel)
  resources_phase.add_file_reference(file_ref, true)
  added += 1
end

# Drop references that no longer have a backing file on disk.
disk_basenames = disk_pngs.map { |p| File.basename(p) }
removed = 0
existing_refs.each do |ref|
  basename = File.basename(ref.real_path.to_s)
  next if disk_basenames.include?(basename)

  resources_phase.files.each do |bf|
    resources_phase.remove_file_reference(bf.file_ref) if bf.file_ref == ref
  end
  ref.remove_from_project
  removed += 1
end

project.save
puts "[setup_ios_alternate_icons] added #{added}, removed #{removed}, " \
     "total tracked #{icons_group.files.count}"
