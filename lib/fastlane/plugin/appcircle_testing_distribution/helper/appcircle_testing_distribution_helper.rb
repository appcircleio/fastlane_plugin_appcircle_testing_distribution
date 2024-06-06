require 'fastlane_core/ui/ui'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class AppcircleTestingDistributionHelper
      # class methods that you define here become available in your action
      # as `Helper::AppcircleTestingDistributionHelper.your_method`
      #
      def self.show_message
        UI.message("Hello from the appcircle_testing_distribution plugin helper!")
      end
    end
  end
end
