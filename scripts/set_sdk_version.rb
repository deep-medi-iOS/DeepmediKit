#!/usr/bin/env ruby

require "json"
require "pathname"

# 잘못된 버전이 소스와 CocoaPods 메타데이터에 반영되지 않도록 검증한다.
VERSION_PATTERN = /\A\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?\z/

version = ARGV.first.to_s.delete_prefix("v")
unless VERSION_PATTERN.match?(version)
  warn "Invalid SDK version: #{ARGV.first.inspect}"
  warn "Expected semantic version such as 3.6.3"
  exit 1
end

root = Pathname(__dir__).parent
podspec_path = root.join("DeepmediKit.podspec")
service_path = root.join("DeepmediKit/Classes/Service/Service.swift")
example_dir = root.join("Example")
lockfile_path = example_dir.join("Podfile.lock")
local_spec_path = example_dir.join(
  "Pods/Local Podspecs/DeepmediKit.podspec.json"
)

# podspec과 런타임 fallback 버전을 동일한 값으로 변경한다.
podspec = podspec_path.read
podspec_pattern = /^(\s*s\.version\s*=\s*['"])([^'"]+)(['"]\s*)$/
podspec_match = podspec.match(podspec_pattern)
unless podspec_match
  warn "Could not find s.version in #{podspec_path}"
  exit 1
end

service = service_path.read
fallback_pattern = /^(\s*private static let fallbackVersion = ")[^"]+(")$/
unless service.match?(fallback_pattern)
  warn "Could not find DeepmediKitSDK fallbackVersion in #{service_path}"
  exit 1
end

podspec_path.write(
  podspec.sub(podspec_pattern) do
    "#{$1}#{version}#{$3}"
  end
)
service_path.write(
  service.sub(fallback_pattern) do
    "#{$1}#{version}#{$2}"
  end
)

puts "DeepmediKit SDK version: #{podspec_match[2]} -> #{version}"
puts "Updating Example CocoaPods metadata..."

# 로컬 pod을 갱신해 lockfile과 생성된 Pods 프로젝트에도 새 버전을 반영한다.
pod_updated = Dir.chdir(example_dir) do
  system(
    { "LANG" => "en_US.UTF-8" },
    "pod",
    "update",
    "DeepmediKit",
    "--no-repo-update"
  )
end
unless pod_updated
  warn "CocoaPods update failed. Source version is #{version}, but Example metadata may be stale."
  exit 1
end

# CocoaPods가 생성한 두 메타데이터가 요청한 버전과 같은지 최종 확인한다.
lockfile_version = lockfile_path.read[
  /^\s+- DeepmediKit \(([^)]+)\):$/,
  1
]
local_spec_version = if local_spec_path.file?
  JSON.parse(local_spec_path.read)["version"]
end

unless lockfile_version == version && local_spec_version == version
  warn(
    "Version sync failed: podspec=#{version}, " \
    "Podfile.lock=#{lockfile_version.inspect}, " \
    "Local Podspec=#{local_spec_version.inspect}"
  )
  exit 1
end

puts "CocoaPods metadata synchronized to DeepmediKit #{version}."
