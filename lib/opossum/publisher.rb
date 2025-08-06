# frozen_string_literal: true

require_relative "api_helper"
require_relative "base_client"

module Opossum
  # Handles Instagram media publishing
  class Publisher < BaseClient
    def initialize(access_token:, ig_id:)
      super(access_token: access_token)

      @ig_id = ig_id
    end

    def publish_media(media_url:, media_type: "IMAGE", caption: nil)
      path = "#{INSTAGRAM_GRAPH_API_ENDPOINT}/#{GRAPH_API_VERSION}/#{ig_id}/media_publish"
      media_container_id = prepare_media_container(media_url: media_url, media_type: media_type, caption: caption)

      ApiHelper.post(
        path: path,
        body: { access_token: access_token, creation_id: media_container_id }
      )
    end

    private

    attr_reader :ig_id

    def prepare_media_container(media_url:, media_type:, caption:)
      if media_url.is_a?(Array)
        prepare_carousel_media(media_urls: media_url, media_type: media_type, caption: caption)
      else
        create_media_container(media_url: media_url, media_type: media_type, caption: caption)
      end
    end

    def prepare_carousel_media(media_urls:, media_type:, caption:)
      children_ids = media_urls.map do |url|
        create_media_container(media_url: url, is_carousel_item: true, caption: caption)
      end

      create_media_container(media_url: children_ids, media_type: media_type, caption: caption)
    end

    def create_media_container(media_url:, media_type: "IMAGE", is_carousel_item: false, upload_type: nil, caption: nil)
      path = "#{INSTAGRAM_GRAPH_API_ENDPOINT}/#{GRAPH_API_VERSION}/#{ig_id}/media"
      body = build_media_container_body(media_url: media_url, media_type: media_type, caption: caption,
                                        is_carousel_item: is_carousel_item, upload_type: upload_type)

      response = ApiHelper.post(path: path, body: body)
      media_container_id = response["id"]

      wait_for_media_container_status(media_container_id: media_container_id)
      media_container_id
    end

    def build_media_container_body(media_url:, media_type:, caption:, is_carousel_item:, upload_type:)
      body = { access_token: access_token, media_type: media_type, caption: caption }
      set_media_url_field(body, media_url, media_type)
      body[:is_carousel_item] = is_carousel_item if is_carousel_item
      body[:upload_type] = upload_type if upload_type
      body
    end

    def set_media_url_field(body, media_url, media_type)
      case media_type
      when "IMAGE"
        body[:image_url] = media_url
      when "VIDEO", "REELS", "STORIES"
        body[:video_url] = media_url
      when "CAROUSEL"
        body[:children] = media_url
      end
    end

    def wait_for_media_container_status(media_container_id:)
      loop do
        status = check_media_container_status(media_container_id: media_container_id)["status"]
        break if handle_media_container_status(status)
      end
    end

    def handle_media_container_status(status)
      case status
      when "FINISHED" then true
      when "IN_PROGRESS"
        sleep 30
        false
      when "EXPIRED", "ERROR", "PUBLISHED" then raise_status_error(status)
      else raise "Unknown media container status: #{status}"
      end
    end

    def raise_status_error(status)
      messages = {
        "EXPIRED" => "Media container has expired. The container was not published within 24 hours.",
        "ERROR" => "Media container failed to complete the publishing process.",
        "PUBLISHED" => "Media container has already been published."
      }
      raise messages[status]
    end

    def check_media_container_status(media_container_id:)
      path = "#{INSTAGRAM_GRAPH_API_ENDPOINT}/#{GRAPH_API_VERSION}/#{media_container_id}?fields=status_code"

      ApiHelper.get(
        path: path,
        params: { access_token: access_token }
      )
    end
  end
end
