describe Fastlane::Actions::AppcircleTestingDistributionAction do
  let(:action) { described_class }
  let(:endpoints) { { auth_endpoint: 'https://auth.example.test', api_endpoint: 'https://api.example.test' } }

  def login(personal_api_token: nil, personal_access_key: nil, sub_organization_name: nil)
    action.ac_login(
      personal_api_token: personal_api_token, personal_access_key: personal_access_key,
      sub_organization_name: sub_organization_name, **endpoints
    )
  end

  describe '.ac_login' do
    it 'keeps the root token when no sub-organization name is given' do
      allow(TDAuthService).to receive(:get_ac_token).and_return(UserResponse.new(accessToken: 'root-token'))
      expect(TDAuthService).not_to receive(:switch_to_sub_organization)

      [nil, '', '   '].each do |name|
        expect(login(personal_api_token: 'my-pat', sub_organization_name: name)).to eq('root-token')
      end
    end

    it 'switches to the sub-organization token with the PAT' do
      allow(TDAuthService).to receive(:get_ac_token).and_return(UserResponse.new(accessToken: 'root-token'))
      expect(TDAuthService).to receive(:switch_to_sub_organization).with(
        root_token: 'root-token', name: 'PlugInTest', pat: 'my-pat',
        auth_endpoint: 'https://auth.example.test', api_endpoint: 'https://api.example.test'
      ).and_return('sub-token')

      expect(login(personal_api_token: 'my-pat', sub_organization_name: ' PlugInTest ')).to eq('sub-token')
    end

    it 'switches to the sub-organization token with the personal access key' do
      allow(TDAuthService).to receive(:get_ac_token_with_personal_access_key).and_return(UserResponse.new(accessToken: 'root-token'))
      expect(TDAuthService).to receive(:switch_to_sub_organization).with(
        root_token: 'root-token', name: 'PlugInTest', pat: 'my-pak',
        auth_endpoint: 'https://auth.example.test', api_endpoint: 'https://api.example.test'
      ).and_return('sub-token')
      expect(Fastlane::UI).not_to receive(:important)

      expect(login(personal_access_key: 'my-pak', sub_organization_name: 'PlugInTest')).to eq('sub-token')
    end

    it 'fails the lane when the sub-organization switch fails' do
      allow(TDAuthService).to receive(:get_ac_token).and_return(UserResponse.new(accessToken: 'root-token'))
      allow(TDAuthService).to receive(:switch_to_sub_organization)
        .and_raise(RuntimeError, "Sub-organization 'Missing' could not be found or is not accessible with this token.")

      expect do
        login(personal_api_token: 'my-pat', sub_organization_name: 'Missing')
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /Sub-organization 'Missing' could not be found or is not accessible with this token\./)
    end
  end

  describe '.run' do
    it 'stops before the login when only one endpoint is self-hosted' do
      params = {
        personalAPIToken: 'my-pat',
        personalAccessKey: nil,
        profileName: 'Example Profile',
        appPath: 'test.ipa',
        message: 'Test message',
        authEndpoint: 'https://auth.example.test',
        apiEndpoint: nil
      }
      expect(action).not_to receive(:ac_login)

      expect { action.run(params) }.to raise_error(FastlaneCore::Interface::FastlaneError, 'Set both authEndpoint and apiEndpoint for a self-hosted Appcircle server, or leave both empty for the Appcircle cloud.')
    end

    it 'uses the cloud endpoints when the endpoint options are empty' do
      params = {
        personalAPIToken: 'my-pat',
        personalAccessKey: nil,
        profileName: 'Example Profile',
        appPath: 'test.ipa',
        message: 'Test message',
        authEndpoint: '',
        apiEndpoint: ' '
      }
      expect(action).to receive(:ac_login)
        .with(hash_including(auth_endpoint: 'https://auth.appcircle.io', api_endpoint: 'https://api.appcircle.io'))
        .and_return('root-token')
      allow(action).to receive(:ac_get_or_create_profile).and_return('profile-id')
      allow(action).to receive(:ac_upload)

      action.run(params)
    end
  end
end
