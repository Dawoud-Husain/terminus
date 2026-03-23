# frozen_string_literal: true

require "hanami_helper"

RSpec.describe Terminus::Aspects::Screens::MoldBuilder, :db do
  subject(:builder) { described_class.new }

  describe "#call" do
    it "answers mold with palette color codes" do
      Factory[
        :palette,
        name: "color-4bwry",
        grays: 2,
        colors: %w[#000000 #FF0000 #FFFFFF #FFFF00]
      ]

      model = Factory[:model, bit_depth: 1, colors: 2, palette_names: %w[color-4bwry]]

      expect(builder.call(model_id: model.id, name: "test", label: "Test")).to be_success(
        Terminus::Aspects::Screens::Mold[
          model_id: model.id,
          name: "test",
          label: "Test",
          bit_depth: 1,
          grays: 2,
          colors: 2,
          color_codes: %w[#000000 #FF0000 #FFFFFF #FFFF00],
          mime_type: "image/png",
          rotation: 0,
          offset_x: 0,
          offset_y: 0,
          width: 800,
          height: 480
        ]
      )
    end

    it "answers mold with last palette when multiple palettes are supported" do
      Factory[:palette, name: "bw"]
      Factory[:palette, name: "gray-4", grays: 4]

      model = Factory[:model, bit_depth: 1, colors: 2, palette_names: %w[bw gray-4]]

      expect(builder.call(model_id: model.id, name: "test", label: "Test")).to be_success(
        Terminus::Aspects::Screens::Mold[
          model_id: model.id,
          name: "test",
          label: "Test",
          bit_depth: 1,
          grays: 4,
          colors: 2,
          color_codes: [],
          mime_type: "image/png",
          rotation: 0,
          offset_x: 0,
          offset_y: 0,
          width: 800,
          height: 480
        ]
      )
    end

    it "answers mold with palette fallbacks" do
      model = Factory[:model, bit_depth: 1, colors: 2, palette_names: ["bogus"]]

      expect(builder.call(model_id: model.id, name: "test", label: "Test")).to be_success(
        Terminus::Aspects::Screens::Mold[
          model_id: model.id,
          name: "test",
          label: "Test",
          bit_depth: 1,
          grays: 0,
          colors: 2,
          color_codes: [],
          mime_type: "image/png",
          rotation: 0,
          offset_x: 0,
          offset_y: 0,
          width: 800,
          height: 480
        ]
      )
    end

    it "answers failure with invalid MIME Type" do
      model = Factory[:model]

      expect(builder.call(model_id: model.id, mime_type: "text/html")).to be_failure(
        "Unsupported MIME Type: text/html."
      )
    end
  end
end
