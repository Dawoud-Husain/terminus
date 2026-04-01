# frozen_string_literal: true

require "hanami_helper"

RSpec.describe Terminus::Structs::Model do
  subject(:model) { Factory.structs[:model, **attributes] }

  let :attributes do
    {
      name: "test",
      label: "Test",
      bit_depth: 4,
      css: {"classes" => {"size" => "screen--lg", "density" => "screen--density-2x"}}
    }
  end

  describe "#css_classes" do
    it "answers classes with full information" do
      expect(model.css_classes).to eq(
        "screen screen--test screen--4bit screen--landscape screen--lg " \
        "screen--1x screen--density-2x"
      )
    end

    it "answers classes with missing values" do
      attributes.merge! name: nil, bit_depth: nil

      expect(model.css_classes).to eq(
        "screen screen-- screen--bit screen--landscape screen--lg screen--1x screen--density-2x"
      )
    end

    it "answers classes without model classes" do
      attributes[:css].clear

      expect(model.css_classes).to eq(
        "screen screen--test screen--4bit screen--landscape screen--1x"
      )
    end
  end

  describe "#orientation" do
    it "answers landscape when rotation is zero" do
      expect(model.orientation).to eq("landscape")
    end

    it "answers portrait when rotation is non-zero" do
      model = Factory.structs[:model, rotation: 90]
      expect(model.orientation).to eq("portrait")
    end
  end
end
