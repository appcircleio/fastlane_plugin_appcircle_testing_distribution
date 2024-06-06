require 'fastlane/action'
require_relative '../helper/appcircle_testing_distribution_helper'

module Fastlane
  module Actions
    class AppcircleTestingDistributionAction < Action
      def self.run(params)
        UI.message("The appcircle_testing_distribution plugin is working!")
      end

      def self.description
        "Efficiently distribute application builds to users or testing groups using Appcircle's robust platform."
      end

      def self.authors
        ["Guven Karanfil"]
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
      end

      def self.details
        # Optional:
        "Appcircle simplifies the distribution of builds to test teams with an extensive platform for managing and tracking applications, versions, testers, and teams. Appcircle integrates with enterprise authentication mechanisms such as LDAP and SSO, ensuring secure distribution of testing packages. Learn more about Appcircle testing distribution"
      end

      def self.available_options
        [
          # FastlaneCore::ConfigItem.new(key: :your_option,
          #                         env_name: "APPCIRCLE_TESTING_DISTRIBUTION_YOUR_OPTION",
          #                      description: "A description of your option",
          #                         optional: false,
          #                             type: String)
        ]
      end

      def self.is_supported?(platform)
        # Adjust this if your plugin only works for a particular platform (iOS vs. Android, for example)
        # See: https://docs.fastlane.tools/advanced/#control-configuration-by-lane-and-by-platform
        #
        # [:ios, :mac, :android].include?(platform)
        true
      end
    end
  end
end
