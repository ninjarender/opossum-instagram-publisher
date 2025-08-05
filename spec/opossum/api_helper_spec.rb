# frozen_string_literal: true

require "spec_helper"

RSpec.describe Opossum::ApiHelper do
  let(:mock_response) { instance_double(Faraday::Response) }
  let(:success_response_body) { '{"status": "success", "data": "test"}' }
  let(:error_response_body) { '{"error": "invalid_request", "error_description": "The request is invalid"}' }

  before do
    allow(Faraday).to receive(:get).and_return(mock_response)
    allow(Faraday).to receive(:post).and_return(mock_response)
  end

  describe ".get" do
    let(:path) { "https://api.example.com/test" }
    let(:params) { { param1: "value1", param2: "value2" } }
    let(:headers) { { "Authorization" => "Bearer token" } }

    context "when request is successful" do
      before do
        allow(mock_response).to receive(:success?).and_return(true)
        allow(mock_response).to receive(:body).and_return(success_response_body)
      end

      it "makes a GET request with correct parameters" do
        expect(Faraday).to receive(:get).with(path) do |&block|
          req = instance_double(Faraday::Request)
          headers_hash = {}
          allow(req).to receive(:headers).and_return(headers_hash)
          expect(headers_hash).to receive(:merge!).with({
                                                          "Content-Type" => "application/json",
                                                          "Authorization" => "Bearer token"
                                                        })
          expect(req).to receive(:params=).with(params)
          block.call(req)
        end.and_return(mock_response)

        described_class.get(path: path, params: params, headers: headers)
      end

      it "returns parsed JSON response" do
        result = described_class.get(path: path)
        expect(result).to eq({ "status" => "success", "data" => "test" })
      end

      it "works with default parameters" do
        result = described_class.get(path: path)
        expect(result).to eq({ "status" => "success", "data" => "test" })
      end
    end

    context "when HTTP request fails" do
      before do
        allow(mock_response).to receive(:success?).and_return(false)
        allow(mock_response).to receive(:status).and_return(404)
        allow(mock_response).to receive(:body).and_return("Not Found")
      end

      it "raises Opossum::Error with HTTP status and body" do
        expect do
          described_class.get(path: path)
        end.to raise_error(Opossum::Error, "HTTP 404: Not Found")
      end
    end

    context "when Faraday raises an error" do
      it "raises the original Faraday::Error" do
        allow(Faraday).to receive(:get).and_raise(Faraday::Error.new("Connection failed"))

        expect do
          described_class.get(path: path)
        end.to raise_error(Faraday::Error, "Connection failed")
      end
    end

    context "when response contains invalid JSON" do
      before do
        allow(mock_response).to receive(:success?).and_return(true)
        allow(mock_response).to receive(:body).and_return("invalid json")
      end

      it "raises Opossum::Error with JSON Parse Error message" do
        expect do
          described_class.get(path: path)
        end.to raise_error(Opossum::Error, /JSON Parse Error/)
      end
    end

    context "when API returns an error" do
      before do
        allow(mock_response).to receive(:success?).and_return(true)
        allow(mock_response).to receive(:body).and_return(error_response_body)
      end

      it "raises Opossum::Error with API error message" do
        expect do
          described_class.get(path: path)
        end.to raise_error(Opossum::Error, "Instagram API Error: invalid_request - The request is invalid")
      end
    end

    context "when API returns error without description" do
      let(:simple_error_body) { '{"error": "access_denied"}' }

      before do
        allow(mock_response).to receive(:success?).and_return(true)
        allow(mock_response).to receive(:body).and_return(simple_error_body)
      end

      it "raises Opossum::Error with simple error message" do
        expect do
          described_class.get(path: path)
        end.to raise_error(Opossum::Error, "Instagram API Error: access_denied")
      end
    end

    context "when handle_response encounters Faraday error" do
      it "raises Opossum::Error with HTTP Error message" do
        # Mock a successful response that causes Faraday error during processing
        allow(mock_response).to receive(:success?).and_raise(Faraday::Error.new("Processing failed"))

        expect do
          described_class.send(:handle_response, mock_response)
        end.to raise_error(Opossum::Error, "HTTP Error: Processing failed")
      end
    end
  end

  describe ".post" do
    let(:path) { "https://api.example.com/test" }
    let(:body) { { key1: "value1", key2: "value2" } }
    let(:headers) { { "Authorization" => "Bearer token" } }

    context "when request is successful" do
      before do
        allow(mock_response).to receive(:success?).and_return(true)
        allow(mock_response).to receive(:body).and_return(success_response_body)
      end

      it "makes a POST request with JSON body by default" do
        expect(Faraday).to receive(:post).with(path) do |&block|
          req = instance_double(Faraday::Request)
          headers_hash = {}
          allow(req).to receive(:headers).and_return(headers_hash)
          expect(headers_hash).to receive(:merge!).with({
                                                          "Content-Type" => "application/json",
                                                          "Authorization" => "Bearer token"
                                                        })
          expect(req).to receive(:body=).with(body.to_json)
          block.call(req)
        end.and_return(mock_response)

        described_class.post(path: path, body: body, headers: headers)
      end

      it "makes a POST request with form-encoded body when specified" do
        form_headers = { "Content-Type" => "application/x-www-form-urlencoded" }

        expect(Faraday).to receive(:post).with(path) do |&block|
          req = instance_double(Faraday::Request)
          headers_hash = {}
          allow(req).to receive(:headers).and_return(headers_hash)
          expect(headers_hash).to receive(:merge!).with(form_headers)
          expect(req).to receive(:body=).with(URI.encode_www_form(body))
          block.call(req)
        end.and_return(mock_response)

        described_class.post(path: path, body: body, headers: form_headers)
      end

      it "returns parsed JSON response" do
        result = described_class.post(path: path, body: body)
        expect(result).to eq({ "status" => "success", "data" => "test" })
      end

      it "works with default parameters" do
        result = described_class.post(path: path)
        expect(result).to eq({ "status" => "success", "data" => "test" })
      end
    end

    context "when HTTP request fails" do
      before do
        allow(mock_response).to receive(:success?).and_return(false)
        allow(mock_response).to receive(:status).and_return(500)
        allow(mock_response).to receive(:body).and_return("Internal Server Error")
      end

      it "raises Opossum::Error with HTTP status and body" do
        expect do
          described_class.post(path: path, body: body)
        end.to raise_error(Opossum::Error, "HTTP 500: Internal Server Error")
      end
    end

    context "when Faraday raises an error" do
      it "raises the original Faraday::Error" do
        allow(Faraday).to receive(:post).and_raise(Faraday::Error.new("Timeout"))

        expect do
          described_class.post(path: path, body: body)
        end.to raise_error(Faraday::Error, "Timeout")
      end
    end
  end

  describe "private methods" do
    describe ".default_headers" do
      it "returns correct default headers" do
        expect(described_class.send(:default_headers)).to eq({
                                                               "Content-Type" => "application/json"
                                                             })
      end
    end

    describe ".parse_json" do
      it "parses valid JSON" do
        result = described_class.send(:parse_json, '{"test": "value"}')
        expect(result).to eq({ "test" => "value" })
      end

      it "raises Opossum::Error for invalid JSON" do
        expect do
          described_class.send(:parse_json, "invalid json")
        end.to raise_error(Opossum::Error, /JSON Parse Error/)
      end
    end

    describe ".check_api_errors" do
      it "does nothing when no error present" do
        expect do
          described_class.send(:check_api_errors, { "status" => "success" })
        end.not_to raise_error
      end

      it "raises error when error present with description" do
        parsed_response = {
          "error" => "invalid_request",
          "error_description" => "The request is invalid"
        }

        expect do
          described_class.send(:check_api_errors, parsed_response)
        end.to raise_error(Opossum::Error, "Instagram API Error: invalid_request - The request is invalid")
      end

      it "raises error when error present without description" do
        parsed_response = { "error" => "access_denied" }

        expect do
          described_class.send(:check_api_errors, parsed_response)
        end.to raise_error(Opossum::Error, "Instagram API Error: access_denied")
      end
    end
  end
end
