require 'net/http'
require 'uri'
require 'json'
require 'rest-client'

BASE_URL = "https://api.appcircle.io"

module TDUploadService
  UI = FastlaneCore::UI

  def self.upload_artifact(token:, message:, app:, dist_profile_id:)
    file_path = app
    file_name = File.basename(file_path)
    file_size = File.size(file_path)

    upload_info_url = "#{BASE_URL}/distribution/v1/profiles/#{dist_profile_id}/app-versions"
    headers = {
      Authorization: "Bearer #{token}",
      accept: 'application/json'
    }

    uri = URI(upload_info_url)
    uri.query = URI.encode_www_form({
      action: 'uploadInformation',
      fileName: file_name,
      fileSize: file_size
    })

    begin
      UI.message("Getting file upload information...")
      response = RestClient.get(uri.to_s, headers)
      upload_info = JSON.parse(response.body)
      if response.code.between?(200, 299)
        UI.success("File upload information retrieved successfully with status code: #{response.code}")
      else
        UI.error("Failed to retrieve file upload information with status code: #{response.code}")
        raise "Failed to retrieve file upload information."
      end
      file_id = upload_info['fileId']
      upload_url = upload_info['uploadUrl']

      file_content = File.binread(file_path)
      UI.message("Uploading file to Appcircle...")
      response = RestClient.put(
        upload_url,
        file_content,
        { content_type: 'application/octet-stream' }
      )
      if response.code.between?(200, 299)
        UI.success("File upload finished successfully with status code: #{response.code}")
      else
        UI.error("File upload failed with status code: #{response.code}")
        raise "File upload failed."
      end

      commit_url = "#{BASE_URL}/distribution/v1/profiles/#{dist_profile_id}/app-versions"
      uri = URI(commit_url)
      uri.query = URI.encode_www_form({ action: 'commitFileUpload' })

      commit_payload = {
        fileId: file_id,
        fileName: file_name,
        message: message
      }.to_json

      commit_headers = {
        Authorization: "Bearer #{token}",
        content_type: :json,
        accept: 'application/json'
      }

      UI.message("Committing file upload...")
      commit_response = RestClient.post(uri.to_s, commit_payload, commit_headers)
      if commit_response.code.between?(200, 299)
        result = JSON.parse(commit_response.body)
        UI.success("Commit successful with status code: #{commit_response.code}")
      else
        UI.error("Commit failed with status code: #{commit_response.code}")
        raise "Commit failed with status code: #{commit_response.code}"
      end

      return result
    rescue RestClient::ExceptionWithResponse => e
      raise e
    rescue StandardError => e
      raise e
    end
  end

  def self.get_distribution_profiles(auth_token:)
    url = "#{BASE_URL}/distribution/v2/profiles"
  
    # Set up the headers with authentication
    headers = {
      Authorization: "Bearer #{auth_token}",
      accept: 'application/json'
    }
  
    begin
      response = RestClient.get(url, headers)
      JSON.parse(response.body)
    rescue RestClient::ExceptionWithResponse => e
      raise e
    rescue StandardError => e
      raise e
    end
  end

  def self.get_testing_groups(auth_token:)
    url = "#{BASE_URL}/distribution/v2/testing-groups"
  
    # Set up the headers with authentication
    headers = {
      Authorization: "Bearer #{auth_token}",
      accept: 'application/json'
    }
  
    begin
      response = RestClient.get(url, headers)
      JSON.parse(response.body)
    rescue RestClient::ExceptionWithResponse => e
      raise e
    rescue StandardError => e
      raise e
    end
  end

  def self.create_distribution_profile(name:, auth_token:)
    url = "#{BASE_URL}/distribution/v2/profiles"
    headers = {
      Authorization: "Bearer #{auth_token}",
      content_type: :json,
      accept: 'application/json'
    }
    payload = {
      name: name
    }.to_json
  
    begin
      response = RestClient.post(url, payload, headers)
      JSON.parse(response.body)
    rescue RestClient::ExceptionWithResponse => e
      raise e
    rescue StandardError => e
      raise e
    end
  end

  def self.update_distribution_profile(profile_id:, auth_type:, username:, password:, testing_group_ids:, auth_token:)
    url = "#{BASE_URL}/distribution/v2/profiles/#{profile_id}"
    headers = {
      Authorization: "Bearer #{auth_token}",
      content_type: :json,
      accept: 'application/json-patch+json'
    }

    ### Construct the payload
    payload = {}

    settings_payload = {
        authenticationType: auth_type,
        username: username,
        password: password
    }.compact

    payload[:settings] = settings_payload unless settings_payload.empty?
    payload[:testingGroupIds] = testing_group_ids unless testing_group_ids&.empty?

    payload = payload.compact.to_json
    ###

    begin
      response = RestClient.patch(url, payload, headers)
      JSON.parse(response.body)
    rescue RestClient::ExceptionWithResponse => e
      raise e
    rescue StandardError => e
      raise e
    end
  end

  def self.get_profile_id(authToken, profileName)
    profileId = nil

    begin
      profiles = TDUploadService.get_distribution_profiles(auth_token: authToken)
      profiles.each do |profile|
        if profile["name"] == profileName
          profileId = profile['id']
          break
        end
      end
    rescue => e
      raise "Something went wrong while fetching profiles: #{e.message}."
    end

    return profileId
  end

  def self.get_testing_group_ids(authToken, testingGroupNames)
    testingGroupIds = []
    remainingGroupNames = Set.new(testingGroupNames)

    begin
      groups = TDUploadService.get_testing_groups(auth_token: authToken)

      groups.each do |group|
        if remainingGroupNames.include?(group["name"])
          testingGroupIds.push(group['id'])
          remainingGroupNames.delete(group["name"])
        end
      end
    rescue => e
      raise "Something went wrong while fetching testing groups: #{e.message}."
    end

    raise "Following testing groups couldn't be found: '#{remainingGroupNames.to_a.join(', ')}'. Aborting profile creation..." unless remainingGroupNames.empty?

    return testingGroupIds
  end

  def self.create_profile(authToken, profileName, profileAuthType, profileUsername, profilePassword, profileTestingGroupNames)
    # Get testing group IDs
    if !profileTestingGroupNames&.empty?
      profileTestingGroupIds = TDUploadService.get_testing_group_ids(authToken, profileTestingGroupNames)
    end
    
    # Create
    begin
      new_profile = TDUploadService.create_distribution_profile(
        name: profileName,
        auth_token: authToken
      )
      if new_profile.nil?
        raise "Error: The new profile could not be created."
      end
      profileId = new_profile['id']
    rescue => e
      raise "Something went wrong while creating a new profile: #{e.message}."
    end

    # Configure
    begin
      Fastlane::UI.message("Configuring the profile...")
      configured_profile = TDUploadService.update_distribution_profile(
        profile_id: profileId,
        auth_type: profileAuthType,
        username: profileUsername,
        password: profilePassword,
        testing_group_ids: profileTestingGroupIds,
        auth_token: authToken
      )
      if configured_profile.nil?
        raise "Error: The new profile could not be configured."
      end
      profileId = configured_profile['id'] # Should be the same as before
    rescue => e
      raise "Something went wrong while configuring the new profile: #{e.message}."
    end

    return profileId
  end

end
