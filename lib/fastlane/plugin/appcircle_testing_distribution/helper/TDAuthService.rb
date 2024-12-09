require 'net/http'
require 'uri'
require 'cgi'
require 'json'


class UserResponse
  attr_accessor :accessToken

  def initialize(accessToken:)
    @accessToken = accessToken
  end
end

module TDAuthService
  def self.get_ac_token(pat:, sub_organization_id: nil)
    endpoint_url = 'https://auth.appcircle.io/auth/v2/token'
    uri = URI(endpoint_url)

    # Create HTTP request
    request = Net::HTTP::Post.new(uri)
    request.content_type = 'application/x-www-form-urlencoded'
    request['Accept'] = 'application/json'
    
    # Encode parameters
    params = { pat: pat }
    params[:subOrganizationId] = sub_organization_id if sub_organization_id
    request.body = URI.encode_www_form(params)

    # Make the HTTP request
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
      http.request(request)
    end

    # Check response
    if response.is_a?(Net::HTTPSuccess)
      response_data = JSON.parse(response.body)

      user = UserResponse.new(
        accessToken: response_data['access_token']
      )

      return user
    else
      raise "Error: (#{response.code} #{response.message})."
    end
  end

  def self.get_organization_id(access_token:, name:)
    endpoint_url = 'https://api.appcircle.io/identity/v1/organizations'
    uri = URI(endpoint_url)
  
    # Create HTTP request
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{access_token}"
    request['Accept'] = 'application/json'
  
    # Make the HTTP request
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
      http.request(request)
    end
  
    # Check response
    if response.is_a?(Net::HTTPSuccess)
      response_data = JSON.parse(response.body)
      organizations = response_data['data']
      organization = organizations.find { |org| org['name'] == name }
      
      raise "Organization with name '#{name}' not found" unless organization
      return organization['id']

    else
      raise "HTTP Request failed (#{response.code} #{response.message})"
    end
  end
end