require 'uri'
require 'json'

describe TDAuthService do
  let(:auth_endpoint) { 'https://auth.example.test' }
  let(:api_endpoint) { 'https://api.example.test' }
  let(:sub_org_id) { 'b8610467-5cf8-49c3-81ad-35d7fbd048ec' }
  let(:organizations) do
    {
      'data' => [
        { 'id' => 'root-id', 'name' => 'Root Org' },
        { 'id' => sub_org_id, 'name' => 'PlugInTest' },
        { 'id' => 'other-id', 'name' => 'plugintest' }
      ]
    }.to_json
  end

  def http_response(code, body)
    response = Net::HTTPResponse::CODE_TO_OBJ[code.to_s].new('1.1', code.to_s, 'message')
    allow(response).to receive(:body).and_return(body)
    response
  end

  def stub_http(*replies)
    requests = []
    http = double('http')
    allow(Net::HTTP).to receive(:start).and_yield(http)
    allow(http).to receive(:request) do |request|
      requests << request
      code, body = replies.shift
      http_response(code, body)
    end
    requests
  end

  def form(request)
    URI.decode_www_form(request.body).to_h
  end

  describe '.normalize_endpoint' do
    it 'uses the cloud endpoint for an empty value and removes a trailing slash' do
      [nil, '', '   '].each do |value|
        expect(TDAuthService.normalize_endpoint(value, 'https://auth.appcircle.io')).to eq('https://auth.appcircle.io')
      end
      expect(TDAuthService.normalize_endpoint(' https://auth.example.test/ ', 'https://auth.appcircle.io')).to eq('https://auth.example.test')
    end
  end

  describe '.validate_endpoints' do
    let(:message) { 'Set both authEndpoint and apiEndpoint for a self-hosted Appcircle server, or leave both empty for the Appcircle cloud.' }

    it 'accepts the cloud defaults and a full self-hosted pair' do
      [[nil, nil], ['', ' '], ['https://auth.appcircle.io/', 'https://API.appcircle.io'],
       ['https://auth.example.test', 'https://api.example.test/']].each do |auth, api|
        expect { TDAuthService.validate_endpoints(auth_endpoint: auth, api_endpoint: api) }.not_to raise_error
      end
    end

    it 'rejects a self-hosted auth endpoint without a self-hosted API endpoint' do
      [nil, 'https://api.appcircle.io'].each do |api|
        expect { TDAuthService.validate_endpoints(auth_endpoint: 'https://auth.example.test', api_endpoint: api) }
          .to raise_error(RuntimeError, message)
      end
    end

    it 'rejects a self-hosted API endpoint without a self-hosted auth endpoint' do
      expect { TDAuthService.validate_endpoints(auth_endpoint: '', api_endpoint: 'https://api.example.test') }
        .to raise_error(RuntimeError, message)
    end
  end

  describe '.get_ac_token' do
    it 'sends only the PAT when no sub-organization id is given' do
      requests = stub_http([200, { access_token: 'root-token' }.to_json])

      user = TDAuthService.get_ac_token(pat: 'my-pat', auth_endpoint: auth_endpoint)

      expect(user.accessToken).to eq('root-token')
      expect(requests.first.path).to eq('/auth/v2/token')
      expect(form(requests.first)).to eq('pat' => 'my-pat')
    end

    it 'sends the sub-organization id with the PAT' do
      requests = stub_http([200, { access_token: 'sub-token' }.to_json])

      user = TDAuthService.get_ac_token(pat: 'my-pat', sub_organization_id: sub_org_id, auth_endpoint: auth_endpoint)

      expect(user.accessToken).to eq('sub-token')
      expect(form(requests.first)).to eq('pat' => 'my-pat', 'subOrganizationId' => sub_org_id)
    end
  end

  describe '.get_ac_token_with_personal_access_key' do
    it 'sends the personal access key as the pat field to /auth/v1/token' do
      requests = stub_http([200, { access_token: 'root-token' }.to_json])

      user = TDAuthService.get_ac_token_with_personal_access_key(personal_access_key: 'my-pak', auth_endpoint: auth_endpoint)

      expect(user.accessToken).to eq('root-token')
      expect(requests.first.path).to eq('/auth/v1/token')
      expect(form(requests.first)).to eq('pat' => 'my-pak')
    end
  end

  describe '.get_organization_id' do
    it 'resolves the id by exact, case-sensitive name with the root token' do
      requests = stub_http([200, organizations], [200, organizations])

      expect(TDAuthService.get_organization_id(access_token: 'root-token', name: 'PlugInTest', api_endpoint: api_endpoint)).to eq(sub_org_id)
      expect(TDAuthService.get_organization_id(access_token: 'root-token', name: 'plugintest', api_endpoint: api_endpoint)).to eq('other-id')
      request = requests.first
      expect(request['Authorization']).to eq('Bearer root-token')
      expect(request.path).to start_with('/identity/v1/organizations?')
      expect(URI.decode_www_form(URI(request.path).query).to_h).to eq('page' => '1', 'perPage' => '1000')
    end

    it 'fails with the not-found message when no name matches' do
      stub_http([200, organizations])

      expect do
        TDAuthService.get_organization_id(access_token: 'root-token', name: 'PLUGINTEST', api_endpoint: api_endpoint)
      end.to raise_error(RuntimeError, "Sub-organization 'PLUGINTEST' could not be found or is not accessible with this token.")
    end

    it 'reports an organization response that is not JSON' do
      stub_http([200, '<html>sign in</html>'])

      expect do
        TDAuthService.get_organization_id(access_token: 'root-token', name: 'PlugInTest', api_endpoint: api_endpoint)
      end.to raise_error(RuntimeError, 'Could not list the organizations of this token (unexpected response).')
    end

    it 'sends the request to the configured API host over TLS' do
      stub_http([200, organizations])

      TDAuthService.get_organization_id(access_token: 'root-token', name: 'PlugInTest', api_endpoint: api_endpoint)

      expect(Net::HTTP).to have_received(:start).with('api.example.test', 443, use_ssl: true)
    end

    it 'reports a failed organization request' do
      stub_http([500, '{}'])

      expect do
        TDAuthService.get_organization_id(access_token: 'root-token', name: 'PlugInTest', api_endpoint: api_endpoint)
      end.to raise_error(RuntimeError, /500/)
    end
  end

  describe '.switch_to_sub_organization' do
    def switch(**credentials)
      TDAuthService.switch_to_sub_organization(
        root_token: 'root-token', name: 'PlugInTest', auth_endpoint: auth_endpoint, api_endpoint: api_endpoint, **credentials
      )
    end

    it 'returns a sub-organization token minted from the PAT' do
      requests = stub_http([200, organizations], [200, { access_token: 'sub-token' }.to_json])

      expect(switch(pat: 'my-pat')).to eq('sub-token')
      expect(requests.last.path).to eq('/auth/v2/token')
      expect(form(requests.last)).to eq('pat' => 'my-pat', 'subOrganizationId' => sub_org_id)
    end

    it 'does not request a token when the sub-organization is not found' do
      requests = stub_http([200, { 'data' => [] }.to_json])

      expect { switch(pat: 'my-pat') }.to raise_error(RuntimeError, /could not be found or is not accessible/)
      expect(requests.size).to eq(1)
    end

    it 'fails instead of falling back to the root token when the token request is rejected' do
      stub_http([200, organizations], [403, '{}'])

      expect { switch(pat: 'my-pat') }.to raise_error(RuntimeError, "Could not authenticate against sub-organization 'PlugInTest' (HTTP 403).")
    end

    it 'fails when the token response is not JSON' do
      stub_http([200, organizations], [200, 'not-json'])

      expect { switch(pat: 'my-pat') }.to raise_error(RuntimeError, "Could not obtain an access token for sub-organization 'PlugInTest'.")
    end

    it 'never puts the credential into an error message' do
      stub_http([200, organizations], [403, '{}'])

      expect { switch(pat: 'my-pat') }.to raise_error(RuntimeError) { |error| expect(error.message).not_to include('my-pat') }
    end

    it 'fails when the token response has no access token' do
      stub_http([200, organizations], [200, '{}'])

      expect { switch(pat: 'my-pat') }.to raise_error(RuntimeError, "Could not obtain an access token for sub-organization 'PlugInTest'.")
    end
  end
end
