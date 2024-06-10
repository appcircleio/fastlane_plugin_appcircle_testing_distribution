require 'fastlane/action'
require_relative '../helper/appcircle_testing_distribution_helper'

module Fastlane
  module Actions
    class AppcircleTestingDistributionAction < Action
      def self.run(params)
        accessToken = params[:accessToken]
        profileID = params[:profileID]
        appPath = params[:appPath]
        message = params[:message]

        self.ac_login(accessToken)
        self.ac_upload(appPath, profileID, message)

      end

      def self.ac_login(accessToken)
        ac_login = `appcircle login --pat #{accessToken}`
        if $?.success?
          UI.success("Logged in to Appcircle successfully.")
        else
          raise "Error executing command of logging to Appcircle. Please make sure you have installed Appcircle CLI and provided a valid access token. For more information, please visit https://docs.appcircle.io/appcircle-api/api-authentication#generatingmanaging-the-personal-api-tokens #{ac_login}"
        end
      end

      def self.ac_upload(appPath, profileID, message)
        ac_upload = `appcircle testing-distribution upload --app=#{appPath} --distProfileId=#{profileID} --message "#{message}"`;
        if $?.success?
          UI.success("#{appPath} Uploaded to Appcircle successfully.")
        else
          raise "Error executing command of uploading to Appcircle. Please make sure you have provide the valid app path and distribution profile id. For more information\n" + ac_upload
        end
      end

      def self.description
        "Efficiently distribute application builds to users or testing groups using Appcircle's robust platform."
      end

      def self.authors
        ["appcircleio"]
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
          FastlaneCore::ConfigItem.new(key: :accessToken,
                                  env_name: "AC_ACCESS_TOKEN",
                               description: "Provide the Appcircle access token to authenticate connections to Appcircle services. This token allows your Azure DevOps pipeline to interact with Appcircle for distributing applications",
                                  optional: false,
                                      type: String),

          FastlaneCore::ConfigItem.new(key: :profileID,
                                  env_name: "AC_PROFILE_ID",
                               description: "Enter the ID of the Appcircle distribution profile. This ID uniquely identifies the profile under which your applications will be distributed",
                                  optional: false,
                                      type: String),

          FastlaneCore::ConfigItem.new(key: :appPath,
                                  env_name: "AC_APP_PATH",
                               description: "Specify the path to your application file. For iOS, this can be a .ipa or .xcarchive file path. For Android, specify the .apk or .appbundle file path",
                                  optional: false,
                                      type: String),
                                      
          FastlaneCore::ConfigItem.new(key: :message,
                                  env_name: "AC_MESSAGE",
                               description: "Optional message to include with the distribution to provide additional information to testers or users receiving the build",
                                  optional: false,
                                      type: String),
        ]
      end

      def self.is_supported?(platform)
        # Adjust this if your plugin only works for a particular platform (iOS vs. Android, for example)
        # See: https://docs.fastlane.tools/advanced/#control-configuration-by-lane-and-by-platform
        #
        [:ios, :android].include?(platform)
      end
    end
  end
end
