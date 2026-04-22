# frozen_string_literal: true

require "refinements/hash"

module Terminus
  module Aspects
    module Extensions
      # Automates upgrading poll extensions to use exchanges.
      class Upgrader
        include Deps[
          :logger,
          extension_repository: "repositories.extension",
          exchange_repository: "repositories.extension_exchange"
        ]

        using Refinements::Hash

        def call
          extension_repository.where(kind: "poll").each do |extension|
            create_exchange extension
            logger.info { "Upgraded extension: #{extension.id}." }
          end
        end

        def create_exchange extension
          attributes = extension.to_h
                                .slice(:headers, :verb, :uris, :body)
                                .transform_keys!(uris: :template)
                                .transform_value!(:template) { it.join "\n" }

          exchange_repository.create extension_id: extension.id, **attributes
        end
      end
    end
  end
end
