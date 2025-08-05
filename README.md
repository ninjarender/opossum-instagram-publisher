# OpossumInstagramPublisher

A Ruby gem for publishing media to Instagram using Instagram Basic Display API and Instagram Graph API. This gem provides a simple interface to authenticate users via Instagram Login and publish images, videos, and carousel posts to their Instagram accounts.

## Prerequisites

Before using this gem, you need to:

1. Create a Facebook App and configure Instagram Basic Display API
2. Set up Instagram Basic Display API permissions
3. Configure OAuth redirect URIs in your Facebook App settings
4. Obtain your Instagram Business Account ID

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'opossum'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install oposum
```

## Usage

This gem provides three independent classes for working with Instagram API:

### Authentication

```ruby
require 'opossum'

# Create authenticator
authenticator = Opossum::Authenticator.new(
  client_id: 'your_instagram_app_id',
  client_secret: 'your_instagram_app_secret',
  redirect_uri: 'your_redirect_uri'
)

# Get user info and long-lived token from authorization code
result = authenticator.get_user_info_from_code(
  authorization_code,
  fields: 'id,user_id'
)
# Returns: 
# { 
#   access_token: {
#     access_token: "ACCESS_TOKEN",
#     token_type: "TOKEN_TYPE",
#     expires_in: 5183742
#   },
#   user_details: {
#     id: "IG_ID",
#     user_id: "IG_USER_ID"
#   }
# }

# Or get only long-lived token without user details
result = authenticator.get_user_info_from_code(authorization_code)
# Returns:
# { 
#   access_token: {
#     access_token: "ACCESS_TOKEN",
#     token_type: "TOKEN_TYPE",
#     expires_in: 5183742
#   }
# }
```

### User Details (Optional)

```ruby
# If you need to refresh an existing access token
user_details = Opossum::UserDetails.new(
  access_token: existing_access_token
)

# Refresh access token (extends for another 60 days)
refreshed_token = user_details.refresh_access_token
```

### Publishing

```ruby
# Create publisher with access token
publisher = Opossum::Publisher.new(
  access_token: access_token
)

# Publish single image
result = publisher.publish_media(
  ig_id: instagram_business_account_id,
  media_url: 'https://example.com/image.jpg',
  media_type: 'IMAGE'
)

# Publish image with caption
result = publisher.publish_media(
  ig_id: instagram_business_account_id,
  media_url: 'https://example.com/image.jpg',
  media_type: 'IMAGE',
  caption: 'Beautiful sunset! 🌅 #nature #photography'
)

# Publish carousel with caption
result = publisher.publish_media(
  ig_id: instagram_business_account_id,
  media_url: [
    'https://example.com/image1.jpg',
    'https://example.com/image2.jpg'
  ],
  media_type: 'CAROUSEL',
  caption: 'Photo collection from my trip ✈️ #travel #memories'
)

# That's it! publish_media handles everything automatically:
# - Creates media container(s)
# - Waits for processing to complete  
# - Publishes the media
```



## Error Handling

The gem includes comprehensive error handling for API responses:

```ruby
begin
  result = client.publish_media(
    ig_id: instagram_business_account_id,
    access_token: access_token,
    media_url: 'https://example.com/image.jpg'
  )
rescue Opossum::Error => e
  puts "Error: #{e.message}"
end
```

## Supported Media Types

- **IMAGE** - Single images (JPEG, PNG) with optional caption
- **VIDEO** - Single videos (MP4, MOV) with optional caption
- **REELS** - Instagram Reels with optional caption
- **STORIES** - Instagram Stories with optional caption
- **CAROUSEL** - Multiple images in a single post with optional caption (automatically handled when passing an array of URLs)

**Features:**
- **Captions** - Add text descriptions, hashtags, and mentions to your posts
- **Token Management** - Get long-lived tokens and refresh existing tokens

**Note:** Currently, carousel posts support only images. Support for mixed media types (images + videos) in carousels will be added in future versions.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ninjarender/opossum. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/opossum/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the OpossumInstagramPublisher project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/ninjarender/opossum/blob/main/CODE_OF_CONDUCT.md).
