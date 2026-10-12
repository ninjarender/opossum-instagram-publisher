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
    #
    # alt_text is sent only for image containers (Instagram ignores it on
    # videos, reels and stories): a String for a single image, or an Array
    # parallel to media_url for a carousel (nil entries are skipped).
    def publish_media(media_url:, media_type: "IMAGE", caption: nil, media_format: nil, alt_text: nil)
      path = "#{INSTAGRAM_GRAPH_API_ENDPOINT}/#{GRAPH_API_VERSION}/#{ig_id}/media_publish"
      media_container_id = prepare_media_container(media_url: media_url, media_type: media_type, caption: caption,
                                                   media_format: media_format, alt_text: alt_text)

      ApiHelper.post(
        path: path,
        body: { access_token: access_token, creation_id: media_container_id }
      )
    end

    private

    attr_reader :ig_id

    def prepare_media_container(media_url:, media_type:, caption:, media_format: nil, alt_text: nil)
      if media_url.is_a?(Array)
        prepare_carousel_media(media_urls: media_url, media_type: media_type, caption: caption,
                               alt_texts: Array(alt_text))
      else
        create_media_container(media_url: media_url, media_type: media_type, caption: caption,
                               media_format: media_format, alt_text: alt_text)
      end
    end

    def prepare_carousel_media(media_urls:, media_type:, caption:, alt_texts: [])
      threads = media_urls.each_with_index.map do |url, index|
        Thread.new do
          create_media_container(media_url: url, is_carousel_item: true, caption: caption, alt_text: alt_texts[index])
        end
      end

      children_ids = threads.map(&:value)

      create_media_container(media_url: children_ids, media_type: media_type, caption: caption)
    end

    # options: is_carousel_item:, upload_type:, media_format:, alt_text:
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
      body[:alt_text] = options[:alt_text] if alt_text_applicable?(media_type, options[:alt_text])
      body
    end

    def alt_text_applicable?(media_type, alt_text)
      media_type == "IMAGE" && !alt_text.nil? && !alt_text.to_s.strip.empty?
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
