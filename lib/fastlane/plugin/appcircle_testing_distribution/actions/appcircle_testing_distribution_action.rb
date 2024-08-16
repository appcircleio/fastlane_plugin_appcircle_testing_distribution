require 'fastlane/action'
require 'net/http'
require 'uri'
require 'json'

require_relative '../helper/appcircle_testing_distribution_helper'
require_relative './auth_service'
require_relative './upload_service'

module Fastlane
  module Actions
    class AppcircleTestingDistributionAction < Action
      def self.run(params)
        accessToken = params[:accessToken]
        profileName = params[:profileName]
        appPath = params[:appPath]
        message = params[:message]
        createProfileIfNotExists = params[:createProfileIfNotExists]

        valid_extensions = ['.apk', '.aab', '.ipa']

        file_extension = File.extname(appPath).downcase
        unless valid_extensions.include?(file_extension)
          raise "Invalid file extension: #{file_extension}. For Android, use .apk or .aab. For iOS, use .ipa."
        end

        if accessToken.nil?
          raise UI.error("Access token is required to authenticate connections to Appcircle services. Please provide a valid access token")
        elsif profileName.nil?
          raise UI.error("Distribution profile name is required to distribute applications. Please provide a distribution profile name")
        elsif appPath.nil?
          raise UI.error("Application file path is required to distribute applications. Please provide a valid application file path")
        elsif message.nil?
          raise UI.error("Message field is required. Please provide a valid message")
        end


        authToken = self.ac_login(accessToken)

        profileId = UploadService.get_profile_id(authToken, profileName, createProfileIfNotExists)
        self.ac_upload(authToken, appPath, profileId, message)
      end

      def self.ac_login(accessToken)
        begin
          user = AuthService.get_ac_token(pat: accessToken)
          UI.success("Login is successful.")
          return user.accessToken
        rescue => e
          puts "Login failed: #{e.message}"
        end
      end
      
      def self.checkTaskStatus(authToken, taskId)
        uri = URI.parse("https://api.appcircle.io/task/v1/tasks/#{taskId}")
        timeout = 1
        
        response = self.send_request(uri, authToken)
        if response.is_a?(Net::HTTPSuccess)
          stateValue = JSON.parse(response.body)["stateValue"]
          
          if stateValue == 1
            sleep(1)
            return checkTaskStatus(authToken, taskId)
          end
          if stateValue == 3
            return true
          else
            UI.error("Task Id #{taskId} failed with state value #{stateValue}")
            raise "Upload could not completed successfully"
          end
        else
          UI.error("Upload failed with response code #{response.code} and message '#{response.message}'")
          raise "Upload failed with response code #{response.code} and message '#{response.message}'"
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
          response = UploadService.upload_artifact(token: token, message: message, app: appPath, dist_profile_id: profileID)
          result = self.checkTaskStatus(token, response['taskId'])

          if $?.success? and result
            UI.success("#{appPath} Uploaded to profile id #{profileID} successfully  🎉")
          end
        rescue => e
          UI.error("Upload failed with status code #{e.response.code}, with message '#{e.message}'")
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
                                       description: "Provide the Appcircle access token to authenticate connections to Appcircle services",
                                       optional: false,
                                       type: String),
          
          FastlaneCore::ConfigItem.new(key: :profileName,
                                       env_name: "AC_PROFILE_NAME",
                                       description: "Enter the profile name of the Appcircle distribution profile. This name uniquely identifies the profile under which your applications will be distributed",
                                       optional: false,
                                       type: String),
          
          FastlaneCore::ConfigItem.new(key: :createProfileIfNotExists,
                                       env_name: "AC_CREATE_PROFILE_IF_NOT_EXISTS",
                                       description: "If the profile does not exist, create a new profile with the given name",
                                       optional: true,
                                       type: Boolean),

          FastlaneCore::ConfigItem.new(key: :appPath,
                                       env_name: "AC_APP_PATH",
                                       description: "Specify the path to your application file. For iOS, this can be a .ipa or .xcarchive file path. For Android, specify the .apk or .appbundle file path",
                                       optional: false,
                                       type: String),

          FastlaneCore::ConfigItem.new(key: :message,
                                       env_name: "AC_MESSAGE",
                                       description: "Optional message to include with the distribution to provide additional information to testers or users receiving the build",
                                       optional: false,
                                       type: String)
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
