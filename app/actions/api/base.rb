# frozen_string_literal: true

require "petail"

require_relative "../../aspects/problem_detail"

module Terminus
  module Actions
    module API
      # The base action.
      class Base < Action
        config.formats.accept :json
        handle_exception Dry::Types::SchemaError => :detail_enum,
                         ROM::SQL::UniqueConstraintError => :detail_duplicate,
                         ROM::SQL::ForeignKeyConstraintError => :detail_foreign_key

        using Refines::Actions::Response

        def initialize(problem: Petail, problem_detail: Aspects::ProblemDetail, **)
          @problem = problem
          @problem_detail = problem_detail
          super(**)
        end

        protected

        attr_reader :problem

        def verify_csrf_token?(*) = false

        private

        attr_reader :problem_detail

        def detail_duplicate request, response, error
          payload = problem_detail.duplicate error.message, request.path
          response.with body: payload.to_json, format: :problem_details, status: payload.status
        end

        def detail_enum request, response, error
          payload = problem_detail.enum error.message, request.path
          response.with body: payload.to_json, format: :problem_details, status: payload.status
        end

        def detail_foreign_key request, response, error
          payload = problem_detail.foreign_key error.message, request.path
          response.with body: payload.to_json, format: :problem_details, status: payload.status
        end
      end
    end
  end
end
