# frozen_string_literal: true

Factory.define :model_palette, relation: :model_palette do |factory|
  factory.association :model
  factory.association :palette
end
