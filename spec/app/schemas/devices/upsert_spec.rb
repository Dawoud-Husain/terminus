# frozen_string_literal: true

require "hanami_helper"

RSpec.describe Terminus::Schemas::Devices::Upsert do
  subject(:contract) { described_class }

  describe "#call" do
    let :attributes do
      {
        model_id: 1,
        playlist_id: nil,
        label: "Test",
        friendly_id: "ABC123",
        mac_address: "AA:BB:CC:11:22:33",
        api_key: "secret",
        refresh_rate: 100,
        image_timeout: 0,
        proxy: "on",
        firmware_update: "on",
        firmware_version: "1.2.3",
        battery_charge: 85.0,
        battery_voltage: 3.5,
        wifi: -75,
        width: 800,
        height: 480,
        wake_reason: "Awoken from test.",
        sleep_start_at: "18:00:00",
        sleep_end_at: "06:00:00"
      }
    end

    it "answers success when all attributes are valid" do
      expect(contract.call(attributes).to_monad).to be_success
    end

    it "answers failure when battery charge is less than zero" do
      attributes[:battery_charge] = -1

      expect(contract.call(attributes).errors.to_h).to include(
        battery_charge: ["must be greater than or equal to 0"]
      )
    end

    it "answers failure when refresh rate is less than zero" do
      attributes[:refresh_rate] = -1

      expect(contract.call(attributes).errors.to_h).to include(
        refresh_rate: ["must be greater than 0"]
      )
    end

    it "answers failure when image timeout is less than zero" do
      attributes[:image_timeout] = -1

      expect(contract.call(attributes).errors.to_h).to include(
        image_timeout: ["must be greater than or equal to 0"]
      )
    end

    it "answers true when proxy is truthy" do
      expect(contract.call(attributes).to_h).to include(proxy: true)
    end

    it "answers false when proxy key is missing" do
      attributes.delete :proxy
      expect(contract.call(attributes).to_h).to include(proxy: false)
    end

    it "answers true when firmware update is truthy" do
      expect(contract.call(attributes).to_h).to include(firmware_update: true)
    end

    it "answers false when firmware update key is missing" do
      attributes.delete :firmware_update
      expect(contract.call(attributes).to_h).to include(firmware_update: false)
    end
  end
end
