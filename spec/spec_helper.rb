$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'simplecov'

SimpleCov.start

module SpecHelper
end

require 'fastlane'
require 'fastlane/plugin/appcircle_testing_distribution'

Fastlane.load_actions
