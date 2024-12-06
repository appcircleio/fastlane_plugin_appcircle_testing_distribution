require 'fastlane_core/ui/ui'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class AppcircleTestingDistributionHelper
      # class methods that you define here become available in your action
      # as `Helper::AppcircleTestingDistributionHelper.your_method`
      #
      def self.uuid_valid(uuid)
        !!uuid.to_s.match(/\A\h{8}-(\h{4}-){3}\h{12}\z/)
      end
    end
  end
end
