# Swift5 API client for FloatplaneAPIClient

Homepage: [https://jman012.github.io/FloatplaneAPIDocs](https://jman012.github.io/FloatplaneAPIDocs)

This document describes the REST API layer of [https://www.floatplane.com](https://www.floatplane.com), a content creation and video streaming website created by Floatplane Media Inc. and Linus Media Group, where users can support their favorite creators via paid subscriptions in order to watch their video and livestream content in higher quality, in addition to other perks.

While this document contains stubs for all of the Floatplane APIs for this version, many are not filled out because they are related only to content creation, moderation, or administration and are not needed for regular use. These have \"TODO\" as the description, and are automatically removed before document generation. If you are viewing the \"Trimmed\" version of this document, they have been removed for brevity.

## API Object Organization

- **Users** and **Creators** exist on Floatplane at the highest level
 - The highest-level object in Floatplane is the Creator. This is an entity, such as Linus Tech Tips, that produces media for Users.
- A Creator owns one or more **Subscription Plans**
- A User can view a Creator's Content if they are subscribed to them
- A Creator publishes **Content**, in the form of **Blog Posts**
 - Content is produced by Creators, and show up for subscribed Users to view when it is released. A piece of Content is meant to be generic, and may contain different types of sub-Content. Currently, the only type is a Blog Post.
 - A Blog Post is the main type of Content that a Creator produces. Blog Posts are how a Creator can share text and/or media attachments with their subscribers.
- A Blog Post is comprised of one or more of: video, audio, or picture **Attachments**
 - A media Attachment may be: video, audio, picture. Attachments are a part of Blog Posts, and are in a particular order.
- A Creator may also have a single **Livestream**
- Creators also may have one or more **Channels**

## API Flow

As of Floatplane version 4.0.13, these are the recommended endpoints to use for normal operations.

1. Login
 1. `/api/v3/auth/captcha/info` - Get captcha information
 1. `/api/v2/auth/login` - Login with username, password, and optional captcha token
 1. `/api/v2/auth/checkFor2faLogin` - Optionally provide 2FA token to complete login
 1. `/api/v2/auth/logout` - Logout at a later point in time
1. Home page
 1. `/api/v3/user/subscriptions` - Get the user's active subscriptions
    1. `/api/v3/creator/info` - Get more information on subscribed creators
        1. Shows a list of creators that the user can select
  1. Note that this can search and return multiple creators. The V3 version only works for a single creator at a time.
 1. `/api/v3/content/creator/list` - Using the subscriptions, show a home page with content from all subscriptions/subscribed creators
  1. Supply all creator identifiers from the subscriptions
  1. This is be paginated
1. Creator page
 1. `/api/v3/creator/info` - Get more details for the creator to display, including if livestreams are available
 1. `/api/v3/content/creator` - Show recent content by that creator (as opposed to all subscribed creators, above)
 1. `/api/v2/plan/info` - Show available plans the user can subscribe to for the creator
1. Content page
 1. `/api/v3/content/post` - Show more detailed information about a piece of content, including text description, available attachments, metadata, interactions, etc.
 1. `/api/v3/content/related` - List some related content for the user to watch next
 1. `/api/v3/comment` - Load comments for the content for the user to read
  1. There are several more comment APIs to post, like, dislike, etc.
 1. `/api/v2/user/ban/status` - Determine if the user is banned from this creator
 1. `/api/v3/content/{video|audio|picture|gallery}` - Load the attached media for the post. This is usually video, but audio, pictures, and galleries are also available.
 1. `/api/v3/delivery/info` - For video and audio, this is required to get the information to stream or download the content in media players
1. Livestream
 1. `/api/v3/delivery/info` - Using the type \"livestream\" to load the livestream media in a media player
 1. `wss://chat.floatplane.com/sails.io/?...` - To connect to the livestream chat over websocket. See https://jman012.github.io/FloatplaneAPIDocs/ for more information on the FP Async API with Websockets.
1. User Profile
 1. `/api/v3/user/self` - Display username, name, email, and profile pictures

## API Organization

The organization of APIs into categories in this document are reflected from the internal organization of the Floatplane website bundled code, from `frontend.floatplane.com/{version}/main.js`. This is in order to use the best organization from the original developers' point of view.

For instance, Floatplane's authentication endpoints are organized into `Auth.v2.login(...)`, `Auth.v2.logout()`, and `Auth.v3.getCaptchaInfo()`. A limitation in OpenAPI is the lack of nested tagging/structure, so this document splits `Auth` into `AuthV2` and `AuthV3` to emulate the nested structure.

## Rate Limiting

The Floatplane API may employ rate limiting on certain or all endpoints. If too many requests are sent by a client to the API, it will be rejected and rate-limited. This may be by IP address per endpoint in a certain unit of time, but is subject to change.

Rate-limited requests will respond with an HTTP 429 response. The content of the response may be HTML or JSON and is subject to change. The response will also have a `Retry-After` header, which contains the number of seconds remaining until the rate limiting will cease for the client on that endpoint. 

Clients are expected to both 1) prevent too many requests from executing at a time, usually for specific endpoints, and particulay for the `/api/v2/cdn/delivery` and `/api/v3/delivery/info` endpoints, and 2) properly handle rate-limited responses by ceasing requests until the `Retry-After` expiration.

## Notes

Note that the Floatplane API does support the use of [ETags](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/ETag) for retrieving some information, such as retrieving information about creators, users, etc. Expect an HTTP 304 if the content has not changed, and to re-use cached responses. This is useful to ease the strain on Floatplane's API server.

The date-time format used by Floatplane API is not standard ISO 8601 format. The dates/times given by Floatplane include milliseconds. Depending on your code generator, you may need to override the date-time format to something similar to `yyyy-MM-dd'T'HH:mm:ss.SSSZ`, for both encoding and decoding.

## Overview
This API client was generated by the [OpenAPI Generator](https://openapi-generator.tech) project.  By using the [openapi-spec](https://github.com/OAI/OpenAPI-Specification) from a remote server, you can easily generate an API client.

- API version: 3.10.0-c
- Package version: 
- Generator version: 7.10.0
- Build package: org.openapitools.codegen.languages.Swift5ClientCodegen
For more information, please visit [https://github.com/Jman012/FloatplaneAPI/](https://github.com/Jman012/FloatplaneAPI/)

## Installation

Add the following entry in your Package.swift:

> .package(path: "./FloatplaneAPIClient")

## Documentation for API Endpoints

All URIs are relative to *https://www.floatplane.com*

Class | Method | HTTP request | Description
------------ | ------------- | ------------- | -------------
*AuthV2API* | [**checkFor2faLogin**](docs/AuthV2API.md#checkfor2falogin) | **POST** /api/v2/auth/checkFor2faLogin | Check For 2FA Login
*AuthV2API* | [**login**](docs/AuthV2API.md#login) | **POST** /api/v2/auth/login | Login
*AuthV2API* | [**logout**](docs/AuthV2API.md#logout) | **POST** /api/v2/auth/logout | Logout
*AuthV3API* | [**checkFor2faLoginV3**](docs/AuthV3API.md#checkfor2faloginv3) | **POST** /api/v3/auth/checkFor2faLogin | Check For 2FA Login
*AuthV3API* | [**getCaptchaInfo**](docs/AuthV3API.md#getcaptchainfo) | **GET** /api/v3/auth/captcha/info | Get Captcha Info
*AuthV3API* | [**loginV3**](docs/AuthV3API.md#loginv3) | **POST** /api/v3/auth/login | Login
*AuthV3API* | [**logoutV3**](docs/AuthV3API.md#logoutv3) | **POST** /api/v3/auth/logout | Logout
*CDNV2API* | [**getDeliveryInfo**](docs/CDNV2API.md#getdeliveryinfo) | **GET** /api/v2/cdn/delivery | Get Delivery Info
*CommentV3API* | [**dislikeComment**](docs/CommentV3API.md#dislikecomment) | **POST** /api/v3/comment/dislike | Dislike Comment
*CommentV3API* | [**getCommentReplies**](docs/CommentV3API.md#getcommentreplies) | **GET** /api/v3/comment/replies | Get Comment Replies
*CommentV3API* | [**getComments**](docs/CommentV3API.md#getcomments) | **GET** /api/v3/comment | Get Comments
*CommentV3API* | [**likeComment**](docs/CommentV3API.md#likecomment) | **POST** /api/v3/comment/like | Like Comment
*CommentV3API* | [**postComment**](docs/CommentV3API.md#postcomment) | **POST** /api/v3/comment | Post Comment
*ConnectedAccountsV2API* | [**listConnections**](docs/ConnectedAccountsV2API.md#listconnections) | **GET** /api/v2/connect/list | List Connections
*ContentV3API* | [**dislikeContent**](docs/ContentV3API.md#dislikecontent) | **POST** /api/v3/content/dislike | Dislike Content
*ContentV3API* | [**getBlogPost**](docs/ContentV3API.md#getblogpost) | **GET** /api/v3/content/post | Get Blog Post
*ContentV3API* | [**getContentTags**](docs/ContentV3API.md#getcontenttags) | **GET** /api/v3/content/tags | Get Content Tags
*ContentV3API* | [**getCreatorBlogPosts**](docs/ContentV3API.md#getcreatorblogposts) | **GET** /api/v3/content/creator | Get Creator Blog Posts
*ContentV3API* | [**getMultiCreatorBlogPosts**](docs/ContentV3API.md#getmulticreatorblogposts) | **GET** /api/v3/content/creator/list | Get Multi Creator Blog Posts
*ContentV3API* | [**getPictureContent**](docs/ContentV3API.md#getpicturecontent) | **GET** /api/v3/content/picture | Get Picture Content
*ContentV3API* | [**getProgress**](docs/ContentV3API.md#getprogress) | **POST** /api/v3/content/get/progress | Get Progress
*ContentV3API* | [**getRelatedBlogPosts**](docs/ContentV3API.md#getrelatedblogposts) | **GET** /api/v3/content/related | Get Related Blog Posts
*ContentV3API* | [**getVideoContent**](docs/ContentV3API.md#getvideocontent) | **GET** /api/v3/content/video | Get Video Content
*ContentV3API* | [**likeContent**](docs/ContentV3API.md#likecontent) | **POST** /api/v3/content/like | Like Content
*ContentV3API* | [**updateProgress**](docs/ContentV3API.md#updateprogress) | **POST** /api/v3/content/progress | Update Progress
*CreatorSubscriptionPlanV2API* | [**getCreatorSubInfoPublic**](docs/CreatorSubscriptionPlanV2API.md#getcreatorsubinfopublic) | **GET** /api/v2/plan/info | Get Creator Sub Info Public
*CreatorV2API* | [**getCreatorInfoByName**](docs/CreatorV2API.md#getcreatorinfobyname) | **GET** /api/v2/creator/named | Get Info By Name
*CreatorV2API* | [**getInfo**](docs/CreatorV2API.md#getinfo) | **GET** /api/v2/creator/info | Get Info
*CreatorV3API* | [**getCreator**](docs/CreatorV3API.md#getcreator) | **GET** /api/v3/creator/info | Get Creator
*CreatorV3API* | [**getCreatorByName**](docs/CreatorV3API.md#getcreatorbyname) | **GET** /api/v3/creator/named | Get Creator By Name
*CreatorV3API* | [**getCreators**](docs/CreatorV3API.md#getcreators) | **GET** /api/v3/creator/list | Get Creators
*CreatorV3API* | [**listCreatorChannelsV3**](docs/CreatorV3API.md#listcreatorchannelsv3) | **GET** /api/v3/creator/channels/list | List Creator Channels
*DeliveryV3API* | [**getDeliveryInfoV3**](docs/DeliveryV3API.md#getdeliveryinfov3) | **GET** /api/v3/delivery/info | Get Delivery Info
*EdgesV2API* | [**getEdges**](docs/EdgesV2API.md#getedges) | **GET** /api/v2/edges | Get Edges
*FAQV2API* | [**getFaqSections**](docs/FAQV2API.md#getfaqsections) | **GET** /api/v2/faq/list | Get Faq Sections
*LoyaltyRewardsV3API* | [**listCreatorLoyaltyReward**](docs/LoyaltyRewardsV3API.md#listcreatorloyaltyreward) | **POST** /api/v3/user/loyaltyreward/list | List Creator Loyalty Reward
*PaymentsV2API* | [**listAddresses**](docs/PaymentsV2API.md#listaddresses) | **GET** /api/v2/payment/address/list | List Addresses
*PaymentsV2API* | [**listInvoices**](docs/PaymentsV2API.md#listinvoices) | **GET** /api/v2/payment/invoice/list | List Invoices
*PaymentsV2API* | [**listPaymentMethods**](docs/PaymentsV2API.md#listpaymentmethods) | **GET** /api/v2/payment/method/list | List Payment Methods
*PollV3API* | [**joinLiveRoom**](docs/PollV3API.md#joinliveroom) | **POST** /api/v3/poll/live/joinroom | Poll Join Live Room
*PollV3API* | [**leaveLiveRoom**](docs/PollV3API.md#leaveliveroom) | **POST** /api/v3/poll/live/leaveLiveRoom | Poll Leave Live Room
*PollV3API* | [**votePoll**](docs/PollV3API.md#votepoll) | **POST** /api/v3/poll/votePoll | Vote Poll
*RedirectV3API* | [**redirectYTLatest**](docs/RedirectV3API.md#redirectytlatest) | **POST** /api/v3/redirect-yt-latest/{channelKey} | Redirect to YouTube Latest Video
*SocketV3API* | [**disconnectSocket**](docs/SocketV3API.md#disconnectsocket) | **POST** /api/v3/socket/disconnect | Disconnect
*SocketV3API* | [**socketConnect**](docs/SocketV3API.md#socketconnect) | **POST** /api/v3/socket/connect | Connect
*SubscriptionsV3API* | [**listUserSubscriptionsV3**](docs/SubscriptionsV3API.md#listusersubscriptionsv3) | **GET** /api/v3/user/subscriptions | List User Subscriptions
*UserV2API* | [**getSecurity**](docs/UserV2API.md#getsecurity) | **GET** /api/v2/user/security | Get Security
*UserV2API* | [**getUserInfo**](docs/UserV2API.md#getuserinfo) | **GET** /api/v2/user/info | Info
*UserV2API* | [**getUserInfoByName**](docs/UserV2API.md#getuserinfobyname) | **GET** /api/v2/user/named | Get Info By Name
*UserV2API* | [**userCreatorBanStatus**](docs/UserV2API.md#usercreatorbanstatus) | **GET** /api/v2/user/ban/status | User Creator Ban Status
*UserV3API* | [**getActivityFeedV3**](docs/UserV3API.md#getactivityfeedv3) | **GET** /api/v3/user/activity | Get Activity Feed
*UserV3API* | [**getSelf**](docs/UserV3API.md#getself) | **GET** /api/v3/user/self | Get Self
*UserV3API* | [**getStatus**](docs/UserV3API.md#getstatus) | **GET** /api/v3/status | Get Status
*UserV3API* | [**getUserNotificationSettingsV3**](docs/UserV3API.md#getusernotificationsettingsv3) | **GET** /api/v3/user/notification/list | Get User Notification Settings
*UserV3API* | [**updateUserNotificationSettingsV3**](docs/UserV3API.md#updateusernotificationsettingsv3) | **POST** /api/v3/user/notification/update | Update User Notification Settings


## Documentation For Models

 - [AudioAttachmentModel](docs/AudioAttachmentModel.md)
 - [AudioAttachmentModelWaveform](docs/AudioAttachmentModelWaveform.md)
 - [AuthLoginV2Request](docs/AuthLoginV2Request.md)
 - [AuthLoginV2Response](docs/AuthLoginV2Response.md)
 - [AuthLoginV3Request](docs/AuthLoginV3Request.md)
 - [AuthLoginV3Response](docs/AuthLoginV3Response.md)
 - [BlogPostModelV3](docs/BlogPostModelV3.md)
 - [BlogPostModelV3Channel](docs/BlogPostModelV3Channel.md)
 - [BlogPostModelV3Creator](docs/BlogPostModelV3Creator.md)
 - [BlogPostModelV3CreatorOwner](docs/BlogPostModelV3CreatorOwner.md)
 - [CdnDeliveryV2DownloadResponse](docs/CdnDeliveryV2DownloadResponse.md)
 - [CdnDeliveryV2QualityLevelModel](docs/CdnDeliveryV2QualityLevelModel.md)
 - [CdnDeliveryV2ResourceModel](docs/CdnDeliveryV2ResourceModel.md)
 - [CdnDeliveryV2ResourceModelData](docs/CdnDeliveryV2ResourceModelData.md)
 - [CdnDeliveryV2Response](docs/CdnDeliveryV2Response.md)
 - [CdnDeliveryV2VodLivestreamResponse](docs/CdnDeliveryV2VodLivestreamResponse.md)
 - [CdnDeliveryV3Group](docs/CdnDeliveryV3Group.md)
 - [CdnDeliveryV3ImagePresentationCharacteristics](docs/CdnDeliveryV3ImagePresentationCharacteristics.md)
 - [CdnDeliveryV3MediaBitrateInfo](docs/CdnDeliveryV3MediaBitrateInfo.md)
 - [CdnDeliveryV3MediaBitrateInfoBitrate](docs/CdnDeliveryV3MediaBitrateInfoBitrate.md)
 - [CdnDeliveryV3MediaIdentityCharacteristics](docs/CdnDeliveryV3MediaIdentityCharacteristics.md)
 - [CdnDeliveryV3Meta](docs/CdnDeliveryV3Meta.md)
 - [CdnDeliveryV3MetaAudio](docs/CdnDeliveryV3MetaAudio.md)
 - [CdnDeliveryV3MetaCommon](docs/CdnDeliveryV3MetaCommon.md)
 - [CdnDeliveryV3MetaCommonAccess](docs/CdnDeliveryV3MetaCommonAccess.md)
 - [CdnDeliveryV3MetaImage](docs/CdnDeliveryV3MetaImage.md)
 - [CdnDeliveryV3MetaLive](docs/CdnDeliveryV3MetaLive.md)
 - [CdnDeliveryV3MetaVideo](docs/CdnDeliveryV3MetaVideo.md)
 - [CdnDeliveryV3Origin](docs/CdnDeliveryV3Origin.md)
 - [CdnDeliveryV3Response](docs/CdnDeliveryV3Response.md)
 - [CdnDeliveryV3Variant](docs/CdnDeliveryV3Variant.md)
 - [ChannelModel](docs/ChannelModel.md)
 - [CheckFor2faLoginRequest](docs/CheckFor2faLoginRequest.md)
 - [ChildImageModel](docs/ChildImageModel.md)
 - [CommentLikeV3PostRequest](docs/CommentLikeV3PostRequest.md)
 - [CommentModel](docs/CommentModel.md)
 - [CommentV3PostRequest](docs/CommentV3PostRequest.md)
 - [CommentV3PostResponse](docs/CommentV3PostResponse.md)
 - [CommentV3PostResponseInteractionCounts](docs/CommentV3PostResponseInteractionCounts.md)
 - [ConnectedAccountModel](docs/ConnectedAccountModel.md)
 - [ConnectedAccountModelConnectedAccount](docs/ConnectedAccountModelConnectedAccount.md)
 - [ConnectedAccountModelConnectedAccountData](docs/ConnectedAccountModelConnectedAccountData.md)
 - [ContentCreatorListLastItems](docs/ContentCreatorListLastItems.md)
 - [ContentCreatorListV3Response](docs/ContentCreatorListV3Response.md)
 - [ContentLikeV3Request](docs/ContentLikeV3Request.md)
 - [ContentPictureV3Response](docs/ContentPictureV3Response.md)
 - [ContentPostV3Response](docs/ContentPostV3Response.md)
 - [ContentVideoV3Response](docs/ContentVideoV3Response.md)
 - [ContentVideoV3ResponseLevelsInner](docs/ContentVideoV3ResponseLevelsInner.md)
 - [ContentVideoV3ResponseTextTracksInner](docs/ContentVideoV3ResponseTextTracksInner.md)
 - [CreatorModelV2](docs/CreatorModelV2.md)
 - [CreatorModelV2Extended](docs/CreatorModelV2Extended.md)
 - [CreatorModelV3](docs/CreatorModelV3.md)
 - [CreatorModelV3Category](docs/CreatorModelV3Category.md)
 - [CreatorModelV3Owner](docs/CreatorModelV3Owner.md)
 - [DiscordRoleModel](docs/DiscordRoleModel.md)
 - [DiscordServerModel](docs/DiscordServerModel.md)
 - [EdgeDataCenter](docs/EdgeDataCenter.md)
 - [EdgeModel](docs/EdgeModel.md)
 - [EdgesModel](docs/EdgesModel.md)
 - [ErrorModel](docs/ErrorModel.md)
 - [ErrorModelErrorsInner](docs/ErrorModelErrorsInner.md)
 - [FaqSectionModel](docs/FaqSectionModel.md)
 - [FaqSectionModelFaqsInner](docs/FaqSectionModelFaqsInner.md)
 - [GetCaptchaInfoResponse](docs/GetCaptchaInfoResponse.md)
 - [GetCaptchaInfoResponseV2](docs/GetCaptchaInfoResponseV2.md)
 - [GetCaptchaInfoResponseV2Variants](docs/GetCaptchaInfoResponseV2Variants.md)
 - [GetCaptchaInfoResponseV2VariantsAndroid](docs/GetCaptchaInfoResponseV2VariantsAndroid.md)
 - [GetCaptchaInfoResponseV3](docs/GetCaptchaInfoResponseV3.md)
 - [GetCaptchaInfoResponseV3Variants](docs/GetCaptchaInfoResponseV3Variants.md)
 - [GetProgressRequest](docs/GetProgressRequest.md)
 - [GetProgressResponseInner](docs/GetProgressResponseInner.md)
 - [ImageFileModel](docs/ImageFileModel.md)
 - [ImageModel](docs/ImageModel.md)
 - [LiveStreamModel](docs/LiveStreamModel.md)
 - [LiveStreamModelOffline](docs/LiveStreamModelOffline.md)
 - [PaymentAddressModel](docs/PaymentAddressModel.md)
 - [PaymentInvoiceListV2Response](docs/PaymentInvoiceListV2Response.md)
 - [PaymentInvoiceListV2ResponseInvoicesInner](docs/PaymentInvoiceListV2ResponseInvoicesInner.md)
 - [PaymentInvoiceListV2ResponseInvoicesInnerSubscriptionsInner](docs/PaymentInvoiceListV2ResponseInvoicesInnerSubscriptionsInner.md)
 - [PaymentInvoiceListV2ResponseInvoicesInnerSubscriptionsInnerPlan](docs/PaymentInvoiceListV2ResponseInvoicesInnerSubscriptionsInnerPlan.md)
 - [PaymentInvoiceListV2ResponseInvoicesInnerSubscriptionsInnerPlanCreator](docs/PaymentInvoiceListV2ResponseInvoicesInnerSubscriptionsInnerPlanCreator.md)
 - [PaymentMethodModel](docs/PaymentMethodModel.md)
 - [PaymentMethodModelCard](docs/PaymentMethodModelCard.md)
 - [PictureAttachmentModel](docs/PictureAttachmentModel.md)
 - [PlanInfoV2Response](docs/PlanInfoV2Response.md)
 - [PlanInfoV2ResponsePlansInner](docs/PlanInfoV2ResponsePlansInner.md)
 - [PostMetadataModel](docs/PostMetadataModel.md)
 - [SubscriptionPlanModel](docs/SubscriptionPlanModel.md)
 - [UpdateProgressRequest](docs/UpdateProgressRequest.md)
 - [UserActivityV3Response](docs/UserActivityV3Response.md)
 - [UserActivityV3ResponseActivityInner](docs/UserActivityV3ResponseActivityInner.md)
 - [UserInfoV2Response](docs/UserInfoV2Response.md)
 - [UserInfoV2ResponseUsersInner](docs/UserInfoV2ResponseUsersInner.md)
 - [UserInfoV2ResponseUsersInnerUser](docs/UserInfoV2ResponseUsersInnerUser.md)
 - [UserLinksV3ResponseValue](docs/UserLinksV3ResponseValue.md)
 - [UserLinksV3ResponseValueType](docs/UserLinksV3ResponseValueType.md)
 - [UserModel](docs/UserModel.md)
 - [UserNamedV2Response](docs/UserNamedV2Response.md)
 - [UserNotificationModel](docs/UserNotificationModel.md)
 - [UserNotificationModelUserNotificationSetting](docs/UserNotificationModelUserNotificationSetting.md)
 - [UserNotificationUpdateV3PostRequest](docs/UserNotificationUpdateV3PostRequest.md)
 - [UserSecurityV2Response](docs/UserSecurityV2Response.md)
 - [UserSelfModel](docs/UserSelfModel.md)
 - [UserSelfV3Response](docs/UserSelfV3Response.md)
 - [UserStatusV3Response](docs/UserStatusV3Response.md)
 - [UserSubscriptionModel](docs/UserSubscriptionModel.md)
 - [VideoAttachmentModel](docs/VideoAttachmentModel.md)
 - [VotePollRequest](docs/VotePollRequest.md)


<a id="documentation-for-authorization"></a>
## Documentation For Authorization


Authentication schemes defined for the API:
<a id="CookieAuth"></a>
### CookieAuth

- **Type**: API key
- **API key parameter name**: sails.sid
- **Location**: 


# How do I migrate from the Swift 5 generator to the swift 6 generator?

https://openapi-generator.tech/docs/faq-generators#how-do-i-migrate-from-the-swift-5-generator-to-the-swift-6-generator

## Author



