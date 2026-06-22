#!/usr/bin/env ruby


require 'json'
require 'net/http'
require 'uri'

GEM_NAME = 'fastlane-plugin-appcircle_testing_distribution'
VERSION_FILE = File.expand_path(
  '../lib/fastlane/plugin/appcircle_testing_distribution/version.rb', __dir__
)

def sh(cmd)
  puts "+ #{cmd}"
  system(cmd) || abort("command failed: #{cmd}")
end

# Base version from the latest git tag, e.g. "v0.4.3" -> "0.4.3".
def base_version
  base = ENV['LATEST_TAG'].to_s.strip.sub(/\Av/, '')
  abort('LATEST_TAG is empty — push a git tag (vX.Y.Z) first.') if base.empty?
  unless base.match?(/\A\d+\.\d+\.\d+\z/)
    abort("LATEST_TAG '#{base}' is not a clean X.Y.Z version.")
  end
  base
end

# All version numbers already published to RubyGems for this gem.
def published_versions
  uri = URI("https://rubygems.org/api/v1/versions/#{GEM_NAME}.json")
  res = Net::HTTP.get_response(uri)
  return [] unless res.is_a?(Net::HTTPSuccess)

  JSON.parse(res.body).map { |v| v['number'] }
rescue StandardError => e
  warn "warn: could not query RubyGems (#{e.class}: #{e.message}); assuming none published"
  []
end

def write_version!(version)
  content = File.read(VERSION_FILE)
  File.write(VERSION_FILE, content.sub(/VERSION\s*=\s*"[^"]*"/, %(VERSION = "#{version}")))
  puts "version.rb -> #{version}"
end

def build_and_push!(version)
  write_version!(version)
  sh "gem build #{GEM_NAME}.gemspec"
  sh "gem push #{GEM_NAME}-#{version}.gem" # uses GEM_HOST_API_KEY
end

def publish_prerelease!
  base = base_version
  published = published_versions
  taken = published.grep(/\A#{Regexp.escape(base)}\.beta\.\d+\z/)
  next_n = (taken.map { |v| v[/\.beta\.(\d+)\z/, 1].to_i }.max || 0) + 1
  version = "#{base}.beta.#{next_n}"

  abort("#{version} is already published") if published.include?(version)
  puts "Publishing PRE-RELEASE #{version} (from tag base #{base})"
  build_and_push!(version)
end

def publish_production!
  version = base_version

  if published_versions.include?(version)
    puts "#{version} is already on RubyGems; nothing to do."
    return
  end

  puts "Publishing PRODUCTION #{version}"
  build_and_push!(version)
end

case ARGV[0]
when 'prerelease' then publish_prerelease!
when 'production' then publish_production!
else abort('usage: ruby ci/release.rb [prerelease|production]')
end
