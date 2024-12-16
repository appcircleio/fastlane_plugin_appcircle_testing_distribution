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
      content_type: :multipart # multipart/form-data
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

  def self.update_distribution_profile(profile_id:, auth_type:, username:, password:, auth_token:)
    url = "#{BASE_URL}/distribution/v2/profiles/#{profile_id}"
    headers = {
      Authorization: "Bearer #{auth_token}",
      content_type: :json,
      accept: 'application/json-patch+json'
    }
    payload = {
      settings: {
        authenticationType: auth_type,
        username: username,
        password: password
      }
    }.to_json
  
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

  def self.create_profile(authToken, profileName, profileAuthType, profileUsername, profilePassword)
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
      puts "Configuring the profile..."
      configured_profile = TDUploadService.update_distribution_profile(
        profile_id: profileId, 
        auth_type: profileAuthType, 
        username: profileUsername, 
        password: profilePassword, 
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
