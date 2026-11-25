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
  class TokenRequestError < RuntimeError
    attr_reader :code

    def initialize(code, message)
      super(message)
      @code = code
    end
  end

  CLOUD_AUTH_ENDPOINT = 'https://auth.appcircle.io'.freeze
  CLOUD_API_ENDPOINT = 'https://api.appcircle.io'.freeze

  def self.validate_endpoints(auth_endpoint:, api_endpoint:)
    return if cloud_endpoint?(auth_endpoint, CLOUD_AUTH_ENDPOINT) == cloud_endpoint?(api_endpoint, CLOUD_API_ENDPOINT)

    raise 'Set both authEndpoint and apiEndpoint for a self-hosted Appcircle server, or leave both empty for the Appcircle cloud.'
  end

  def self.normalize_endpoint(endpoint, cloud_endpoint)
    value = endpoint.to_s.strip.sub(%r{/+\z}, '')
    value.empty? ? cloud_endpoint : value
  end

  def self.cloud_endpoint?(endpoint, cloud_endpoint)
    normalize_endpoint(endpoint, cloud_endpoint).casecmp?(cloud_endpoint)
  end

  def self.get_ac_token(pat:, sub_organization_id: nil, auth_endpoint: 'https://auth.appcircle.io')
    endpoint_url = "#{auth_endpoint}/auth/v2/token"
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
      raise TokenRequestError.new(response.code, "Error: (#{response.code} #{response.message}).")
    end
  end

  def self.get_ac_token_with_personal_access_key(personal_access_key:, auth_endpoint: 'https://auth.appcircle.io')
    endpoint_url = "#{auth_endpoint}/auth/v1/token"
    uri = URI(endpoint_url)

    # Create HTTP request
    request = Net::HTTP::Post.new(uri)
    request.content_type = 'application/x-www-form-urlencoded'
    request['Accept'] = 'application/json'

    # Encode parameters
    params = { pat: personal_access_key }
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

  def self.get_organization_id(access_token:, name:, api_endpoint: 'https://api.appcircle.io')
    uri = URI("#{api_endpoint}/identity/v1/organizations")
    uri.query = URI.encode_www_form(page: 1, perPage: 1000)

    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{access_token}"
    request['Accept'] = 'application/json'

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
      http.request(request)
    end

    raise "Could not list the organizations of this token (HTTP #{response.code})." unless response.kind_of?(Net::HTTPSuccess)

    payload = begin
      JSON.parse(response.body)
    rescue JSON::ParserError
      nil
    end
    raise 'Could not list the organizations of this token (unexpected response).' unless payload.kind_of?(Hash)

    organizations = payload['data'].kind_of?(Array) ? payload['data'] : []
    organization = organizations.find { |org| org['name'] == name }
    raise "Sub-organization '#{name}' could not be found or is not accessible with this token." if organization.nil? || organization['id'].to_s.empty?

    organization['id']
  end

  def self.switch_to_sub_organization(root_token:, name:, pat:, auth_endpoint:, api_endpoint:)
    organization_id = get_organization_id(access_token: root_token, name: name, api_endpoint: api_endpoint)
    begin
      user = get_ac_token(pat: pat, sub_organization_id: organization_id, auth_endpoint: auth_endpoint)
    rescue TokenRequestError => e
      raise "Could not authenticate against sub-organization '#{name}' (HTTP #{e.code})."
    rescue JSON::ParserError
      raise "Could not obtain an access token for sub-organization '#{name}'."
    end

    token = user.accessToken
    raise "Could not obtain an access token for sub-organization '#{name}'." if token.nil? || token.to_s.empty?

    token
  end
end
