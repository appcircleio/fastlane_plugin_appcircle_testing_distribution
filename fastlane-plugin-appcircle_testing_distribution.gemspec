lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fastlane/plugin/appcircle_testing_distribution/version'

Gem::Specification.new do |spec|
  spec.name          = 'fastlane-plugin-appcircle_testing_distribution'
  spec.version       = Fastlane::AppcircleTestingDistribution::VERSION
  spec.author        = 'Guven Karanfil'
  spec.email         = 'guven.karanfil@smartface.io'

  spec.summary       = "Efficiently distribute application builds to users or testing groups using Appcircle's robust platform."
  # spec.homepage      = "https://github.com/<GITHUB_USERNAME>/fastlane-plugin-appcircle_testing_distribution"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*"] + %w(README.md LICENSE)
  spec.require_paths = ['lib']
  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.required_ruby_version = '>= 2.6'

  # Don't add a dependency to fastlane or fastlane_re
  # since this would cause a circular dependency

  # spec.add_dependency 'your-dependency', '~> 1.0.0'
end
