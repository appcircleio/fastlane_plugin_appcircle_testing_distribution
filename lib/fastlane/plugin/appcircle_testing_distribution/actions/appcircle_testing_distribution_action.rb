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
      VALID_EXTENSIONS = ['.apk', '.aab', '.ipa']
      AUTH_TYPE_MAPPING = {
        'none' => 1, # None
        'static' => 3, # Static Username and Password
        'ldap' => 4, # LDAP Login
        'sso' => 5 # SSO Login
      }
      
      def self.run(params)
        personalAPIToken = params[:personalAPIToken]
        personalAccessKey = params[:personalAccessKey]
        subOrganizationName = params[:subOrganizationName]
        profileName = params[:profileName]
        createProfileIfNotExists = params[:createProfileIfNotExists] || false
        #
        profileCreationSettings = params[:profileCreationSettings]
        profileAuthType = profileCreationSettings&.dig(:authType)
        profileUsername = profileCreationSettings&.dig(:username)
        profilePassword = profileCreationSettings&.dig(:password)
        profileTestingGroupNames= profileCreationSettings&.dig(:testingGroupNames)
        #
        appPath = params[:appPath]
        message = params[:message]

        profileAuthType = AUTH_TYPE_MAPPING[profileAuthType] # map input to API values

        # Validate auth input (either-or, not both, not none)
        if personalAPIToken.nil? && personalAccessKey.nil?
          UI.user_error!("Either Personal API Token or Personal Access Key is required to authenticate connections to Appcircle services. Please provide a valid access token or access key.")
        elsif !personalAPIToken.nil? && !personalAccessKey.nil?
          UI.user_error!("Personal API Token and Personal Access Key cannot be used together. Please provide only one authentication method.")
        end

        # Auth
        authToken = self.ac_login(personal_api_token: personalAPIToken,
                                  personal_access_key: personalAccessKey,
                                  sub_organization_name: subOrganizationName)

        # Get or create profile
        profileId = self.ac_get_or_create_profile(authToken, profileName, createProfileIfNotExists, profileCreationSettings, profileAuthType, profileUsername, profilePassword, profileTestingGroupNames)

        # Upload package
        self.ac_upload(authToken, appPath, profileId, profileName, message)
      end

      def self.ac_login(personal_api_token:, personal_access_key:, sub_organization_name:)
        begin
          token = ''

          if personal_access_key
            user = TDAuthService.get_ac_token_with_personal_access_key(personal_access_key: personal_access_key)
          else
            user = TDAuthService.get_ac_token(pat: personal_api_token)
          end
          UI.success("Login is successful.")
          token = user.accessToken

          if sub_organization_name
            if personal_access_key
              UI.important("Warning: subOrganizationName is currently only supported with personalAPIToken auth. Ignoring sub-organization switch for Personal Access Key login.")
            else
              organization_id = TDAuthService.get_organization_id(access_token: token, name: sub_organization_name)
              user = TDAuthService.get_ac_token(pat: personal_api_token, sub_organization_id: organization_id)
              UI.message("Switched to sub-organization: #{sub_organization_name}")
              token = user.accessToken
            end
          end

          return token

        rescue => e
          UI.user_error!("Login failed: \"#{e.message}\".")
        end
      end

      def self.ac_get_or_create_profile(authToken, profileName, createProfileIfNotExists, profileCreationSettings, profileAuthType, profileUsername, profilePassword, profileTestingGroupNames)
        begin
          profileId = TDUploadService.get_profile_id(authToken, profileName)

          if profileId
            UI.message("Profile '#{profileName}' found with ID: #{profileId}.")
            UI.important("Warning: Profile '#{profileName}' already exists, so the provided profile creation settings will be ignored. To update the profile settings, please use the Appcircle web interface.") if profileCreationSettings

          elsif profileId.nil? && !createProfileIfNotExists
            UI.user_error!("Error: Profile '#{profileName}' not found. The option 'createProfileIfNotExists' is set to false, so a new profile was not created. To automatically create a new profile when it doesn't exist, set 'createProfileIfNotExists' to true.")
          elsif profileId.nil? && createProfileIfNotExists
            UI.message("Profile '#{profileName}' not found. Creating the new profile...")
            profileId = TDUploadService.create_profile(authToken, profileName, profileAuthType, profileUsername, profilePassword, profileTestingGroupNames)
          end

          return profileId
          
        rescue => e
          UI.user_error!("Couldn't get the profile: \"#{e.message}\".")
        end
      end

      def self.ac_upload(token, appPath, profileID, profileName, message)
        begin
          UI.message("Upload started.")
          response = TDUploadService.upload_artifact(token: token, message: message, app: appPath, dist_profile_id: profileID)
          result = self.checkTaskStatus(token, response['taskId'])

          if result
            UI.success("#{appPath} uploaded to profile '#{profileName}' successfully  🎉")
          end
        rescue => e
          status_code = e.respond_to?(:response) && e.response ? e.response.code : 'unknown'
          UI.user_error!("Upload failed with status code '#{status_code}', with message \"#{e.message}\".")
        end
      end

      def self.checkTaskStatus(authToken, taskId)
        uri = URI.parse("https://api.appcircle.io/task/v1/tasks/#{taskId}")
        
        check_interval = 1
        # timeout = 2 * 60 * 60 # 2 hours in seconds
        # start_time = Time.now
      
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
              UI.user_error!("Upload could not be completed successfully.")
            end
          else
            UI.user_error!("Upload failed with response code #{response.code} and message '#{response.message}'.")
          end

          # if Time.now - start_time > timeout
          #   UI.user_error!("Task Id #{taskId} timed out after 2 hours.")
          # end
        end
      end

      def self.send_request(uri, access_token)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == "https")
        request = Net::HTTP::Get.new(uri.request_uri)
        request["Authorization"] = "Bearer #{access_token}"
        http.request(request)
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
                                       description: "Provide Personal API Token to authenticate connections to Appcircle services (alternative to personalAccessKey)",
                                       optional: true,
                                       type: String),

          FastlaneCore::ConfigItem.new(key: :personalAccessKey,
                                       env_name: "AC_PERSONAL_ACCESS_KEY",
                                       description: "Provide Personal Access Key to authenticate connections to Appcircle services (alternative to personalAPIToken)",
                                       optional: true,
                                       type: String),

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
                                         UI.user_error!("Profile name cannot be empty. Please provide a testing distribution profile name.") unless value && !value.empty?
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
                                         # Parse and Validate
                                         if value[:authType] && !value[:authType].empty?
                                           UI.user_error!("Invalid authType: '#{value[:authType]}'. Options: 'none' (None), 'static' (Static Username and Password), 'ldap' (LDAP Login), 'sso' (SSO Login).") unless AUTH_TYPE_MAPPING.key?(value[:authType])

                                           if value[:authType] == 'static'
                                             UI.user_error!("username must be a String and at least 6 characters long.") unless value[:username].kind_of?(String) && value[:username].length >= 6
                                             UI.user_error!("password must be a String and at least 6 characters long.") unless value[:password].kind_of?(String) && value[:password].length >= 6
                                           else
                                             value[:username] = nil
                                             value[:password] = nil
                                           end
                                         end

                                         if value[:testingGroupNames] && !value[:testingGroupNames].empty?
                                           value[:testingGroupNames] = value[:testingGroupNames].to_s.split(",").map(&:strip)
                                           UI.user_error!("testingGroupNames must be a string array. Ex: 'group1, group2, group3'.") unless value[:testingGroupNames].kind_of?(Array)
                                         end
                                       end),

          FastlaneCore::ConfigItem.new(key: :appPath,
                                       env_name: "AC_APP_PATH",
                                       description: "Specify the path to your application file. For iOS, this can be a .ipa file path. For Android, specify the .apk or .aab file path",
                                       optional: false,
                                       type: String,
                                       verify_block: proc do |value|
                                         UI.user_error!("Application file path cannot be empty. Please provide a valid application file path.") unless value && !value.empty?

                                         file_extension = File.extname(value).downcase
                                         unless VALID_EXTENSIONS.include?(file_extension)
                                           UI.user_error!("Invalid file extension: '#{file_extension}'. For Android, use .apk or .aab. For iOS, use .ipa.")
                                         end
                                       end),

          FastlaneCore::ConfigItem.new(key: :message,
                                       env_name: "AC_MESSAGE",
                                       description: "Message to include with the distribution to provide additional information to testers or users receiving the build",
                                       optional: false,
                                       type: String,
                                       verify_block: proc do |value|
                                         UI.user_error!("Message field cannot be empty. Please provide a message.") unless value && !value.empty?
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
