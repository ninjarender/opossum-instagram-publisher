## [0.3.0] - 2025-08-12

### Improved
- **Publisher Performance** - Enhanced carousel media processing with parallel execution
  - `prepare_carousel_media` now uses Thread-based parallel processing for media container creation
  - Significantly improved upload speed for carousels with multiple media items
  - Each media URL in carousel is processed concurrently instead of sequentially
- **Error Handling** - Enhanced Error class with additional error context
  - Added `code` and `subcode` attributes to Error class for better error identification
  - Improved error initialization with optional code and subcode parameters

## [0.2.1] - 2025-08-07

### Improved
- **Instagram API Response Handling** - Enhanced error handling and response processing
  - Improved JSON parsing with better error messages when API returns invalid JSON
  - Added specific Instagram API error detection and messaging via `error_message` field
  - Enhanced HTTP error handling with more descriptive error messages
  - Better separation of concerns in ApiHelper with dedicated private methods for response processing
  - More robust error handling chain: HTTP errors → JSON parsing errors → Instagram API errors

## [0.2.0] - 2025-08-06

### Changed
- **Publisher class initialization** - Improved API design for better usability
  - Constructor now requires `ig_id` parameter: `Publisher.new(access_token: token, ig_id: account_id)`
  - `publish_media` method no longer requires `ig_id` parameter (stored in instance)
  - Simplified method calls: `publisher.publish_media(media_url: url, media_type: 'IMAGE')`
  - Breaking change: existing code needs to be updated to new initialization pattern

### Added
- **Authenticator#get_user_info_from_code** - New convenience method that combines authentication flow
  - Exchanges authorization code for access token
  - Gets long-lived access token (60-day validity)
  - Optionally retrieves user information with specified fields
  - Returns `{ access_token: token_hash }` or `{ access_token: token_hash, user_details: user_info }`
  - Simplifies common authentication workflow into single method call

### Improved
- **UserDetails API** - All methods now return hashes with symbol keys instead of string keys
  - `get_user_info` returns `{ id: "...", username: "...", media_count: 42 }` (Ruby convention)
  - `get_long_lived_access_token` returns `{ access_token: "...", token_type: "bearer", expires_in: 5184000 }`
  - `refresh_access_token` returns `{ access_token: "...", token_type: "bearer", expires_in: 5184000 }`
- **Publisher class refactoring** - Improved code structure and maintainability
  - Split large methods into smaller, focused functions for better readability
  - Extracted media container body building logic into separate method
  - Separated carousel media preparation logic for better organization
  - Improved status handling with dedicated error management methods
  - All methods now comply with linting standards (≤10 lines, ≤5 parameters)
  - Enhanced code modularity while maintaining backward compatibility

### Tests
- **Complete test suite** - Added comprehensive RSpec test coverage for all components
  - **Authenticator tests** - Full coverage including new `get_user_info_from_code` method
    - Tests for both scenarios: with and without fields parameter
    - Tests for empty fields array handling
    - Error handling tests for all possible failure points
    - Mock-based testing with proper isolation
  - **UserDetails tests** - Updated to work with symbol keys
  - **Publisher tests** - Complete media publishing workflow coverage
  - **ApiHelper tests** - HTTP request handling and error scenarios
  - All 83 tests passing with comprehensive coverage

## [0.1.0] - 2025-07-31

### Added

#### Core Architecture
- **Authenticator class** - OAuth authentication with Instagram Basic Display API
  - Exchange authorization code for access token
  - Support for client credentials and redirect URI configuration

- **Publisher class** - Complete media publishing functionality
  - Single image publishing with optional captions
  - Single video publishing (MP4, MOV) with optional captions
  - Carousel publishing (multiple images) with optional captions
  - Support for Instagram Reels and Stories
  - Automatic media container creation and status monitoring
  - Built-in waiting mechanism for media processing completion

- **UserDetails class** - User information and token management
  - Retrieve user profile information with customizable fields
  - Get long-lived access tokens (60-day validity)
  - Refresh existing access tokens (extend for another 60 days)

- **BaseClient superclass** - Shared functionality for token-based classes
  - Common constants (INSTAGRAM_GRAPH_API_ENDPOINT, GRAPH_API_VERSION)
  - Standardized initialization with access_token parameter
  - Inheritance support for consistent API design

- **ApiHelper module** - Centralized HTTP request handling
  - Faraday wrapper with automatic error handling
  - JSON and form-encoded request support
  - Unified Instagram API error parsing and exception raising
  - Configurable headers and parameters

#### Features
- **Caption Support** - Add text descriptions, hashtags, emojis, and mentions to all post types
- **Token Lifecycle Management** - Complete OAuth flow from short-lived to long-lived tokens
- **Error Handling** - Comprehensive error handling for HTTP, JSON, and Instagram API errors
- **Clean Architecture** - SOLID principles with separation of concerns
- **Modular Design** - Independent classes that can be used separately or together

#### Media Type Support
- **IMAGE** - JPEG, PNG images with captions
- **VIDEO** - MP4, MOV videos with captions  
- **REELS** - Instagram Reels with captions
- **STORIES** - Instagram Stories with captions
- **CAROUSEL** - Multiple images in single post with captions

#### Developer Experience
- **Comprehensive Documentation** - Detailed README with usage examples
- **Ruby 3.0+ Support** - Modern Ruby version compatibility
- **MIT License** - Open source friendly licensing
- **RubyGems Ready** - Proper gemspec configuration for easy installation

### Technical Details
- **Dependencies**: faraday (~> 2.0), json (~> 2.0)
- **Development Dependencies**: rake, rspec, rubocop
- **Minimum Ruby Version**: 3.0.0
- **Instagram Graph API Version**: v23.0

### Limitations
- Carousel posts currently support images only (mixed media support planned for future versions)
