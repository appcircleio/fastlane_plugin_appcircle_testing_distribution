describe Fastlane::Actions::AppcircleTestingDistributionAction do
  describe '#run' do
    it 'prints a message' do
      expect(Fastlane::UI).to receive(:message).with("The appcircle_testing_distribution plugin is working!")

      Fastlane::Actions::AppcircleTestingDistributionAction.run(nil)
    end
  end
end
