# frozen_string_literal: true

require "faraday"
require "json"

module Opossum
  # Helper for handling API requests and responses
  class ApiHelper
    def self.get(path:, params: {}, headers: {})
      response = Faraday.get(path) do |req|
        req.headers.merge!(default_headers.merge(headers))
        req.params = params
      end

      handle_response(response)
    end

    def self.post(path:, body: {}, headers: {})
      response = Faraday.post(path) do |req|
        req.headers.merge!(default_headers.merge(headers))
        req.body = if headers["Content-Type"] == "application/x-www-form-urlencoded"
                     URI.encode_www_form(body)
                   else
                     body.to_json
                   end
      end

      handle_response(response)
    end

    class << self
      private

      def default_headers
        { "Content-Type" => "application/json" }
      end

      def handle_response(response)
        raise Opossum::Error, "HTTP #{response.status}: #{response.body}" unless response.success?

        parsed_response = parse_json(response.body)
        check_api_errors(parsed_response)
        parsed_response
      rescue Faraday::Error => e
        raise Opossum::Error, "HTTP Error: #{e.message}"
      end

      def parse_json(body)
        JSON.parse(body)
      rescue JSON::ParserError => e
        raise Opossum::Error, "JSON Parse Error: #{e.message}"
      end

      def check_api_errors(parsed_response)
        return unless parsed_response["error"]

        error_message = "Instagram API Error: #{parsed_response["error"]}"
        error_message += " - #{parsed_response["error_description"]}" if parsed_response["error_description"]
        raise Opossum::Error, error_message
      end
    end
  end
end
