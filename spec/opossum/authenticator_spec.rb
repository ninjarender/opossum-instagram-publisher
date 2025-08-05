# frozen_string_literal: true

require "spec_helper"

RSpec.describe Opossum::Authenticator do
  let(:client_id) { "test_client_id" }
  let(:client_secret) { "test_client_secret" }
  let(:redirect_uri) { "https://example.com/callback" }
  let(:authenticator) do
    described_class.new(
      client_id: client_id,
      client_secret: client_secret,
      redirect_uri: redirect_uri
    )
  end

  describe "#initialize" do
    it "sets the client_id, client_secret, and redirect_uri" do
      expect(authenticator.send(:client_id)).to eq(client_id)
      expect(authenticator.send(:client_secret)).to eq(client_secret)
      expect(authenticator.send(:redirect_uri)).to eq(redirect_uri)
    end
  end

  describe "#exchange_code_for_token" do
    let(:code) { "test_authorization_code" }
    let(:expected_path) { "#{Opossum::Authenticator::INSTAGRAM_TOKEN_ENDPOINT}/oauth/access_token" }
    let(:expected_body) do
      {
        client_id: client_id,
        client_secret: client_secret,
        grant_type: "authorization_code",
        redirect_uri: redirect_uri,
        code: code
      }
    end
    let(:expected_headers) { { "Content-Type" => "application/x-www-form-urlencoded" } }

    before do
      allow(Opossum::ApiHelper).to receive(:post)
    end

    it "calls ApiHelper.post with correct parameters" do
      authenticator.exchange_code_for_token(code)

      expect(Opossum::ApiHelper).to have_received(:post).with(
        path: expected_path,
        body: expected_body,
        headers: expected_headers
      )
    end

    it "returns the response from ApiHelper.post" do
      mock_response = { "access_token" => "token123", "user_id" => "12345" }
      allow(Opossum::ApiHelper).to receive(:post).and_return(mock_response)

      result = authenticator.exchange_code_for_token(code)

      expect(result).to eq(mock_response)
    end

    context "when ApiHelper raises an error" do
      let(:error_message) { "HTTP 400: Bad Request" }

      before do
        allow(Opossum::ApiHelper).to receive(:post).and_raise(Opossum::Error, error_message)
      end

      it "propagates the error" do
        expect { authenticator.exchange_code_for_token(code) }.to raise_error(Opossum::Error, error_message)
      end
    end
  end

  describe "private methods" do
    describe "#token_request_params" do
      let(:code) { "test_code" }
      let(:expected_params) do
        {
          client_id: client_id,
          client_secret: client_secret,
          grant_type: "authorization_code",
          redirect_uri: redirect_uri,
          code: code
        }
      end

      it "returns correct parameters hash" do
        result = authenticator.send(:token_request_params, code)
        expect(result).to eq(expected_params)
      end

      it "includes all required OAuth parameters" do
        result = authenticator.send(:token_request_params, code)

        expect(result).to have_key(:client_id)
        expect(result).to have_key(:client_secret)
        expect(result).to have_key(:grant_type)
        expect(result).to have_key(:redirect_uri)
        expect(result).to have_key(:code)
      end

      it "sets grant_type to authorization_code" do
        result = authenticator.send(:token_request_params, code)
        expect(result[:grant_type]).to eq("authorization_code")
      end
    end
  end

  describe "#get_user_info_from_code" do
    let(:code) { "test_authorization_code" }
    let(:short_lived_token) { "short_lived_token_123" }
    let(:long_lived_token) { "long_lived_token_456" }
    let(:access_token_response) { { "access_token" => short_lived_token, "user_id" => "12345" } }
    let(:user_details_client) { instance_double(Opossum::UserDetails) }

    before do
      allow(authenticator).to receive(:exchange_code_for_token).and_return(access_token_response)
      allow(Opossum::UserDetails).to receive(:new).and_return(user_details_client)
      allow(user_details_client).to receive(:get_long_lived_access_token).and_return(long_lived_token)
    end

    context "when fields parameter is not provided" do
      it "returns only the long-lived access token" do
        result = authenticator.get_user_info_from_code(code)

        expect(result).to eq({ access_token: long_lived_token })
      end

      it "exchanges code for token" do
        authenticator.get_user_info_from_code(code)

        expect(authenticator).to have_received(:exchange_code_for_token).with(code)
      end

      it "creates UserDetails client with short-lived token" do
        authenticator.get_user_info_from_code(code)

        expect(Opossum::UserDetails).to have_received(:new).with(access_token: short_lived_token)
      end

      it "gets long-lived access token" do
        authenticator.get_user_info_from_code(code)

        expect(user_details_client).to have_received(:get_long_lived_access_token).with(client_secret: client_secret)
      end

      it "does not call get_user_info" do
        allow(user_details_client).to receive(:get_user_info)

        authenticator.get_user_info_from_code(code)

        expect(user_details_client).not_to have_received(:get_user_info)
      end
    end

    context "when fields parameter is provided" do
      let(:fields) { "id,username,media_count" }
      let(:user_info) { { "id" => "12345", "username" => "testuser", "media_count" => 42 } }

      before do
        allow(user_details_client).to receive(:get_user_info).and_return(user_info)
      end

      it "returns both access token and user details" do
        result = authenticator.get_user_info_from_code(code, fields: fields)

        expect(result).to eq({
                               access_token: long_lived_token,
                               user_details: user_info
                             })
      end

      it "exchanges code for token" do
        authenticator.get_user_info_from_code(code, fields: fields)

        expect(authenticator).to have_received(:exchange_code_for_token).with(code)
      end

      it "creates UserDetails client with short-lived token" do
        authenticator.get_user_info_from_code(code, fields: fields)

        expect(Opossum::UserDetails).to have_received(:new).with(access_token: short_lived_token)
      end

      it "gets long-lived access token" do
        authenticator.get_user_info_from_code(code, fields: fields)

        expect(user_details_client).to have_received(:get_long_lived_access_token).with(client_secret: client_secret)
      end

      it "gets user info with specified fields" do
        authenticator.get_user_info_from_code(code, fields: fields)

        expect(user_details_client).to have_received(:get_user_info).with(fields: fields)
      end
    end

    context "when fields is an empty array" do
      let(:fields) { [] }

      it "returns only the long-lived access token" do
        result = authenticator.get_user_info_from_code(code, fields: fields)

        expect(result).to eq({ access_token: long_lived_token })
      end

      it "does not call get_user_info" do
        allow(user_details_client).to receive(:get_user_info)

        authenticator.get_user_info_from_code(code, fields: fields)

        expect(user_details_client).not_to have_received(:get_user_info)
      end
    end

    context "when exchange_code_for_token fails" do
      let(:error_message) { "Invalid authorization code" }

      before do
        allow(authenticator).to receive(:exchange_code_for_token).and_raise(Opossum::Error, error_message)
      end

      it "propagates the error" do
        expect { authenticator.get_user_info_from_code(code) }.to raise_error(Opossum::Error, error_message)
      end
    end

    context "when get_long_lived_access_token fails" do
      let(:error_message) { "Failed to get long-lived token" }

      before do
        allow(user_details_client).to receive(:get_long_lived_access_token).and_raise(Opossum::Error, error_message)
      end

      it "propagates the error" do
        expect { authenticator.get_user_info_from_code(code) }.to raise_error(Opossum::Error, error_message)
      end
    end

    context "when get_user_info fails" do
      let(:fields) { "id,username" }
      let(:error_message) { "Failed to get user info" }

      before do
        allow(user_details_client).to receive(:get_user_info).and_raise(Opossum::Error, error_message)
      end

      it "propagates the error" do
        expect do
          authenticator.get_user_info_from_code(code, fields: fields)
        end.to raise_error(Opossum::Error, error_message)
      end
    end
  end

  describe "constants" do
    it "defines INSTAGRAM_TOKEN_ENDPOINT" do
      expect(Opossum::Authenticator::INSTAGRAM_TOKEN_ENDPOINT).to eq("https://api.instagram.com")
    end
  end
end
