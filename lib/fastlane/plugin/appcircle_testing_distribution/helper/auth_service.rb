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

module AuthService
  def self.get_ac_token(pat:)
    endpoint_url = 'https://auth.appcircle.io/auth/v2/token'
    uri = URI(endpoint_url)

    # Create HTTP request
    request = Net::HTTP::Post.new(uri)
    request.content_type = 'application/x-www-form-urlencoded'
    request['Accept'] = 'application/json'
    
    # Encode parameters
    params = { pat: pat }
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
      raise "HTTP Request failed (#{response.code} #{response.message})"
    end
  end
end