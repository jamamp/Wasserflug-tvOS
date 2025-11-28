# Wasserflug tvOS
An unofficial Floatplane client for Apple TV/tvOS. View it on the Apple TV App Store at https://apps.apple.com/us/app/wasserflug/id1611976921.

⚠️ Notice ⚠️: The App Store version is currently out-dated. Getting the Test Flight version is recommended. See below in "Beta Testing" for instructions.

Looking for Roku? https://github.com/bmlzootown/Hydravion

Looking for Android TV? https://github.com/bmlzootown/Hydravion-AndroidTV

## Screenshots

See https://imgur.com/a/vXAcEJy for screenshots of Wasserflug.

## Features

### Implemented Floatplane Features
- ✅ Floatplane Login (and with 2FA)
  - Login via LTT Forum/Discord: See FAQ
- ✅ Aggregated home screen
- ✅ Creator screens with proper branding (banner image, profile picture, "About" information)
  - ✅ Search a creator for videos
  - ✅ Creator Livestream
  - ✅ Channel support (branding, search, etc.)
- ✅ Floatplane tags (view only)
- ✅ Formatted post descriptions
- ✅ 4K Support
- ✅ Watch progress (syncs with Floatplane website)
- ✅ Attachment views
  - ✅ Videos
  - ✅ Pictures
  - ❌ Audio
  - ❌ Gallery
- ❌ Livestream chat
- ❌ Notifications
- ❌ Creator discovery
- ❌ Search by tags
  - Note: You can currently manually search a tag by typing a `#` before the tag name in the creator's search screen, same as Floatplane.com.
  - This is more about clicking a tag button to search it automatically.
- ❌ Picture-in-Picture

## Frequently Asked Questions

- Q: I have an grandfathered/OG account on LinusTechTips forums, and normally log in to Floatplane using this account. How do I log in on Wasserflug?
    - A: When you log in to Floatplane using a Discord or LTT Forum account, an account is made for you in Floatplane as well, with its own password and username (the username is usually copied from the other service). You were asked to create a Floatplane-specific password when you first logged in. This is the information you should use to log in to Wasserflug. If you have forgotten the Floatplane password for this account (because you normally use LTT Forum or Discord to log in), you can go onto the Floatplane website to change your password first.
- Q: I'm getting an error when logging in, "Logging in was successful, but an error was encountered while loading your user profile."? What do I do?
    - A: This happens sometimes because of the differences between the LTT subscriptions and other content creators on Floatplane having slightly different data here and there. Let the app developer know over Discord or email and the issue can be sorted out quickly enough!

## Technical

### Beta Testing

If you would like to enter the beta testing via Test Flight for Wasserflug or to receive advanced updates, please use this Test Flist invite link: https://testflight.apple.com/join/aYwKPFNF.

### Development

Cloning the git repository and opening/running it in Xcode, with some slight changes for provisioning/signing should be all that is needed at this time. There are some dependencies; please allow time for Xcode to automatically fetch those before/during initial compilation.

This uses an Xcode tvOS SwiftUI template, including a `.xcodeproj` file. Opening the `.xcodeproj` file is the main way of accessing this project. Wasserflug uses SwiftUI instead of UIKit, and targets tvOS 15.0.

For accessing the Floatplane API, this uses an accompanying project that maps out the API in the OpenAPI specification for automatic code and documentation generation. Check it out at https://jman012.github.io/FloatplaneAPIDocs/. The `floatplane-openapi-specification-trimmed.json` in this repository is copied over from that project, and the auto-generated code is generated using ``generate-floatplane-api-client.sh` and included in this repository in the `FloatplaneAPIClient` folder.

### Related

See bmlzootown's Hydravion projects and Discord server and more for other Floatplane-related software and discussion:
- https://github.com/bmlzootown/Hydravion
- https://github.com/bmlzootown/Hydravion-AndroidTV
- https://discord.gg/4xKDGz5M5B
- https://jman012.github.io/FloatplaneAPIDocs/

# Legal
Application created by James Linnell.

Wasserflug logo copyright to Yaroslav Shkuro via [Shutterstock](https://www.shutterstock.com/image-vector/small-seaplane-isolated-vector-illustration-single-1091024861).
