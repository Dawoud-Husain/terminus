# frozen_string_literal: true

require "hanami_helper"

RSpec.describe Terminus::Views::Parts::Firmware do
  subject(:part) { described_class.new value: firmware, rendering: Terminus::View.new.rendering }

  let(:firmware) { Factory.structs[:firmware] }

  describe "#kind_label" do
    it "answers capitalized label" do
      expect(part.kind_label).to eq("Terminus")
    end

    context "with trmnl" do
      let(:firmware) { Factory.structs[:firmware, kind: "trmnl"] }

      it "answers upcase" do
        expect(part.kind_label).to eq("TRMNL")
      end
    end
  end
end
