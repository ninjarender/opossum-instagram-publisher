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

  describe "constants" do
    it "defines INSTAGRAM_TOKEN_ENDPOINT" do
      expect(Opossum::Authenticator::INSTAGRAM_TOKEN_ENDPOINT).to eq("https://api.instagram.com")
    end
  end
end
