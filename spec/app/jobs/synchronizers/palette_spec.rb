# frozen_string_literal: true

require "hanami_helper"

RSpec.describe Terminus::Jobs::Synchronizers::Palette do
  subject(:job) { described_class.new synchronizer: }

  let(:synchronizer) { instance_spy Terminus::Aspects::Palettes::Synchronizer }

  describe "#perform" do
    it "calls synchronizer" do
      job.perform
      expect(synchronizer).to have_received(:call)
    end
  end
end
