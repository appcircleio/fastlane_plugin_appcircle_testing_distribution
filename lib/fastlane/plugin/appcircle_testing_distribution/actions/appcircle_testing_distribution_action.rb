require 'fastlane/action'
require 'net/http'
require 'uri'
require 'json'

require_relative '../helper/appcircle_testing_distribution_helper'
require_relative '../helper/TDAuthService'
require_relative '../helper/TDUploadService'

module Fastlane
  module Actions
    class AppcircleTestingDistributionAction < Action
      VALID_EXTENSIONS = ['.apk', '.aab', '.ipa', '.zip']
      AUTH_TYPE_MAPPING = {
        nil => 0, # Undefined
        'none' => 1, # None
        'static' => 3, # Static Username and Password
        'ldap' => 4, # LDAP Login
        'sso' => 5, # SSO Login
      }
      
      def self.run(params)
        personalAPIToken = params[:personalAPIToken]
        subOrganizationName = params[:subOrganizationName]
        profileName = params[:profileName]
        createProfileIfNotExists = params[:createProfileIfNotExists] || false
        profileAuthType = params[:profileCreationSettings]&.dig(:authType)
        profileUsername = params[:profileCreationSettings]&.dig(:username)
        profilePassword = params[:profileCreationSettings]&.dig(:password)
        profileTestingGroupNames= params[:profileCreationSettings]&.dig(:testingGroupNames)
        appPath = params[:appPath]
        message = params[:message]

        file_extension = File.extname(appPath).downcase
        unless VALID_EXTENSIONS.include?(file_extension)
          UI.user_error!("Invalid file extension: '#{file_extension}'. For Android, use .apk or .aab. For iOS, use .ipa or .zip(.xcarchive).")
        end
        
        profileAuthType = AUTH_TYPE_MAPPING[profileAuthType] # map input to API values

        # Auth
        authToken = self.ac_login(personalAPIToken, subOrganizationName)

        # Get or create profile
        profileId = TDUploadService.get_profile_id(authToken, profileName)

        if profileId.nil? && !createProfileIfNotExists
          raise "Error: The test profile '#{profileName}' could not be found. The option 'createProfileIfNotExists' is set to false, so no new profile was created. To automatically create a new profile if it doesn't exist, set 'createProfileIfNotExists' to true."
        elsif profileId.nil? && createProfileIfNotExists
          UI.message "The test profile '#{profileName}' could not be found. A new profile is being created..."
          profileId = TDUploadService.create_profile(authToken, profileName, profileAuthType, profileUsername, profilePassword, profileTestingGroupNames)
        end

        # Upload package
        self.ac_upload(authToken, appPath, profileId, message)
      end

      def self.ac_login(personalAPIToken, subOrganizationName)
        begin
          token = ''

          user = TDAuthService.get_ac_token(pat: personalAPIToken)
          UI.success("Login is successful.")
          token = user.accessToken
          
          if subOrganizationName
            organization_id = TDAuthService.get_organization_id(access_token: token, name: subOrganizationName)
            user = TDAuthService.get_ac_token(pat: personalAPIToken, sub_organization_id: organization_id)
            UI.success("Switched to sub-organization: #{subOrganizationName}")
            token = user.accessToken
          end
          
          return token

        rescue => e
          UI.user_error!("Login failed: #{e.message}.")
        end
      end
      
      def self.checkTaskStatus(authToken, taskId)
        uri = URI.parse("https://api.appcircle.io/task/v1/tasks/#{taskId}")
        check_interval = 1
      
        loop do
          response = self.send_request(uri, authToken)
          if response.is_a?(Net::HTTPSuccess)
            stateValue = JSON.parse(response.body)["stateValue"]
      
            if stateValue == 1
              sleep(check_interval)
            elsif stateValue == 3
              return true
            else
              UI.error("Task Id #{taskId} failed with state value #{stateValue}.")
              raise "Upload could not be completed successfully."
            end
          else
            raise "Upload failed with response code #{response.code} and message '#{response.message}'."
          end
        end
      end

      def self.send_request(uri, access_token)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == "https")
        request = Net::HTTP::Get.new(uri.request_uri)
        request["Authorization"] = "Bearer #{access_token}"
        http.request(request)
      end

      def self.ac_upload(token, appPath, profileID, message)
        begin
          response = TDUploadService.upload_artifact(token: token, message: message, app: appPath, dist_profile_id: profileID)
          result = self.checkTaskStatus(token, response['taskId'])

          if result
            UI.success("#{appPath} uploaded to profile ID #{profileID} successfully  🎉")
          end
        rescue => e
          status_code = e.respond_to?(:response) && e.response ? e.response.code : 'unknown'
          UI.user_error!("Upload failed with status code #{status_code}, with message '#{e.message}'.")
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
        "Appcircle simplifies the distribution of builds to test teams with an extensive platform for managing and tracking applications, versions, testers, and teams. Appcircle integrates with enterprise authentication mechanisms such as LDAP and SSO, ensuring secure distribution of testing packages. Learn more about Appcircle testing distribution."
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :personalAPIToken,
                                       env_name: "AC_PERSONAL_API_TOKEN",
                                       description: "Provide Personal API Token to authenticate connections to Appcircle services",
                                       optional: false,
                                       type: String,
                                       verify_block: proc do |value|
                                         UI.user_error!("Personal API Token cannot be empty. Please provide a valid access token.") unless (value and not value.empty?)
                                       end),

          FastlaneCore::ConfigItem.new(key: :subOrganizationName,
                                       env_name: "AC_SUB_ORGANIZATION_NAME",
                                       description: "Optional: Sub-organization name for app distribution. Profiles will be created under root organization if not provided",
                                       optional: true,
                                       type: String),
          
          FastlaneCore::ConfigItem.new(key: :profileName,
                                       env_name: "AC_PROFILE_NAME",
                                       description: "Enter the profile name of the Appcircle testing distribution profile. This name uniquely identifies the profile under which your applications will be distributed",
                                       optional: false,
                                       type: String,
                                       verify_block: proc do |value|
                                         UI.user_error!("Profile name cannot be empty. Please provide a testing distribution profile name.") unless (value and not value.empty?)
                                       end),
          
          FastlaneCore::ConfigItem.new(key: :createProfileIfNotExists,
                                       env_name: "AC_CREATE_PROFILE_IF_NOT_EXISTS",
                                       description: "Optional: If the profile does not exist, create a new profile with the given name",
                                       optional: true,
                                       type: Boolean),
          
          FastlaneCore::ConfigItem.new(key: :profileCreationSettings,
                                       description: "Optional: Profile creation settings for the testing distribution profile",
                                       optional: true,
                                       type: Hash,
                                       verify_block: proc do |value|
                                         value[:authType] ||= ENV["AC_PROFILE_AUTH_TYPE"]
                                         value[:username] ||= ENV["AC_PROFILE_USERNAME"]
                                         value[:password] ||= ENV["AC_PROFILE_PASSWORD"]
                                         value[:testingGroupNames] ||= ENV["AC_PROFILE_TESTING_GROUP_NAMES"]
                                         value[:testingGroupNames] = value[:testingGroupNames]&.split(",")&.map(&:strip)
                                         
                                         UI.user_error!("Invalid authType: '#{value[:authType]}'. Options: 0 (None), 1 (Static Username and Password), 2 (LDAP Login), 3 (SSO Login).") unless AUTH_TYPE_MAPPING.key?(value[:authType])
                                         if value[:authType] == 1
                                          UI.user_error!("username must be a String and at least 6 characters long.") unless value[:username].kind_of?(String) && value[:username].length >= 6
                                          UI.user_error!("password must be a String and at least 6 characters long.") unless value[:password].kind_of?(String) && value[:password].length >= 6
                                         end
                                         UI.user_error!("testingGroupNames must be a non-empty string array. Ex: 'group1, group2, group3'.") unless value[:testingGroupNames].kind_of?(Array)
                                       end),

          FastlaneCore::ConfigItem.new(key: :appPath,
                                       env_name: "AC_APP_PATH",
                                       description: "Specify the path to your application file. For iOS, this can be a .ipa or .xcarchive file path. For Android, specify the .apk or .appbundle file path",
                                       optional: false,
                                       type: String,
                                       verify_block: proc do |value|
                                         UI.user_error!("Application file path cannot be empty. Please provide a valid application file path.") unless (value and not value.empty?)
                                       end),

          FastlaneCore::ConfigItem.new(key: :message,
                                       env_name: "AC_MESSAGE",
                                       description: "Optional message to include with the distribution to provide additional information to testers or users receiving the build",
                                       optional: false,
                                       type: String,
                                       verify_block: proc do |value|
                                         UI.user_error!("Message field cannot be empty. Please provide a valid message.") unless (value and not value.empty?)
                                       end)
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
