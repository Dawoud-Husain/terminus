# auto_register: false
# frozen_string_literal: true

module Terminus
  module Jobs
    module Synchronizers
      # Synchronizes TRMNL palettes for local use.
      class Palette < Base
        include Deps["aspects.palettes.synchronizer"]

        sidekiq_options queue: "within_1_minute"

        def perform = synchronizer.call
      end
    end
  end
end
