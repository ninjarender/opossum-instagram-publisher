# frozen_string_literal: true

require_relative "api_helper"
require_relative "user_details"

module Opossum
  # Handles Instagram authentication flow
  class Authenticator
    INSTAGRAM_TOKEN_ENDPOINT = "https://api.instagram.com"

    def initialize(client_id:, client_secret:, redirect_uri:)
      @client_id = client_id
      @client_secret = client_secret
      @redirect_uri = redirect_uri
    end

    def exchange_code_for_token(code)
      path = "#{INSTAGRAM_TOKEN_ENDPOINT}/oauth/access_token"

      ApiHelper.post(
        path: path,
        body: token_request_params(code),
        headers: { "Content-Type" => "application/x-www-form-urlencoded" }
      )
    end

    def get_user_info_from_code(code, fields: "")
      access_token = exchange_code_for_token(code)

      user_details_client = UserDetails.new(access_token: access_token["access_token"])
      long_lived_access_token = user_details_client.get_long_lived_access_token(client_secret: client_secret)

      return { access_token: long_lived_access_token } if !fields.is_a?(String) || fields.empty?

      user_details = user_details_client.get_user_info(fields: fields)

      {
        access_token: long_lived_access_token,
        user_details: user_details
      }
    end

    private

    attr_reader :client_id, :client_secret, :redirect_uri

    def token_request_params(code)
      {
        client_id: client_id,
        client_secret: client_secret,
        grant_type: "authorization_code",
        redirect_uri: redirect_uri,
        code: code
      }
    end
  end
end
