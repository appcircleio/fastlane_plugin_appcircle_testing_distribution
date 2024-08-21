require 'net/http'
require 'uri'
require 'json'
require 'rest-client'

BASE_URL = "https://api.appcircle.io"

module TDUploadService
  def self.upload_artifact(token:, message:, app:, dist_profile_id:)
    url = "https://api.appcircle.io/distribution/v2/profiles/#{dist_profile_id}/app-versions"
    headers = {
      Authorization: "Bearer #{token}",
      Message: message,
      content_type: :multipart
    }
    payload = {
      Message: message,
      File: File.new(app, 'rb')
    }
  
    begin
      response = RestClient.post(url, payload, headers)
      JSON.parse(response.body) rescue response.body
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
      parsed_response = JSON.parse(response.body)
  
      parsed_response
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

  def self.get_profile_id(authToken, profileName, createProfileIfNotExists)
    profileId = nil

    begin
      profiles = TDUploadService.get_distribution_profiles(auth_token: authToken)
      profiles.each do |profile|
        if profile["name"] == profileName
          profileId = profile['id']
        end
      end
    rescue => e
      raise "Something went wrong while fetching profiles: #{e.message}"
    end
      
    if profileId.nil? && !createProfileIfNotExists
      raise "Error: The test profile '#{profileName}' could not be found. The option 'createProfileIfNotExists' is set to false, so no new profile was created. To automatically create a new profile if it doesn't exist, set 'createProfileIfNotExists' to true."
    end

    if profileId.nil? && createProfileIfNotExists
      begin
        puts "The test profile '#{profileName}' could not be found. A new profile is being created..."
        new_profile = TDUploadService.create_distribution_profile(name: profileName, auth_token: authToken)
        if new_profile.nil?
          raise "Error: The new profile could not be created."
        end
        profileId = new_profile['id']
      rescue => e
        raise "Something went wrong while creating a new profile: #{e.message}"
      end
    end

    return profileId
  end

end
