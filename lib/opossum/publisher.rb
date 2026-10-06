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

    # media_format applies to STORIES only: "IMAGE" sends the url as image_url,
    # "VIDEO" (the default) as video_url. Other media types ignore it.
    def publish_media(media_url:, media_type: "IMAGE", caption: nil, media_format: nil)
      path = "#{INSTAGRAM_GRAPH_API_ENDPOINT}/#{GRAPH_API_VERSION}/#{ig_id}/media_publish"
      media_container_id = prepare_media_container(media_url: media_url, media_type: media_type, caption: caption,
                                                   media_format: media_format)

      ApiHelper.post(
        path: path,
        body: { access_token: access_token, creation_id: media_container_id }
      )
    end

    private

    attr_reader :ig_id

    def prepare_media_container(media_url:, media_type:, caption:, media_format: nil)
      if media_url.is_a?(Array)
        prepare_carousel_media(media_urls: media_url, media_type: media_type, caption: caption)
      else
        create_media_container(media_url: media_url, media_type: media_type, caption: caption,
                               media_format: media_format)
      end
    end

    def prepare_carousel_media(media_urls:, media_type:, caption:)
      threads = media_urls.map do |url|
        Thread.new do
          create_media_container(media_url: url, is_carousel_item: true, caption: caption)
        end
      end

      children_ids = threads.map(&:value)

      create_media_container(media_url: children_ids, media_type: media_type, caption: caption)
    end

    # options: is_carousel_item:, upload_type:, media_format:
    def create_media_container(media_url:, media_type: "IMAGE", caption: nil, **options)
      path = "#{INSTAGRAM_GRAPH_API_ENDPOINT}/#{GRAPH_API_VERSION}/#{ig_id}/media"
      body = build_media_container_body(media_url: media_url, media_type: media_type, caption: caption, **options)

      response = ApiHelper.post(path: path, body: body)
      media_container_id = response["id"]

      wait_for_media_container_status(media_container_id: media_container_id)
      media_container_id
    end

    def build_media_container_body(media_url:, media_type:, caption:, **options)
      body = { access_token: access_token, media_type: media_type, caption: caption }
      set_media_url_field(body, media_url, media_type, options[:media_format])
      body[:is_carousel_item] = options[:is_carousel_item] if options[:is_carousel_item]
      body[:upload_type] = options[:upload_type] if options[:upload_type]
      body
    end

    def set_media_url_field(body, media_url, media_type, media_format = nil)
      case media_type
      when "IMAGE"
        body[:image_url] = media_url
      when "VIDEO", "REELS"
        body[:video_url] = media_url
      when "STORIES"
        body[media_format.to_s.upcase == "IMAGE" ? :image_url : :video_url] = media_url
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
