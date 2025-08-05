# frozen_string_literal: true

require "spec_helper"

RSpec.describe Opossum::UserDetails do
  let(:access_token) { "test_access_token" }
  let(:user_details) { described_class.new(access_token: access_token) }

  describe "#initialize" do
    it "sets the access token" do
      expect(user_details.send(:access_token)).to eq(access_token)
    end

    it "inherits from BaseClient" do
      expect(user_details).to be_a(Opossum::BaseClient)
    end
  end

  describe "#get_user_info" do
    let(:fields) { "id,username,media_count" }
    let(:expected_path) { "#{Opossum::BaseClient::INSTAGRAM_GRAPH_API_ENDPOINT}/#{Opossum::BaseClient::GRAPH_API_VERSION}/me" }
    let(:expected_params) do
      {
        access_token: access_token,
        fields: fields
      }
    end

    context "when API call is successful" do
      let(:api_response) do
        {
          id: "123456789",
          username: "test_user",
          media_count: 42
        }
      end

      before do
        allow(Opossum::ApiHelper).to receive(:get).with(
          path: expected_path,
          params: expected_params
        ).and_return(api_response)
      end

      it "calls ApiHelper.get with correct parameters" do
        user_details.get_user_info(fields: fields)

        expect(Opossum::ApiHelper).to have_received(:get).with(
          path: expected_path,
          params: expected_params
        )
      end

      it "returns the API response" do
        result = user_details.get_user_info(fields: fields)
        expect(result).to eq(api_response)
      end
    end

    context "when API call fails" do
      before do
        allow(Opossum::ApiHelper).to receive(:get).and_raise(
          Opossum::Error, "Instagram API Error: Invalid access token"
        )
      end

      it "raises Opossum::Error" do
        expect { user_details.get_user_info(fields: fields) }.to raise_error(
          Opossum::Error, "Instagram API Error: Invalid access token"
        )
      end
    end
  end

  describe "#get_long_lived_access_token" do
    let(:client_secret) { "test_client_secret" }
    let(:expected_path) { "#{Opossum::BaseClient::INSTAGRAM_GRAPH_API_ENDPOINT}/access_token" }
    let(:expected_params) do
      {
        access_token: access_token,
        client_secret: client_secret,
        grant_type: "ig_exchange_token"
      }
    end

    context "when API call is successful" do
      let(:api_response) do
        {
          access_token: "new_long_lived_token",
          token_type: "bearer",
          expires_in: 5_184_000
        }
      end

      before do
        allow(Opossum::ApiHelper).to receive(:get).with(
          path: expected_path,
          params: expected_params
        ).and_return(api_response)
      end

      it "calls ApiHelper.get with correct parameters" do
        user_details.get_long_lived_access_token(client_secret: client_secret)

        expect(Opossum::ApiHelper).to have_received(:get).with(
          path: expected_path,
          params: expected_params
        )
      end

      it "returns the API response" do
        result = user_details.get_long_lived_access_token(client_secret: client_secret)
        expect(result).to eq(api_response)
      end
    end

    context "when API call fails" do
      before do
        allow(Opossum::ApiHelper).to receive(:get).and_raise(
          Opossum::Error, "Instagram API Error: Invalid client secret"
        )
      end

      it "raises Opossum::Error" do
        expect { user_details.get_long_lived_access_token(client_secret: client_secret) }.to raise_error(
          Opossum::Error, "Instagram API Error: Invalid client secret"
        )
      end
    end
  end

  describe "#refresh_access_token" do
    let(:expected_path) { "#{Opossum::BaseClient::INSTAGRAM_GRAPH_API_ENDPOINT}/refresh_access_token" }
    let(:expected_params) do
      {
        access_token: access_token,
        grant_type: "ig_refresh_token"
      }
    end

    context "when API call is successful" do
      let(:api_response) do
        {
          access_token: "refreshed_access_token",
          token_type: "bearer",
          expires_in: 5_184_000
        }
      end

      before do
        allow(Opossum::ApiHelper).to receive(:get).with(
          path: expected_path,
          params: expected_params
        ).and_return(api_response)
      end

      it "calls ApiHelper.get with correct parameters" do
        user_details.refresh_access_token

        expect(Opossum::ApiHelper).to have_received(:get).with(
          path: expected_path,
          params: expected_params
        )
      end

      it "returns the API response" do
        result = user_details.refresh_access_token
        expect(result).to eq(api_response)
      end
    end

    context "when API call fails" do
      before do
        allow(Opossum::ApiHelper).to receive(:get).and_raise(
          Opossum::Error, "Instagram API Error: Token has expired"
        )
      end

      it "raises Opossum::Error" do
        expect { user_details.refresh_access_token }.to raise_error(
          Opossum::Error, "Instagram API Error: Token has expired"
        )
      end
    end
  end
end
