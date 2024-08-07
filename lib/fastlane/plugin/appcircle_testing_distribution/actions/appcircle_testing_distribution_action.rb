require 'fastlane/action'
require 'net/http'
require 'uri'
require 'json'
require_relative '../helper/appcircle_testing_distribution_helper'

module Fastlane
  module Actions
    class AppcircleTestingDistributionAction < Action
      def self.run(params)
        accessToken = params[:accessToken]
        profileID = params[:profileID]
        appPath = params[:appPath]
        message = params[:message]

        if accessToken.nil?
          raise UI.error("Access token is required to authenticate connections to Appcircle services. Please provide a valid access token")
        elsif profileID.nil?
          raise UI.error("Distribution profile ID is required to distribute applications. Please provide a valid distribution profile ID")
        elsif appPath.nil?
          raise UI.error("Application file path is required to distribute applications. Please provide a valid application file path")
        elsif message.nil?
          raise UI.error("Message field is required. Please provide a valid message")
        end


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
      
      def self.checkTaskStatus(taskId)
        uri = URI.parse("https://api.appcircle.io/task/v1/tasks/#{taskId}")
        timeout = 1
        jwtToken = `appcircle config get AC_ACCESS_TOKEN -o json`
        apiAccessToken = JSON.parse(jwtToken)
        
        response = self.send_request(uri, apiAccessToken["AC_ACCESS_TOKEN"])
        if response.is_a?(Net::HTTPSuccess)
          stateValue = JSON.parse(response.body)["stateValue"]
          
          if stateValue == 1
            sleep(1)
            return checkTaskStatus(taskId)
          end
          if stateValue == 3
            return true
          else
            UI.error("Task Id #{taskId} failed with state value #{stateValue}")
            raise "Upload could not completed successfully"
          end
        else
          UI.error("Request failed with response code #{response.code} and message #{response.message}")
          raise "Request failed"
        end
      end

      def self.send_request(uri, access_token)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == "https")
        request = Net::HTTP::Get.new(uri.request_uri)
        request["Authorization"] = "Bearer #{access_token}"
        http.request(request)
      end

      def self.ac_upload(appPath, profileID, message)
        ac_upload = `appcircle testing-distribution upload --app=#{appPath} --distProfileId=#{profileID} --message "#{message}" -o json`
        taskId = JSON.parse(ac_upload)["taskId"]
        UI.message("taskID #{taskId}")
        result = self.checkTaskStatus(taskId)

        if $?.success? and result
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
                                       description: "Provide the Appcircle access token to authenticate connections to Appcircle services",
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
