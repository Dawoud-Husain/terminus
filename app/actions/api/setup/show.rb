# frozen_string_literal: true

require "versionaire"

module Terminus
  module Actions
    module API
      module Setup
        # The show action.
        class Show < Base
          include Deps[
            "aspects.devices.provisioner",
            model_name_transformer: "aspects.firmware.headers.transformers.model_name",
            model_repository: "repositories.model"
          ]

          include Initable[payload: Terminus::Models::Firmware::Setup]

          using Refines::Actions::Response

          params do
            required(:HTTP_FW_VERSION).maybe Types::String.constrained(format: Versionaire::PATTERN)
            required(:HTTP_ID).filled Types::MACAddress
            required(:HTTP_MODEL).maybe :string
          end

          def handle request, response
            case validate_and_transform request.env
              in Success(headers) then create headers, response
              in Failure(result) then unprocessable_content result.errors.to_h, response
              # :nocov:
              # :nocov:
            end
          end

          protected

          def authorize(*) = nil

          private

          def validate_and_transform environment
            contract.call(environment).to_monad.bind { model_name_transformer.call it.to_h }
          end

          def create headers, response
            firmware_version, mac_address, model_name = headers.values_at :HTTP_FW_VERSION,
                                                                          :HTTP_ID,
                                                                          :HTTP_MODEL

            provisioner.call(model_id: find_model_id(model_name), mac_address:, firmware_version:)
                       .either -> device { render_success device, response },
                               -> error { not_found error, response }
          end

          def find_model_id(name) = model_repository.find_by(name:).then { it.id if it }

          def render_success device, response
            response.body = payload.for(device).to_json
          end

          def not_found error, response
            payload = problem[
              type: "/problem_details#device_setup",
              status: __method__,
              detail: error,
              instance: "/api/setup"
            ]

            response.with body: payload.to_json, format: :problem_details, status: payload.status
          end

          def unprocessable_content errors, response
            payload = problem[
              type: "/problem_details#device_setup",
              status: __method__,
              detail: "Invalid request headers.",
              instance: "/api/setup",
              extensions: {errors:}
            ]

            response.with body: payload.to_json, format: :problem_details, status: payload.status
          end
        end
      end
    end
  end
end
