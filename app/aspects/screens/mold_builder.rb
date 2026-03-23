# frozen_string_literal: true

require "dry/monads"
require "initable"
require "refinements/hash"

module Terminus
  module Aspects
    module Screens
      # Initializes and builds a screen mold.
      class MoldBuilder
        include Deps["aspects.models.finder", palette_repository: "repositories.palette"]
        include Initable[mold: Mold, fallbacks: {grays: 0, color_codes: []}]
        include Dry::Monads[:result]

        using Refinements::Hash

        def call model_id: nil, device_id: nil, **attributes
          finder.call(model_id:, device_id:)
                .fmap { |model| palette_attributes_for model }
                .fmap { |model, palette| build model, palette, attributes }
                .bind do |mold|
                  mold.image? ? Success(mold) : Failure("Unsupported MIME Type: #{mold.mime_type}.")
                end
        end

        private

        def palette_attributes_for model
          palette = palette_repository.find_by name: model.palette_names.last
          attributes = palette ? palette.screen_attributes : fallbacks

          [model, attributes]
        end

        def build model, palette_attributes, attributes
          allowed_keys = mold.members

          mold.new(
            **model.to_h.transform_keys!(id: :model_id).slice(*allowed_keys),
            **palette_attributes,
            **attributes.slice(*allowed_keys)
          )
        end
      end
    end
  end
end
