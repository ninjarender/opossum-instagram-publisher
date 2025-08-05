# frozen_string_literal: true

require "spec_helper"

RSpec.describe Opossum::Publisher do
  let(:access_token) { "test_access_token" }
  let(:publisher) { described_class.new(access_token: access_token) }
  let(:ig_id) { "instagram_user_id_123" }
  let(:media_url) { "https://example.com/image.jpg" }
  let(:media_container_id) { "media_container_123" }

  describe "#initialize" do
    it "inherits from BaseClient and sets access_token" do
      expect(publisher).to be_a(Opossum::BaseClient)
      expect(publisher.send(:access_token)).to eq(access_token)
    end
  end

  describe "#publish_media" do
    let(:expected_path) { "#{Opossum::BaseClient::INSTAGRAM_GRAPH_API_ENDPOINT}/#{Opossum::BaseClient::GRAPH_API_VERSION}/#{ig_id}/media_publish" }
    let(:expected_body) { { access_token: access_token, creation_id: media_container_id } }

    before do
      allow(publisher).to receive(:prepare_media_container).and_return(media_container_id)
      allow(Opossum::ApiHelper).to receive(:post)
    end

    it "calls prepare_media_container with correct parameters" do
      publisher.publish_media(ig_id: ig_id, media_url: media_url)

      expect(publisher).to have_received(:prepare_media_container).with(
        ig_id: ig_id,
        media_url: media_url,
        media_type: "IMAGE",
        caption: nil
      )
    end

    it "calls ApiHelper.post with correct parameters" do
      publisher.publish_media(ig_id: ig_id, media_url: media_url)

      expect(Opossum::ApiHelper).to have_received(:post).with(
        path: expected_path,
        body: expected_body
      )
    end

    it "accepts custom media_type and caption" do
      custom_caption = "Test caption"
      custom_media_type = "VIDEO"

      publisher.publish_media(
        ig_id: ig_id,
        media_url: media_url,
        media_type: custom_media_type,
        caption: custom_caption
      )

      expect(publisher).to have_received(:prepare_media_container).with(
        ig_id: ig_id,
        media_url: media_url,
        media_type: custom_media_type,
        caption: custom_caption
      )
    end

    it "returns the response from ApiHelper.post" do
      mock_response = { "id" => "published_media_123" }
      allow(Opossum::ApiHelper).to receive(:post).and_return(mock_response)

      result = publisher.publish_media(ig_id: ig_id, media_url: media_url)

      expect(result).to eq(mock_response)
    end
  end

  describe "private methods" do
    describe "#prepare_media_container" do
      context "when media_url is a single URL" do
        it "calls create_media_container once" do
          allow(publisher).to receive(:create_media_container).and_return(media_container_id)

          result = publisher.send(:prepare_media_container,
                                  ig_id: ig_id,
                                  media_url: media_url,
                                  media_type: "IMAGE",
                                  caption: nil)

          expect(publisher).to have_received(:create_media_container).once.with(
            ig_id: ig_id,
            media_url: media_url,
            media_type: "IMAGE",
            caption: nil
          )
          expect(result).to eq(media_container_id)
        end
      end

      context "when media_url is an array (carousel)" do
        let(:media_urls) { ["https://example.com/image1.jpg", "https://example.com/image2.jpg"] }
        let(:child_id_1) { "child_container_1" }
        let(:child_id_2) { "child_container_2" }
        let(:carousel_container_id) { "carousel_container_123" }

        before do
          allow(publisher).to receive(:create_media_container).and_return(child_id_1, child_id_2, carousel_container_id)
        end

        it "creates containers for each child and then a carousel container" do
          result = publisher.send(:prepare_media_container,
                                  ig_id: ig_id,
                                  media_url: media_urls,
                                  media_type: "CAROUSEL",
                                  caption: "Carousel caption")

          # Should create child containers
          expect(publisher).to have_received(:create_media_container).with(
            ig_id: ig_id,
            media_url: media_urls[0],
            is_carousel_item: true,
            caption: "Carousel caption"
          )
          expect(publisher).to have_received(:create_media_container).with(
            ig_id: ig_id,
            media_url: media_urls[1],
            is_carousel_item: true,
            caption: "Carousel caption"
          )

          # Should create carousel container with child IDs
          expect(publisher).to have_received(:create_media_container).with(
            ig_id: ig_id,
            media_url: [child_id_1, child_id_2],
            media_type: "CAROUSEL",
            caption: "Carousel caption"
          )

          expect(result).to eq(carousel_container_id)
        end
      end
    end

    describe "#create_media_container" do
      let(:expected_path) { "#{Opossum::BaseClient::INSTAGRAM_GRAPH_API_ENDPOINT}/#{Opossum::BaseClient::GRAPH_API_VERSION}/#{ig_id}/media" }
      let(:api_response) { { "id" => media_container_id } }

      before do
        allow(Opossum::ApiHelper).to receive(:post).and_return(api_response)
        allow(publisher).to receive(:wait_for_media_container_status)
      end

      context "for IMAGE media type" do
        let(:expected_body) do
          {
            access_token: access_token,
            media_type: "IMAGE",
            caption: nil,
            image_url: media_url
          }
        end

        it "sends correct request for image" do
          result = publisher.send(:create_media_container,
                                  ig_id: ig_id,
                                  media_url: media_url,
                                  media_type: "IMAGE")

          expect(Opossum::ApiHelper).to have_received(:post).with(
            path: expected_path,
            body: expected_body
          )
          expect(result).to eq(media_container_id)
        end
      end

      context "for VIDEO media type" do
        let(:video_url) { "https://example.com/video.mp4" }
        let(:expected_body) do
          {
            access_token: access_token,
            media_type: "VIDEO",
            caption: "Video caption",
            video_url: video_url
          }
        end

        it "sends correct request for video" do
          publisher.send(:create_media_container,
                         ig_id: ig_id,
                         media_url: video_url,
                         media_type: "VIDEO",
                         caption: "Video caption")

          expect(Opossum::ApiHelper).to have_received(:post).with(
            path: expected_path,
            body: expected_body
          )
        end
      end

      context "for REELS media type" do
        let(:reels_url) { "https://example.com/reels.mp4" }
        let(:expected_body) do
          {
            access_token: access_token,
            media_type: "REELS",
            caption: nil,
            video_url: reels_url
          }
        end

        it "sends correct request for reels" do
          publisher.send(:create_media_container,
                         ig_id: ig_id,
                         media_url: reels_url,
                         media_type: "REELS")

          expect(Opossum::ApiHelper).to have_received(:post).with(
            path: expected_path,
            body: expected_body
          )
        end
      end

      context "for STORIES media type" do
        let(:story_url) { "https://example.com/story.mp4" }
        let(:expected_body) do
          {
            access_token: access_token,
            media_type: "STORIES",
            caption: nil,
            video_url: story_url
          }
        end

        it "sends correct request for stories" do
          publisher.send(:create_media_container,
                         ig_id: ig_id,
                         media_url: story_url,
                         media_type: "STORIES")

          expect(Opossum::ApiHelper).to have_received(:post).with(
            path: expected_path,
            body: expected_body
          )
        end
      end

      context "for CAROUSEL media type" do
        let(:children_ids) { %w[child1 child2] }
        let(:expected_body) do
          {
            access_token: access_token,
            media_type: "CAROUSEL",
            caption: "Carousel caption",
            children: children_ids
          }
        end

        it "sends correct request for carousel" do
          publisher.send(:create_media_container,
                         ig_id: ig_id,
                         media_url: children_ids,
                         media_type: "CAROUSEL",
                         caption: "Carousel caption")

          expect(Opossum::ApiHelper).to have_received(:post).with(
            path: expected_path,
            body: expected_body
          )
        end
      end

      context "with optional parameters" do
        let(:expected_body) do
          {
            access_token: access_token,
            media_type: "IMAGE",
            caption: "Test caption",
            image_url: media_url,
            is_carousel_item: true,
            upload_type: "resumable"
          }
        end

        it "includes optional parameters when provided" do
          publisher.send(:create_media_container,
                         ig_id: ig_id,
                         media_url: media_url,
                         media_type: "IMAGE",
                         is_carousel_item: true,
                         upload_type: "resumable",
                         caption: "Test caption")

          expect(Opossum::ApiHelper).to have_received(:post).with(
            path: expected_path,
            body: expected_body
          )
        end

        it "excludes optional parameters when not provided" do
          expected_body_minimal = {
            access_token: access_token,
            media_type: "IMAGE",
            caption: nil,
            image_url: media_url
          }

          publisher.send(:create_media_container,
                         ig_id: ig_id,
                         media_url: media_url,
                         media_type: "IMAGE")

          expect(Opossum::ApiHelper).to have_received(:post).with(
            path: expected_path,
            body: expected_body_minimal
          )
        end
      end

      it "waits for media container status and returns container id" do
        result = publisher.send(:create_media_container,
                                ig_id: ig_id,
                                media_url: media_url)

        expect(publisher).to have_received(:wait_for_media_container_status).with(
          media_container_id: media_container_id
        )
        expect(result).to eq(media_container_id)
      end
    end

    describe "#wait_for_media_container_status" do
      before do
        allow(publisher).to receive(:check_media_container_status)
        allow(publisher).to receive(:sleep)
      end

      context "when status is FINISHED" do
        it "breaks the loop immediately" do
          allow(publisher).to receive(:check_media_container_status)
            .and_return({ "status" => "FINISHED" })

          expect { publisher.send(:wait_for_media_container_status, media_container_id: media_container_id) }
            .not_to raise_error

          expect(publisher).to have_received(:check_media_container_status).once
        end
      end

      context "when status is IN_PROGRESS then FINISHED" do
        it "waits and checks again" do
          allow(publisher).to receive(:check_media_container_status)
            .and_return(
              { "status" => "IN_PROGRESS" },
              { "status" => "FINISHED" }
            )

          publisher.send(:wait_for_media_container_status, media_container_id: media_container_id)

          expect(publisher).to have_received(:check_media_container_status).twice
          expect(publisher).to have_received(:sleep).once.with(30)
        end
      end

      context "when status is EXPIRED" do
        it "raises an error" do
          allow(publisher).to receive(:check_media_container_status)
            .and_return({ "status" => "EXPIRED" })

          expect do
            publisher.send(:wait_for_media_container_status, media_container_id: media_container_id)
          end.to raise_error("Media container has expired. The container was not published within 24 hours.")
        end
      end

      context "when status is ERROR" do
        it "raises an error" do
          allow(publisher).to receive(:check_media_container_status)
            .and_return({ "status" => "ERROR" })

          expect do
            publisher.send(:wait_for_media_container_status, media_container_id: media_container_id)
          end.to raise_error("Media container failed to complete the publishing process.")
        end
      end

      context "when status is PUBLISHED" do
        it "raises an error" do
          allow(publisher).to receive(:check_media_container_status)
            .and_return({ "status" => "PUBLISHED" })

          expect do
            publisher.send(:wait_for_media_container_status, media_container_id: media_container_id)
          end.to raise_error("Media container has already been published.")
        end
      end

      context "when status is unknown" do
        it "raises an error with the unknown status" do
          unknown_status = "UNKNOWN_STATUS"
          allow(publisher).to receive(:check_media_container_status)
            .and_return({ "status" => unknown_status })

          expect do
            publisher.send(:wait_for_media_container_status, media_container_id: media_container_id)
          end.to raise_error("Unknown media container status: #{unknown_status}")
        end
      end
    end

    describe "#check_media_container_status" do
      let(:expected_path) { "#{Opossum::BaseClient::INSTAGRAM_GRAPH_API_ENDPOINT}/#{Opossum::BaseClient::GRAPH_API_VERSION}/#{media_container_id}?fields=status_code" }
      let(:expected_params) { { access_token: access_token } }

      before do
        allow(Opossum::ApiHelper).to receive(:get)
      end

      it "calls ApiHelper.get with correct parameters" do
        publisher.send(:check_media_container_status, media_container_id: media_container_id)

        expect(Opossum::ApiHelper).to have_received(:get).with(
          path: expected_path,
          params: expected_params
        )
      end

      it "returns the response from ApiHelper.get" do
        mock_response = { "status" => "IN_PROGRESS", "status_code" => "IN_PROGRESS" }
        allow(Opossum::ApiHelper).to receive(:get).and_return(mock_response)

        result = publisher.send(:check_media_container_status, media_container_id: media_container_id)

        expect(result).to eq(mock_response)
      end
    end
  end

  describe "error handling" do
    before do
      allow(publisher).to receive(:prepare_media_container).and_return(media_container_id)
    end

    context "when ApiHelper raises an error during publish_media" do
      let(:error_message) { "HTTP 400: Bad Request" }

      before do
        allow(Opossum::ApiHelper).to receive(:post).and_raise(Opossum::Error, error_message)
      end

      it "propagates the error" do
        expect do
          publisher.publish_media(ig_id: ig_id, media_url: media_url)
        end.to raise_error(Opossum::Error, error_message)
      end
    end

    context "when ApiHelper raises an error during create_media_container" do
      let(:error_message) { "HTTP 500: Internal Server Error" }

      before do
        allow(Opossum::ApiHelper).to receive(:post).and_raise(Opossum::Error, error_message)
        allow(publisher).to receive(:prepare_media_container).and_call_original
      end

      it "propagates the error" do
        expect do
          publisher.send(:create_media_container, ig_id: ig_id, media_url: media_url)
        end.to raise_error(Opossum::Error, error_message)
      end
    end
  end

  describe "constants inheritance" do
    it "has access to INSTAGRAM_GRAPH_API_ENDPOINT from BaseClient" do
      expect(Opossum::Publisher::INSTAGRAM_GRAPH_API_ENDPOINT).to eq("https://graph.instagram.com")
    end

    it "has access to GRAPH_API_VERSION from BaseClient" do
      expect(Opossum::Publisher::GRAPH_API_VERSION).to eq("v23.0")
    end
  end
end
