import Foundation
import SwiftUI
import Vapor
import FloatplaneAPIClient

protocol FPAPIService {
	/// Auth-related
	func getUserStatus(platform: UserV3API.Platform_getStatus, version: String) async throws -> UserV3API.GetStatus
	func listUserSubscriptionsV3() async throws -> [UserSubscriptionModel]
	func getInfo(creatorGUID: [String]) async throws -> [CreatorModelV2]
	func getCreator(id: String) async throws -> CreatorModelV3
	func getUsers(ids: [String]) async throws -> UserInfoV2Response
	func login(username: String, password: String, captchaToken: String?) -> EventLoopFuture<AuthV3API.LoginV3>
	func secondFactor(token: String) -> EventLoopFuture<AuthV3API.CheckFor2faLoginV3>
	
	/// Creator-related
	func getHomeContent(ids: [String], limit: Int, lastItems: [ContentCreatorListLastItems]?) async throws -> ContentCreatorListV3Response
	func getProgress(ids: [String]) async throws -> [GetProgressResponseInner]
	func getCreatorContent(id: String, limit: Int, fetchAfter: Int?, search: String?, channelId: String?) async throws -> [BlogPostModelV3]
	func getLivestream(url: URI) -> EventLoopFuture<ClientResponse>
	
	/// Post-related
	func getBlogPost(id: String) -> EventLoopFuture<ContentV3API.GetBlogPost>
	func getVideoContent(id: String) async throws -> ContentVideoV3Response
	func getCdn(type: CDNV2API.ModelType_getDeliveryInfo, id: String) -> EventLoopFuture<CDNV2API.GetDeliveryInfo>
	func getDeliveryInfo(scenario: DeliveryV3API.Scenario_getDeliveryInfoV3, entityId: String, outputKind: DeliveryV3API.OutputKind_getDeliveryInfoV3?) async throws -> CdnDeliveryV3Response
	func getPictureContent(id: String) -> EventLoopFuture<ContentV3API.GetPictureContent>
	func updateProgress(id: String, contentType: UpdateProgressRequest.ContentType, progress: Int) async throws
	
	/// Interaction-related
	func likeContent(id: String) -> EventLoopFuture<ContentV3API.LikeContent>
	func dislikeContent(id: String) -> EventLoopFuture<ContentV3API.DislikeContent>
}

struct FPAPIServiceKey: EnvironmentKey {
	static var defaultValue: FPAPIService = MockFPAPIService()
}

extension EnvironmentValues {
	var fpApiService: FPAPIService {
		get { self[FPAPIServiceKey.self] }
		set { self[FPAPIServiceKey.self] = newValue }
	}
}

class DefaultFPAPIService: FPAPIService {
	lazy var logger: Logger = {
		var logger = Wasserflug_tvOSApp.logger
		logger[metadataKey: "class"] = "\(Self.Type.self)"
		return logger
	}()
	
	func getUserStatus(platform: UserV3API.Platform_getStatus, version: String) async throws -> UserV3API.GetStatus {
		return try await withCheckedThrowingContinuation { continuation in
			UserV3API
				.getStatus(platform: platform, version: version)
				.whenComplete { result in
					switch result {
					case let .success(value):
						continuation.resume(returning: value)
					case let .failure(error):
						self.logger.error("Encountered an unexpected error while loading creator information. Reporting the error to the user. Error: \(String(reflecting: error))")
						continuation.resume(throwing: error)
					}
				}
		}
	}

	func listUserSubscriptionsV3() async throws -> [UserSubscriptionModel] {
		return try await withCheckedThrowingContinuation { continuation in
			SubscriptionsV3API
				.listUserSubscriptionsV3()
				.whenComplete { result in
					switch result {
					case let .success(value):
						switch value {
						case let .http200(value: response, raw: clientResponse):
							self.logger.debug("User subscriptions raw response: \(clientResponse.plaintextDebugContent)")
							continuation.resume(returning: response)
						case let .http0(value: errorModel, raw: clientResponse),
							 let .http400(value: errorModel, raw: clientResponse),
							 let .http401(value: errorModel, raw: clientResponse),
							 let .http403(value: errorModel, raw: clientResponse),
							 let .http404(value: errorModel, raw: clientResponse):
							self.logger.warning("Received an unexpected HTTP status (\(clientResponse.status.code)) while loading user subscriptions. Reporting the error to the user. Error Model: \(String(reflecting: errorModel)).")
							continuation.resume(throwing: errorModel)
						case .http429(raw: _):
							self.logger.warning("Received HTTP 429 Too Many Requests.")
							continuation.resume(throwing: WasserflugError.http429)
						}
					case let .failure(error):
						self.logger.error("Encountered an unexpected error while loading user subscriptions. Reporting the error to the user. Error: \(String(reflecting: error))")
						continuation.resume(throwing: error)
					}
				}
		}
	}

	func getInfo(creatorGUID: [String]) async throws -> [CreatorModelV2] {
		return try await withCheckedThrowingContinuation { continuation in
			CreatorV2API
				.getInfo(creatorGUID: creatorGUID)
				.whenComplete { result in
					switch result {
					case let .success(value):
						switch value {
						case let .http200(value: response, raw: clientResponse):
							self.logger.debug("Creator information raw response: \(clientResponse.plaintextDebugContent)")
							continuation.resume(returning: response)
						case let .http0(value: errorModel, raw: clientResponse),
							 let .http400(value: errorModel, raw: clientResponse),
							 let .http401(value: errorModel, raw: clientResponse),
							 let .http403(value: errorModel, raw: clientResponse),
							 let .http404(value: errorModel, raw: clientResponse):
							self.logger.warning("Received an unexpected HTTP status (\(clientResponse.status.code)) while loading creator information. Reporting the error to the user. Error Model: \(String(reflecting: errorModel)).")
							continuation.resume(throwing: errorModel)
						case .http429(raw: _):
							self.logger.warning("Received HTTP 429 Too Many Requests.")
							continuation.resume(throwing: WasserflugError.http429)
						}
					case let .failure(error):
						self.logger.error("Encountered an unexpected error while loading creator information. Reporting the error to the user. Error: \(String(reflecting: error))")
						continuation.resume(throwing: error)
					}
				}
		}
	}

	func getCreator(id: String) async throws -> CreatorModelV3 {
		return try await withCheckedThrowingContinuation { continuation in
			CreatorV3API
				.getCreator(id: id)
				.whenComplete { result in
					switch result {
					case let .success(value):
						switch value {
						case let .http200(value: response, raw: clientResponse):
							self.logger.debug("Creator information raw response: \(clientResponse.plaintextDebugContent)")
							continuation.resume(returning: response)
						case let .http0(value: errorModel, raw: clientResponse),
							 let .http400(value: errorModel, raw: clientResponse),
							 let .http401(value: errorModel, raw: clientResponse),
							 let .http403(value: errorModel, raw: clientResponse),
							 let .http404(value: errorModel, raw: clientResponse):
							self.logger.warning("Received an unexpected HTTP status (\(clientResponse.status.code)) while loading creator information. Reporting the error to the user. Error Model: \(String(reflecting: errorModel)).")
							continuation.resume(throwing: errorModel)
						case .http429(raw: _):
							self.logger.warning("Received HTTP 429 Too Many Requests.")
							continuation.resume(throwing: WasserflugError.http429)
						}
					case let .failure(error):
						self.logger.error("Encountered an unexpected error while loading creator information. Reporting the error to the user. Error: \(String(reflecting: error))")
						continuation.resume(throwing: error)
					}
				}
		}
	}

	func getUsers(ids: [String]) async throws -> UserInfoV2Response {
		return try await withCheckedThrowingContinuation { continuation in
			UserV2API
				.getUserInfo(id: ids)
				.whenComplete { result in
					switch result {
					case let .success(value):
						switch value {
						case let .http200(value: response, raw: clientResponse):
							self.logger.debug("Users raw response: \(clientResponse.plaintextDebugContent)")
							continuation.resume(returning: response)
						case let .http0(value: errorModel, raw: clientResponse),
							 let .http400(value: errorModel, raw: clientResponse),
							 let .http401(value: errorModel, raw: clientResponse),
							 let .http403(value: errorModel, raw: clientResponse),
							 let .http404(value: errorModel, raw: clientResponse):
							self.logger.warning("Received an unexpected HTTP status (\(clientResponse.status.code)) while loading users. Reporting the error to the user. Error Model: \(String(reflecting: errorModel)).")
							continuation.resume(throwing: errorModel)
						case .http429(raw: _):
							self.logger.warning("Received HTTP 429 Too Many Requests.")
							continuation.resume(throwing: WasserflugError.http429)
						}
					case let .failure(error):
						self.logger.error("Encountered an unexpected error while loading users. Reporting the error to the user. Error: \(String(reflecting: error))")
						continuation.resume(throwing: error)
					}
				}
		}
	}

	func login(username: String, password: String, captchaToken: String?) -> EventLoopFuture<AuthV3API.LoginV3> {
		return AuthV3API.loginV3(authLoginV3Request: .init(username: username, password: password, captchaToken: captchaToken))
	}

	func secondFactor(token: String) -> EventLoopFuture<AuthV3API.CheckFor2faLoginV3> {
		return AuthV3API.checkFor2faLoginV3(checkFor2faLoginRequest: .init(token: token))
	}

	func getHomeContent(ids: [String], limit: Int, lastItems: [ContentCreatorListLastItems]?) async throws -> ContentCreatorListV3Response {
		return try await withCheckedThrowingContinuation { continuation in
			ContentV3API
				.getMultiCreatorBlogPosts(ids: ids, limit: limit, fetchAfter: lastItems)
				.whenComplete { result in
					switch result {
					case let .success(value):
						switch value {
						case let .http200(value: response, raw: clientResponse):
							self.logger.debug("Home content raw response: \(clientResponse.plaintextDebugContent)")
							continuation.resume(returning: response)
						case let .http0(value: errorModel, raw: clientResponse),
							 let .http400(value: errorModel, raw: clientResponse),
							 let .http401(value: errorModel, raw: clientResponse),
							 let .http403(value: errorModel, raw: clientResponse),
							 let .http404(value: errorModel, raw: clientResponse):
							self.logger.warning("Received an unexpected HTTP status (\(clientResponse.status.code)) while loading home content. Reporting the error to the user. Error Model: \(String(reflecting: errorModel)).")
							continuation.resume(throwing: errorModel)
						case .http429(raw: _):
							self.logger.warning("Received HTTP 429 Too Many Requests.")
							continuation.resume(throwing: WasserflugError.http429)
						}
					case let .failure(error):
						self.logger.error("Encountered an unexpected error while loading home content. Reporting the error to the user. Error: \(String(reflecting: error))")
						continuation.resume(throwing: error)
					}
				}
		}
	}

	func getProgress(ids: [String]) async throws -> [GetProgressResponseInner] {
		return try await withCheckedThrowingContinuation { continuation in
			ContentV3API
				.getProgress(getProgressRequest: .init(ids: ids, contentType: .blogpost))
				.whenComplete { result in
					switch result {
					case let .success(value):
						switch value {
						case let .http200(value: response, raw: clientResponse):
							self.logger.debug("Get progress raw response: \(clientResponse.plaintextDebugContent)")
							continuation.resume(returning: response)
						case let .http0(value: errorModel, raw: clientResponse),
							 let .http400(value: errorModel, raw: clientResponse),
							 let .http401(value: errorModel, raw: clientResponse),
							 let .http403(value: errorModel, raw: clientResponse),
							 let .http404(value: errorModel, raw: clientResponse):
							self.logger.warning("Received an unexpected HTTP status (\(clientResponse.status.code)) while loading get progress. Reporting the error to the user. Error Model: \(String(reflecting: errorModel)).")
							continuation.resume(throwing: errorModel)
						case .http429(raw: _):
							self.logger.warning("Received HTTP 429 Too Many Requests.")
							continuation.resume(throwing: WasserflugError.http429)
						}
					case let .failure(error):
						self.logger.error("Encountered an unexpected error while loading get progress. Reporting the error to the user. Error: \(String(reflecting: error))")
						continuation.resume(throwing: error)
					}
				}
		}
	}

	func getCreatorContent(id: String, limit: Int, fetchAfter: Int? = nil, search: String? = nil, channelId: String? = nil) async throws -> [BlogPostModelV3] {
		return try await withCheckedThrowingContinuation { continuation in
			ContentV3API
				.getCreatorBlogPosts(id: id, channel: channelId, limit: limit, fetchAfter: fetchAfter, search: search)
				.whenComplete { result in
					switch result {
					case let .success(value):
						switch value {
						case let .http200(value: response, raw: clientResponse):
							self.logger.debug("Creator content raw response: \(clientResponse.plaintextDebugContent)")
							continuation.resume(returning: response)
						case let .http0(value: errorModel, raw: clientResponse),
							 let .http400(value: errorModel, raw: clientResponse),
							 let .http401(value: errorModel, raw: clientResponse),
							 let .http403(value: errorModel, raw: clientResponse),
							 let .http404(value: errorModel, raw: clientResponse):
							self.logger.warning("Received an unexpected HTTP status (\(clientResponse.status.code)) while loading creator content. Reporting the error to the user. Error Model: \(String(reflecting: errorModel)).")
							continuation.resume(throwing: errorModel)
						case .http429(raw: _):
							self.logger.warning("Received HTTP 429 Too Many Requests.")
							continuation.resume(throwing: WasserflugError.http429)
						}
					case let .failure(error):
						self.logger.error("Encountered an unexpected error while loading creator content. Reporting the error to the user. Error: \(String(reflecting: error))")
						continuation.resume(throwing: error)
					}
				}
		}
	}

	func getLivestream(url: URI) -> EventLoopFuture<ClientResponse> {
		return Configuration.apiClient!.get(url)
	}

	func getBlogPost(id: String) -> EventLoopFuture<ContentV3API.GetBlogPost> {
		return ContentV3API.getBlogPost(id: id)
	}

	func getVideoContent(id: String) async throws -> ContentVideoV3Response {
		return try await withCheckedThrowingContinuation { continuation in
			ContentV3API
				.getVideoContent(id: id)
				.whenComplete { result in
					switch result {
					case let .success(value):
						switch value {
						case let .http200(value: response, raw: clientResponse):
							self.logger.debug("Video content raw response: \(clientResponse.plaintextDebugContent)")
							continuation.resume(returning: response)
						case let .http0(value: errorModel, raw: clientResponse),
							 let .http400(value: errorModel, raw: clientResponse),
							 let .http401(value: errorModel, raw: clientResponse),
							 let .http403(value: errorModel, raw: clientResponse),
							 let .http404(value: errorModel, raw: clientResponse):
							self.logger.warning("Received an unexpected HTTP status (\(clientResponse.status.code)) while loading video content. Reporting the error to the user. Error Model: \(String(reflecting: errorModel)).")
							continuation.resume(throwing: errorModel)
						case .http429(raw: _):
							self.logger.warning("Received HTTP 429 Too Many Requests.")
							continuation.resume(throwing: WasserflugError.http429)
						}
					case let .failure(error):
						self.logger.error("Encountered an unexpected error while loading video content. Reporting the error to the user. Error: \(String(reflecting: error))")
						continuation.resume(throwing: error)
					}
				}
		}
	}

	func getCdn(type: CDNV2API.ModelType_getDeliveryInfo, id: String) -> EventLoopFuture<CDNV2API.GetDeliveryInfo> {
		switch type {
		case .live:
			return CDNV2API.getDeliveryInfo(type: type, creator: id)
		default:
			return CDNV2API.getDeliveryInfo(type: type, guid: id)
		}
	}

	func getDeliveryInfo(scenario: DeliveryV3API.Scenario_getDeliveryInfoV3, entityId: String, outputKind: DeliveryV3API.OutputKind_getDeliveryInfoV3? = nil) async throws -> CdnDeliveryV3Response {
		return try await withCheckedThrowingContinuation { continuation in
			DeliveryV3API
				.getDeliveryInfoV3(scenario: scenario, entityId: entityId, outputKind: outputKind)
				.whenComplete { result in
					switch result {
					case let .success(value):
						switch value {
						case let .http200(value: response, raw: clientResponse):
							self.logger.debug("Delivery info raw response: \(clientResponse.plaintextDebugContent)")
							continuation.resume(returning: response)
						case let .http0(value: errorModel, raw: clientResponse),
							 let .http400(value: errorModel, raw: clientResponse),
							 let .http401(value: errorModel, raw: clientResponse),
							 let .http403(value: errorModel, raw: clientResponse),
							 let .http404(value: errorModel, raw: clientResponse):
							self.logger.warning("Received an unexpected HTTP status (\(clientResponse.status.code)) while loading delivery info. Reporting the error to the user. Error Model: \(String(reflecting: errorModel)).")
							continuation.resume(throwing: errorModel)
						case .http429(raw: _):
							self.logger.warning("Received HTTP 429 Too Many Requests.")
							continuation.resume(throwing: WasserflugError.http429)
						}
					case let .failure(error):
						self.logger.error("Encountered an unexpected error while loading delivery info. Reporting the error to the user. Error: \(String(reflecting: error))")
						continuation.resume(throwing: error)
					}
				}
		}
	}

	func getPictureContent(id: String) -> EventLoopFuture<ContentV3API.GetPictureContent> {
		return ContentV3API.getPictureContent(id: id)
	}

	func updateProgress(id: String, contentType: UpdateProgressRequest.ContentType, progress: Int) async throws {
		return try await withCheckedThrowingContinuation { continuation in
			ContentV3API
				.updateProgress(updateProgressRequest: .init(id: id, contentType: contentType, progress: progress))
				.whenComplete { result in
					switch result {
					case let .success(value):
						switch value {
						case let .http200(value: _, raw: clientResponse):
							self.logger.debug("Update Progress raw response: \(clientResponse.plaintextDebugContent)")
							continuation.resume(returning: ())
						case let .http0(value: errorModel, raw: clientResponse),
							 let .http400(value: errorModel, raw: clientResponse),
							 let .http401(value: errorModel, raw: clientResponse),
							 let .http403(value: errorModel, raw: clientResponse),
							 let .http404(value: errorModel, raw: clientResponse):
							self.logger.warning("Received an unexpected HTTP status (\(clientResponse.status.code)) while updating progress. Reporting the error to the user. Error Model: \(String(reflecting: errorModel)).")
							continuation.resume(throwing: errorModel)
						case .http429(raw: _):
							self.logger.warning("Received HTTP 429 Too Many Requests.")
							continuation.resume(throwing: WasserflugError.http429)
						}
					case let .failure(error):
						self.logger.error("Encountered an unexpected error while loading delivery info. Reporting the error to the user. Error: \(String(reflecting: error))")
						continuation.resume(throwing: error)
					}
				}
		}
	}

	func likeContent(id: String) -> EventLoopFuture<ContentV3API.LikeContent> {
		return ContentV3API.likeContent(contentLikeV3Request: .init(contentType: .blogpost, id: id))
	}

	func dislikeContent(id: String) -> EventLoopFuture<ContentV3API.DislikeContent> {
		return ContentV3API.dislikeContent(contentLikeV3Request: .init(contentType: .blogpost, id: id))
	}
	
	func test() async throws -> String {
		return try await withCheckedThrowingContinuation { continuation in
			continuation.resume(returning: "hi")
		}
	}
}

class MockFPAPIService: FPAPIService {
	private var eventLoop: EventLoop {
		Configuration.apiClient!.eventLoop
	}
	
	func getUserStatus(platform: UserV3API.Platform_getStatus, version: String) async throws -> UserV3API.GetStatus {
		return try await withCheckedThrowingContinuation { continuation in
			continuation.resume(returning: .http200(value: .init(selfUser: MockData.userSelf), raw: ClientResponse()))
		}
//		return eventLoop.makeSucceededFuture(.http401(value: ErrorModel(id: "", errors: [], message: ""), raw: ClientResponse()))
	}

	func listUserSubscriptionsV3() async throws -> [UserSubscriptionModel] {
		return try await withCheckedThrowingContinuation { continuation in
			continuation.resume(returning: MockData.userSubscriptions)
		}
	}

	func getInfo(creatorGUID: [String]) async throws -> [CreatorModelV2] {
		return try await withCheckedThrowingContinuation { continuation in
			continuation.resume(returning: MockData.creators)
		}
	}

	func getCreator(id: String) async throws -> CreatorModelV3 {
		return try await withCheckedThrowingContinuation { continuation in
			continuation.resume(returning: MockData.creatorV3)
		}
	}

	func getUsers(ids: [String]) async throws -> UserInfoV2Response {
		return try await withCheckedThrowingContinuation { continuation in
			continuation.resume(returning: MockData.creatorOwners)
		}
	}

	func login(username: String, password: String, captchaToken: String?) -> EventLoopFuture<AuthV3API.LoginV3> {
		return eventLoop.makeSucceededFuture(.http200(value: .init(user: nil, needs2FA: true), raw: ClientResponse()))
	}

	func secondFactor(token: String) -> EventLoopFuture<AuthV3API.CheckFor2faLoginV3> {
		return eventLoop.makeSucceededFuture(.http200(value: .init(user: .init(id: "1", username: "my_username", profileImage: .init(width: 1, height: 1, path: "", childImages: nil)), needs2FA: false), raw: ClientResponse()))
	}

	func getHomeContent(ids: [String], limit: Int, lastItems: [ContentCreatorListLastItems]?) async throws -> ContentCreatorListV3Response {
		return try await withCheckedThrowingContinuation { continuation in
			continuation.resume(returning: MockData.blogPosts)
		}
	}

	func getProgress(ids: [String]) async throws -> [GetProgressResponseInner] {
		return try await withCheckedThrowingContinuation { continuation in
			continuation.resume(returning: [])
		}
	}

	func getCreatorContent(id: String, limit: Int, fetchAfter: Int? = nil, search: String? = nil, channelId: String?) async throws -> [BlogPostModelV3] {
		return try await withCheckedThrowingContinuation { continuation in
			continuation.resume(returning: MockData.blogPosts.blogPosts)
		}
	}

	func getLivestream(url: URI) -> EventLoopFuture<ClientResponse> {
		return eventLoop.makeSucceededFuture(ClientResponse(status: .notFound, headers: .init(), body: nil))
	}

	func getBlogPost(id: String) -> EventLoopFuture<ContentV3API.GetBlogPost> {
		return eventLoop.makeSucceededFuture(.http200(value: MockData.getBlogPost, raw: ClientResponse()))
	}

	func getVideoContent(id: String) async throws -> ContentVideoV3Response {
		return try await withCheckedThrowingContinuation { continuation in
			continuation.resume(returning: MockData.getVideoContent)
		}
	}

	func getCdn(type: CDNV2API.ModelType_getDeliveryInfo, id: String) -> EventLoopFuture<CDNV2API.GetDeliveryInfo> {
		switch type {
		case .live:
			return eventLoop.makeSucceededFuture(.http200(value: MockData.getCdnLive, raw: ClientResponse()))
		default:
			return eventLoop.makeSucceededFuture(.http200(value: MockData.getCdn, raw: ClientResponse()))
		}
	}

	func getDeliveryInfo(scenario: DeliveryV3API.Scenario_getDeliveryInfoV3, entityId: String, outputKind: DeliveryV3API.OutputKind_getDeliveryInfoV3? = nil) async throws -> CdnDeliveryV3Response {
		return try await withCheckedThrowingContinuation { continuation in
			switch scenario {
			case .ondemand:
				continuation.resume(returning: MockData.getDeliveryOnDemand)
			case .live:
				continuation.resume(returning: MockData.getDeliveryLive)
			case .download:
				continuation.resume(returning: MockData.getDeliveryDownload)
			}
		}
	}

	func getPictureContent(id: String) -> EventLoopFuture<ContentV3API.GetPictureContent> {
		return eventLoop.makeSucceededFuture(.http200(value: MockData.getPictureContent, raw: ClientResponse()))
	}

	func updateProgress(id: String, contentType: UpdateProgressRequest.ContentType, progress: Int) async throws {
		// Nothing
	}

	func likeContent(id: String) -> EventLoopFuture<ContentV3API.LikeContent> {
		return eventLoop.makeSucceededFuture(.http200(value: ["like"], raw: ClientResponse()))
	}

	func dislikeContent(id: String) -> EventLoopFuture<ContentV3API.DislikeContent> {
		return eventLoop.makeSucceededFuture(.http200(value: ["dislike"], raw: ClientResponse()))
	}
}

enum MockData {
	static let decoder = try! Configuration.contentConfiguration.requireDecoder(for: .json)
	
	static let userSelf: UserSelfV3Response = try! decoder.decode(UserSelfV3Response.self, from: ByteBuffer(string: MockStaticData.userSelf), headers: .init())
	
	static let userSubscriptions: [UserSubscriptionModel] = {
		return try! decoder.decode([UserSubscriptionModel].self, from: ByteBuffer(string: MockStaticData.userSubscriptions), headers: .init())
	}()
	
	static let creators: [CreatorModelV2] = {
		return try! decoder.decode([CreatorModelV2].self, from: ByteBuffer(string: MockStaticData.creators), headers: .init())
	}()
	
	static let creatorV3: CreatorModelV3 = try! decoder.decode(CreatorModelV3.self, from: ByteBuffer(string: MockStaticData.creatorV3), headers: .init())
	
	static let creatorOwners: UserInfoV2Response = try! decoder.decode(UserInfoV2Response.self, from: ByteBuffer(string: MockStaticData.creatorOwners), headers: .init())
	
	static let userInfo: UserInfo = {
		let a = UserInfo()
		a.userSelf = userSelf
		a.userSubscriptions = userSubscriptions
		a.creators = [
			creatorV3.id: creatorV3,
		]
		return a
	}()
	
	static let blogPosts: ContentCreatorListV3Response = {
		let blogPosts = try! decoder.decode(ContentCreatorListV3Response.self, from: ByteBuffer(string: MockStaticData.getHomeContent), headers: .init())
		return blogPosts
	}()
	
	static let getBlogPost: ContentPostV3Response = try! decoder.decode(ContentPostV3Response.self, from: ByteBuffer(string: MockStaticData.getBlogPost), headers: .init())
	
	static let getVideoContent: ContentVideoV3Response = try! decoder.decode(ContentVideoV3Response.self, from: ByteBuffer(string: MockStaticData.getVideoContent), headers: .init())
	
	static let getCdn: CdnDeliveryV2Response = try! decoder.decode(CdnDeliveryV2Response.self, from: ByteBuffer(string: MockStaticData.getCdn), headers: .init())
	
	static let getCdnLive: CdnDeliveryV2Response = try! decoder.decode(CdnDeliveryV2Response.self, from: ByteBuffer(string: MockStaticData.getCdnLive), headers: .init())
	
	static let getDeliveryOnDemand: CdnDeliveryV3Response = try! decoder.decode(CdnDeliveryV3Response.self, from: ByteBuffer(string: MockStaticData.getDeliveryOnDemand), headers: .init())
	
	static let getDeliveryLive: CdnDeliveryV3Response = try! decoder.decode(CdnDeliveryV3Response.self, from: ByteBuffer(string: MockStaticData.getDeliveryLive), headers: .init())
	
	static let getDeliveryDownload: CdnDeliveryV3Response = try! decoder.decode(CdnDeliveryV3Response.self, from: ByteBuffer(string: MockStaticData.getDeliveryDownload), headers: .init())
	
	static let getPictureContent: ContentPictureV3Response = try! decoder.decode(ContentPictureV3Response.self, from: ByteBuffer(string: MockStaticData.getPictureContent), headers: .init())
}
	
enum MockStaticData {
	static let userSelf: String = #"""
	{
		"id": "0123456789abcdef01234567",
		"username": "my_username",
		"profileImage": {
			"width": 512,
			"height": 512,
			"path": "https://pbs.floatplane.com/profile_images/default/user12.png",
			"childImages": [
				{
					"width": 250,
					"height": 250,
					"path": "https://pbs.floatplane.com/profile_images/default/user12_250x250.png"
				},
				{
					"width": 100,
					"height": 100,
					"path": "https://pbs.floatplane.com/profile_images/default/user12_100x100.png"
				}
			]
		},
		"email": "testemail@example.com",
		"displayName": "Firstname Lastname",
		"creators": [],
		"scheduledDeletionDate": null
	}
	"""#
	static let userSubscriptions: String = #"""
	[
		{
			"startDate": "2020-09-25T07:35:04.273Z",
			"endDate": "2021-09-25T07:35:04.273Z",
			"paymentID": 12345,
			"interval": "year",
			"paymentCancelled": false,
			"plan": {
				"id": "5d48d0306825b5780db93d07",
				"title": "LTT Supporter (1080p)",
				"description": "Includes:\n- Early access (when possible)\n- Live Streaming\n- Behind-the-scenes, cutting room floor & exclusives\n\nNOTE: Tech Quickie and TechLinked are included for now, but will move to their own Floatplane pages in the future",
				"price": "5.00",
				"priceYearly": "50.00",
				"currency": "usd",
				"logo": null,
				"interval": "month",
				"featured": true,
				"allowGrandfatheredAccess": false,
				"discordServers": [],
				"discordRoles": []
			},
			"creator": "59f94c0bdd241b70349eb72b"
		}
	]
	"""#
	static let creators: String = #"""
	[
		{
			"id": "59f94c0bdd241b70349eb72b",
			"owner": "59f94c0bdd241b70349eb723",
			"title": "LinusTechTips",
			"urlname": "linustechtips",
			"description": "We make entertaining videos about technology, including tech reviews, showcases and other content.",
			"about": "# We're LinusTechTips\nWe make *videos* and stuff, cool eh?",
			"category": "59f94c0bdd241b70349eb727",
			"cover": {
				"width": 1990,
				"height": 519,
				"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867.jpeg",
				"childImages": [
					{
						"width": 1245,
						"height": 325,
						"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867_1245x325.jpeg"
					}
				]
			},
			"icon": {
				"width": 600,
				"height": 600,
				"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205.jpeg",
				"childImages": [
					{
						"width": 250,
						"height": 250,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_250x250.jpeg"
					},
					{
						"width": 100,
						"height": 100,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_100x100.jpeg"
					}
				]
			},
			"liveStream": {
				"id": "5c13f3c006f1be15e08e05c0",
				"title": "We're Changing Our Name - WAN Show October 29, 2021",
				"description": "<p>Check out Secret Lab at <a href=\"https://lmg.gg/SecretLabWAN\" rel=\"noopener noreferrer\" target=\"_blank\">https://lmg.gg/SecretLabWAN</a></p><p><br></p><p>Save 10% at Ridage Wallet with offer code WAN at <a href=\"https://www.ridge.com/WAN\" rel=\"noopener noreferrer\" target=\"_blank\">https://www.ridge.com/WAN</a></p><p><br></p><p>Try Pulseway for free and start remotely monitoring and managing your server or PC at <a href=\"https://lmg.gg/Ktd7Z\" rel=\"noopener noreferrer\" target=\"_blank\">https://lmg.gg/Ktd7Z</a></p><p><br></p><p>Podcast Download: TBD</p><p><br></p><p>Check out our other Podcasts:</p><p>They're Just Movies Podcast: <a href=\"https://www.youtube.com/channel/UCt-oJR5teQIjOAxCmIQvcgA\" rel=\"noopener noreferrer\" target=\"_blank\">https://www.youtube.com/channel/UCt-oJR5teQIjOAxCmIQvcgA</a></p><p><br></p><p>Timestamps TBD</p>",
				"thumbnail": {
					"width": 1920,
					"height": 1080,
					"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/567667542019112_1635554358724.jpeg",
					"childImages": [
						{
							"width": 400,
							"height": 225,
							"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/567667542019112_1635554358724_400x225.jpeg"
						},
						{
							"width": 1200,
							"height": 675,
							"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/567667542019112_1635554358724_1200x675.jpeg"
						}
					]
				},
				"owner": "59f94c0bdd241b70349eb72b",
				"streamPath": "/api/video/v1/us-east-1.758417551536.channel.yKkxur4ukc0B.m3u8",
				"offline": {
					"title": "Offline",
					"description": "We're offline for now – please check back later!",
					"thumbnail": {
						"width": 1920,
						"height": 1080,
						"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026.jpeg",
						"childImages": [
							{
								"width": 400,
								"height": 225,
								"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_400x225.jpeg"
							},
							{
								"width": 1200,
								"height": 675,
								"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_1200x675.jpeg"
							}
						]
					}
				}
			},
			"subscriptionPlans": null,
			"discoverable": true,
			"subscriberCountDisplay": "total",
			"incomeDisplay": false,
			"socialLinks": {
				"instagram": "https://www.instagram.com/linustech/",
				"website": "https://linustechtips.com",
				"facebook": "https://www.facebook.com/LinusTech",
				"youtube": "https://www.youtube.com/user/LinusTechTips",
				"twitter": "https://twitter.com/linustech"
			},
			"discordServers": [
				{
					"id": "5baa8838d9f3aa0a83acd429",
					"guildName": "LinusTechTips",
					"guildIcon": "a_528743a32b33b5eb227a8405d5593473",
					"inviteLink": "https://discord.gg/LTT",
					"inviteMode": "link"
				},
				{
					"id": "5e34cd9a9dbb744872192895",
					"guildName": "LTT Minecraft Network",
					"guildIcon": "4f7f812b49196b1646bdcdb84b948c84",
					"inviteLink": "https://discord.gg/VVpwBPXrMc",
					"inviteMode": "link"
				}
			]
		}
	]
	"""#
	static let creatorOwners: String = #"""
	{
		"users": [
			{
				"id": "59f94c0bdd241b70349eb723",
				"user": {
					"id": "59f94c0bdd241b70349eb723",
					"username": "Linus",
					"profileImage": {
						"width": 600,
						"height": 600,
						"path": "https://pbs.floatplane.com/profile_images/59f94c0bdd241b70349eb723/013264939123424_1535577174346.jpeg",
						"childImages": [
							{
								"width": 100,
								"height": 100,
								"path": "https://pbs.floatplane.com/profile_images/59f94c0bdd241b70349eb723/013264939123424_1535577174346_100x100.jpeg"
							},
							{
								"width": 250,
								"height": 250,
								"path": "https://pbs.floatplane.com/profile_images/59f94c0bdd241b70349eb723/013264939123424_1535577174346_250x250.jpeg"
							}
						]
					}
				}
			}
		]
	}
	"""#
	static let creatorV3: String = #"""
	{
		"id": "59f94c0bdd241b70349eb72b",
		"owner": {
			"id": "59f94c0bdd241b70349eb723",
			"username": "Linus"
		},
		"title": "LinusTechTips",
		"urlname": "linustechtips",
		"description": "We make entertaining videos about technology, including tech reviews, showcases and other content.",
		"about": "# We're LinusTechTips\nWe make videos and stuff, cool eh?",
		"category": {
			"id": "59f94c0bdd241b70349eb727",
			"title": "Technology"
		},
		"cover": {
			"width": 1990,
			"height": 519,
			"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867.jpeg",
			"childImages": [
				{
					"width": 1245,
					"height": 325,
					"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867_1245x325.jpeg"
				}
			]
		},
		"icon": {
			"width": 600,
			"height": 600,
			"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205.jpeg",
			"childImages": [
				{
					"width": 250,
					"height": 250,
					"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_250x250.jpeg"
				},
				{
					"width": 100,
					"height": 100,
					"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_100x100.jpeg"
				}
			]
		},
		"liveStream": {
			"id": "5c13f3c006f1be15e08e05c0",
			"title": "It's Time To Name And Shame - WAN Show June 2, 2023",
			"description": "<p>Get a 15-day free trial for unlimited backup at<a href=\"https://www.backblaze.com/landing/podcast-wan.html\" rel=\"noopener noreferrer\" target=\"_blank\"> https://www.backblaze.com/landing/podcast-wan.html</a></p><p>Visit<a href=\"https://www.squarespace.com/WAN\" rel=\"noopener noreferrer\" target=\"_blank\"> https://www.squarespace.com/WAN</a> and use offer code WAN for 10% off</p><p>Start taking proactive steps to safeguard your network and critical infrastructure at<a href=\"https://lmg.gg/blkpt\" rel=\"noopener noreferrer\" target=\"_blank\"> https://lmg.gg/blkpt</a></p><p><br></p><p>Podcast Download: TBD</p>",
			"thumbnail": {
				"width": 1920,
				"height": 1080,
				"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/227070283326316_1685755931723.jpeg",
				"childImages": [
					{
						"width": 400,
						"height": 225,
						"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/227070283326316_1685755931723_400x225.jpeg"
					},
					{
						"width": 1200,
						"height": 675,
						"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/227070283326316_1685755931723_1200x675.jpeg"
					}
				]
			},
			"owner": "59f94c0bdd241b70349eb72b",
			"channel": "63fe42c309e691e4e36de93d",
			"streamPath": "/api/video/v1/us-east-1.758417551536.channel.yKkxur4ukc0B.m3u8",
			"offline": {
				"title": "Offline",
				"description": "We're offline for now – please check back later!",
				"thumbnail": {
					"width": 1920,
					"height": 1080,
					"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026.jpeg",
					"childImages": [
						{
							"width": 400,
							"height": 225,
							"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_400x225.jpeg"
						},
						{
							"width": 1200,
							"height": 675,
							"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_1200x675.jpeg"
						}
					]
				}
			}
		},
		"subscriptionPlans": [
			{
				"id": "5d48d0306825b5780db93d07",
				"title": "LTT Supporter",
				"description": "- 2 Exclusives Per Week (Meet the Team, Extras, Behind the Scenes) \n- Exclusive livestreams\n- Save $10 by purchasing an annual subscription\n- Our gratitude for your support",
				"price": "5.00",
				"priceYearly": "50.00",
				"currency": "usd",
				"logo": null,
				"interval": "month",
				"featured": true,
				"allowGrandfatheredAccess": false,
				"discordServers": [],
				"discordRoles": []
			},
			{
				"id": "5e0ba6ac14e2590f760a0f0f",
				"title": "LTT Supporter Plus",
				"description": "- 4K Bitrate Streaming\n- 2 Exclusives Per Week (Meet the Team, Extras, Behind the Scenes) \n- Exclusive livestreams\n- Save $20 by purchasing an annual subscription\n- LTX 2023 Digital Pass\n- Our gratitude for your support",
				"price": "10.00",
				"priceYearly": "100.00",
				"currency": "usd",
				"logo": null,
				"interval": "month",
				"featured": true,
				"allowGrandfatheredAccess": false,
				"discordServers": [],
				"discordRoles": []
			}
		],
		"discoverable": true,
		"subscriberCountDisplay": "total",
		"incomeDisplay": false,
		"defaultChannel": "63fe42c309e691e4e36de93d",
		"socialLinks": {
			"instagram": "https://www.instagram.com/linustech",
			"website": "https://linustechtips.com",
			"facebook": "https://www.facebook.com/LinusTech",
			"youtube": "https://www.youtube.com/user/LinusTechTips",
			"twitter": "https://twitter.com/linustech"
		},
		"channels": [
			{
				"id": "63fe42c309e691e4e36de93d",
				"creator": "59f94c0bdd241b70349eb72b",
				"title": "Linus Tech Tips",
				"urlname": "main",
				"about": "# We're LinusTechTips\nWe make videos and stuff, cool eh?",
				"order": 0,
				"cover": {
					"width": 1990,
					"height": 519,
					"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867.jpeg",
					"childImages": [
						{
							"width": 1245,
							"height": 325,
							"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867_1245x325.jpeg"
						}
					]
				},
				"card": null,
				"icon": {
					"width": 600,
					"height": 600,
					"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205.jpeg",
					"childImages": [
						{
							"width": 250,
							"height": 250,
							"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_250x250.jpeg"
						},
						{
							"width": 100,
							"height": 100,
							"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_100x100.jpeg"
						}
					]
				},
				"socialLinks": {}
			},
			{
				"id": "6413534d88c13c181c3e2809",
				"creator": "59f94c0bdd241b70349eb72b",
				"title": "TechLinked",
				"urlname": "techlinked",
				"about": "News about tech + gaming culture, delivered thrice weekly.\n\nWe're also doing long-form video essays now, apparently. \n\nThe TalkLinked talk show/podcast will probably come back at some point, too!\n\nWriters: Riley Murdock, Jon Martin, James Strieb",
				"order": 2,
				"cover": {
					"width": 1080,
					"height": 282,
					"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/6413534d88c13c181c3e2809/231100243161134_1678988109632.jpeg",
					"childImages": []
				},
				"card": null,
				"icon": {
					"width": 88,
					"height": 88,
					"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/6413534d88c13c181c3e2809/955526950207988_1678988110287.jpeg",
					"childImages": []
				},
				"socialLinks": {}
			},
			{
				"id": "64135da7ce81077a8480c679",
				"creator": "59f94c0bdd241b70349eb72b",
				"title": "ShortCircuit",
				"urlname": "shortcircuit",
				"about": "What's in the box? Let's find out!\n\nOfficial channel under Linus Media Group.",
				"order": 3,
				"cover": {
					"width": 1084,
					"height": 283,
					"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/64135da7ce81077a8480c679/745715133852622_1678990806332.jpeg",
					"childImages": []
				},
				"card": null,
				"icon": {
					"width": 88,
					"height": 88,
					"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/64135da7ce81077a8480c679/470304051261927_1678990806883.jpeg",
					"childImages": []
				},
				"socialLinks": {}
			},
			{
				"id": "64135e27c773b27ff22c97eb",
				"creator": "59f94c0bdd241b70349eb72b",
				"title": "Techquickie",
				"urlname": "techquickie",
				"about": "Ever wanted to learn more about your favorite gadgets or a trending topic in tech? \n\nWith a mix of humor, cynicism, and insight, Techquickie brings you the answers to all your tech questions every Tuesday and Friday.",
				"order": 5,
				"cover": {
					"width": 1080,
					"height": 282,
					"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/64135e27c773b27ff22c97eb/721553790654237_1678990887992.jpeg",
					"childImages": []
				},
				"card": null,
				"icon": {
					"width": 88,
					"height": 88,
					"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/64135e27c773b27ff22c97eb/666841640245092_1678990909616.jpeg",
					"childImages": []
				},
				"socialLinks": {}
			},
			{
				"id": "64135e901ebaee42e258eb0b",
				"creator": "59f94c0bdd241b70349eb72b",
				"title": "Mac Address",
				"urlname": "macaddress",
				"about": "The exploration of all things Apple, from iPhones underwater to full iClouds in the sky. We want to be the channel that you come to first for an unexpected viewpoint about the devices you love.",
				"order": 4,
				"cover": {
					"width": 1080,
					"height": 282,
					"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/64135e901ebaee42e258eb0b/254417940627493_1678990992632.jpeg",
					"childImages": []
				},
				"card": null,
				"icon": {
					"width": 88,
					"height": 88,
					"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/64135e901ebaee42e258eb0b/979475909700348_1678990993114.jpeg",
					"childImages": []
				},
				"socialLinks": {}
			},
			{
				"id": "64135ed078d6262f717341b7",
				"creator": "59f94c0bdd241b70349eb72b",
				"title": "Channel Super Fun",
				"urlname": "channelsuperfun",
				"about": "Channel Super Fun is all about the name. Games, toys, and challenges. Expect to find them all here!",
				"order": 6,
				"cover": {
					"width": 1080,
					"height": 282,
					"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/64135ed078d6262f717341b7/881886551214964_1678991123807.jpeg",
					"childImages": []
				},
				"card": null,
				"icon": {
					"width": 88,
					"height": 88,
					"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/64135ed078d6262f717341b7/317924815973639_1678991124672.jpeg",
					"childImages": []
				},
				"socialLinks": {}
			},
			{
				"id": "64135f82fc76ab7f9fbdc876",
				"creator": "59f94c0bdd241b70349eb72b",
				"title": "They're Just Movies",
				"urlname": "tajm",
				"about": "Each week our small group of nerds sits down for a not-so-serious, SPOILER-FILLED, chat about the movies you love.\n\nFormerly known as Carpool Critics, we're part of Linus Media Group!",
				"order": 7,
				"cover": {
					"width": 1080,
					"height": 282,
					"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/64135f82fc76ab7f9fbdc876/190277198232475_1678991235439.jpeg",
					"childImages": []
				},
				"card": null,
				"icon": {
					"width": 88,
					"height": 88,
					"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/64135f82fc76ab7f9fbdc876/570806971094170_1678991236419.jpeg",
					"childImages": []
				},
				"socialLinks": {}
			},
			{
				"id": "6413623f5b12cca228a28e78",
				"creator": "59f94c0bdd241b70349eb72b",
				"title": "FP Exclusive",
				"urlname": "fpexclusive",
				"about": "wow... so empty",
				"order": 1,
				"cover": {
					"width": 1200,
					"height": 313,
					"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/6413623f5b12cca228a28e78/072932633007415_1678991935461.jpeg",
					"childImages": []
				},
				"card": null,
				"icon": {
					"width": 720,
					"height": 720,
					"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/6413623f5b12cca228a28e78/069457536750544_1678991936484.jpeg",
					"childImages": [
						{
							"width": 100,
							"height": 100,
							"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/6413623f5b12cca228a28e78/069457536750544_1678991936484_100x100.jpeg"
						},
						{
							"width": 250,
							"height": 250,
							"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/6413623f5b12cca228a28e78/069457536750544_1678991936484_250x250.jpeg"
						}
					]
				},
				"socialLinks": {}
			}
		],
		"card": {
			"width": 375,
			"height": 500,
			"path": "https://pbs.floatplane.com/creator_card/59f94c0bdd241b70349eb72b/281467946609369_1551250329871.jpeg",
			"childImages": [
				{
					"width": 300,
					"height": 400,
					"path": "https://pbs.floatplane.com/creator_card/59f94c0bdd241b70349eb72b/281467946609369_1551250329871_300x400.jpeg"
				}
			]
		}
	}
	"""#
	static let getHomeContent: String = #"""
	{
		"blogPosts": [
			{
				"id": "ez4ELvWk5m",
				"guid": "ez4ELvWk5m",
				"title": "Livestream VOD – April 15, 2023 @ 02:18 – I Give Up - WAN Show April 14, 2023",
				"text": "<p>JumpCloud offers an Open Directory Platform that makes it possible to unify your technology stack across identity, access, and device management. Learn more here: <a href=\"https://lmg.gg/JumpCloud\">https://lmg.gg/JumpCloud</a></p><p>Check out Goliath today and save 20% at <a href=\"https://lmg.gg/Goliath-Technologies\">https://lmg.gg/Goliath-Technologies</a></p><p>Buy a Seasonic Prime TX 1000W PSU:<a href=\"https://geni.us/aryiquT\"> https://geni.us/aryiquT</a></p><p><br /></p><p>Purchases made through some store links may provide some compensation to Linus Media Group.</p><p><br /></p><p>Podcast Download: TBD</p>",
				"type": "blogPost",
				"channel": {
					"id": "63fe42c309e691e4e36de93d",
					"creator": "59f94c0bdd241b70349eb72b",
					"title": "Linus Tech Tips",
					"urlname": "main",
					"about": "# We're LinusTechTips\nWe make videos and stuff, cool eh?",
					"order": 0,
					"cover": null,
					"card": null,
					"icon": {
						"width": 600,
						"height": 600,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205.jpeg",
						"childImages": [
							{
								"width": 250,
								"height": 250,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_250x250.jpeg"
							},
							{
								"width": 100,
								"height": 100,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_100x100.jpeg"
							}
						]
					}
				},
				"tags": [],
				"attachmentOrder": [
					"wAjrwHU7Fi"
				],
				"releaseDate": "2023-04-15T11:02:00.039Z",
				"likes": 119,
				"dislikes": 0,
				"score": 119,
				"comments": 67,
				"creator": {
					"id": "59f94c0bdd241b70349eb72b",
					"owner": {
						"id": "59f94c0bdd241b70349eb723",
						"username": "Linus"
					},
					"title": "LinusTechTips",
					"urlname": "linustechtips",
					"description": "We make entertaining videos about technology, including tech reviews, showcases and other content.",
					"about": "# We're LinusTechTips\nWe make videos and stuff, cool eh?",
					"category": {
						"id": "59f94c0bdd241b70349eb727",
						"title": "Technology"
					},
					"cover": {
						"width": 1990,
						"height": 519,
						"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867.jpeg",
						"childImages": [
							{
								"width": 1245,
								"height": 325,
								"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867_1245x325.jpeg"
							}
						]
					},
					"icon": {
						"width": 600,
						"height": 600,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205.jpeg",
						"childImages": [
							{
								"width": 250,
								"height": 250,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_250x250.jpeg"
							},
							{
								"width": 100,
								"height": 100,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_100x100.jpeg"
							}
						]
					},
					"liveStream": {
						"id": "5c13f3c006f1be15e08e05c0",
						"title": "I Give Up - WAN Show April 14, 2023",
						"description": "<p>JumpCloud offers an Open Directory Platform that makes it possible to unify your technology stack across identity, access, and device management. Learn more here: <a href=\"https://lmg.gg/JumpCloud\" rel=\"noopener noreferrer\" target=\"_blank\">https://lmg.gg/JumpCloud</a></p><p>Check out Goliath today and save 20% at <a href=\"https://lmg.gg/Goliath-Technologies\" rel=\"noopener noreferrer\" target=\"_blank\">https://lmg.gg/Goliath-Technologies</a></p><p>Buy a Seasonic Prime TX 1000W PSU:<a href=\"https://geni.us/aryiquT\" rel=\"noopener noreferrer\" target=\"_blank\"> https://geni.us/aryiquT</a></p><p><br></p><p>Purchases made through some store links may provide some compensation to Linus Media Group.</p><p><br></p><p>Podcast Download: TBD</p>",
						"thumbnail": {
							"width": 1920,
							"height": 1080,
							"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325.jpeg",
							"childImages": [
								{
									"width": 400,
									"height": 225,
									"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325_400x225.jpeg"
								},
								{
									"width": 1200,
									"height": 675,
									"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325_1200x675.jpeg"
								}
							]
						},
						"owner": "59f94c0bdd241b70349eb72b",
						"channel": "63fe42c309e691e4e36de93d",
						"streamPath": "/api/video/v1/us-east-1.758417551536.channel.yKkxur4ukc0B.m3u8",
						"offline": {
							"title": "Offline",
							"description": "We're offline for now – please check back later!",
							"thumbnail": {
								"width": 1920,
								"height": 1080,
								"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026.jpeg",
								"childImages": [
									{
										"width": 400,
										"height": 225,
										"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_400x225.jpeg"
									},
									{
										"width": 1200,
										"height": 675,
										"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_1200x675.jpeg"
									}
								]
							}
						}
					},
					"subscriptionPlans": [
						{
							"id": "5d48d0306825b5780db93d07",
							"title": "LTT Supporter",
							"description": "- 2 Exclusives Per Week (Meet the Team, Extras, Behind the Scenes) \n- Exclusive livestreams\n- Save $10 by purchasing an annual subscription\n- Our gratitude for your support",
							"price": "5.00",
							"priceYearly": "50.00",
							"currency": "usd",
							"logo": null,
							"interval": "month",
							"featured": true,
							"allowGrandfatheredAccess": false,
							"discordServers": [],
							"discordRoles": []
						},
						{
							"id": "5e0ba6ac14e2590f760a0f0f",
							"title": "LTT Supporter Plus",
							"description": "- 4K Bitrate Streaming\n- 2 Exclusives Per Week (Meet the Team, Extras, Behind the Scenes) \n- Exclusive livestreams\n- Save $20 by purchasing an annual subscription\n- Our gratitude for your support",
							"price": "10.00",
							"priceYearly": "100.00",
							"currency": "usd",
							"logo": null,
							"interval": "month",
							"featured": true,
							"allowGrandfatheredAccess": false,
							"discordServers": [],
							"discordRoles": []
						}
					],
					"discoverable": true,
					"subscriberCountDisplay": "total",
					"incomeDisplay": false,
					"defaultChannel": "63fe42c309e691e4e36de93d",
					"channels": [
						"63fe42c309e691e4e36de93d",
						"6413534d88c13c181c3e2809",
						"64135da7ce81077a8480c679",
						"64135e27c773b27ff22c97eb",
						"64135e901ebaee42e258eb0b",
						"64135ed078d6262f717341b7",
						"64135f82fc76ab7f9fbdc876",
						"6413623f5b12cca228a28e78"
					],
					"card": {
						"width": 375,
						"height": 500,
						"path": "https://pbs.floatplane.com/creator_card/59f94c0bdd241b70349eb72b/281467946609369_1551250329871.jpeg",
						"childImages": [
							{
								"width": 300,
								"height": 400,
								"path": "https://pbs.floatplane.com/creator_card/59f94c0bdd241b70349eb72b/281467946609369_1551250329871_300x400.jpeg"
							}
						]
					}
				},
				"wasReleasedSilently": false,
				"metadata": {
					"hasVideo": true,
					"videoCount": 1,
					"videoDuration": 15695,
					"hasAudio": false,
					"audioCount": 0,
					"audioDuration": 0,
					"hasPicture": false,
					"pictureCount": 0,
					"isFeatured": false,
					"hasGallery": false,
					"galleryCount": 0
				},
				"galleryAttachments": [],
				"thumbnail": {
					"width": 1920,
					"height": 1080,
					"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325.jpeg",
					"childImages": [
						{
							"width": 400,
							"height": 225,
							"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325_400x225.jpeg"
						},
						{
							"width": 1200,
							"height": 675,
							"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325_1200x675.jpeg"
						}
					]
				},
				"isAccessible": true,
				"videoAttachments": [
					"wAjrwHU7Fi"
				],
				"audioAttachments": [],
				"pictureAttachments": []
			},
			{
				"id": "iKl5zXTlaP",
				"guid": "iKl5zXTlaP",
				"title": "TL: AutoGPT, Windows handheld mode, WD hack + more!",
				"text": "<p><strong>NEWS SOURCES:</strong></p><p><br /></p><p>PROMPT INCEPTION</p><p>AutoGPT</p><p><a href=\"https://www.digitaltrends.com/computing/what-is-auto-gpt/\">https://www.digitaltrends.com/computing/what-is-auto-gpt/</a></p><p><a href=\"https://github.com/Torantulino/Auto-GPT\">https://github.com/Torantulino/Auto-GPT</a></p><p><a href=\"https://www.lesswrong.com/posts/566kBoPi76t8KAkoD/on-autogpt#:~:text=The%20concept%20works%20like%20this%3A\">https://www.lesswrong.com/posts/566kBoPi76t8KAkoD/on-autogpt#:~:text=The%20concept%20works%20like%20this%3A</a></p><p><a href=\"https://github.com/trending\">https://github.com/trending</a></p><p>Microsoft Jarvis <a href=\"https://github.com/microsoft/JARVIS\">https://github.com/microsoft/JARVIS</a></p><p>Sim study <a href=\"https://arxiv.org/abs/2304.03442\">https://arxiv.org/abs/2304.03442</a></p><p><a href=\"https://arxiv.org/pdf/2304.03442.pdf\">https://arxiv.org/pdf/2304.03442.pdf</a></p><p>party <a href=\"https://lmg.gg/bmG9w\">https://lmg.gg/bmG9w</a></p><p>Voice cloning scams are effing sh** up</p><p><a href=\"https://www.wkyt.com/2023/04/10/ive-got-your-daughter-mom-warns-terrifying-ai-voice-cloning-scam-that-faked-kidnapping\">https://www.wkyt.com/2023/04/10/ive-got-your-daughter-mom-warns-terrifying-ai-voice-cloning-scam-that-faked-kidnapping</a></p><p><a href=\"https://www.tiktok.com/@bethroyce/video/7207863411902778666\">https://www.tiktok.com/@bethroyce/video/7207863411902778666</a></p><p>some banks use voices to log in <a href=\"https://www.vice.com/en/article/dy7axa/how-i-broke-into-a-bank-account-with-an-ai-generated-voice\">https://www.vice.com/en/article/dy7axa/how-i-broke-into-a-bank-account-with-an-ai-generated-voice</a> </p><p>Dolly 2.0 will make AI tech more accessible <a href=\"https://arstechnica.com/information-technology/2023/04/a-really-big-deal-dolly-is-a-free-open-source-chatgpt-style-ai-model/\">https://arstechnica.com/information-technology/2023/04/a-really-big-deal-dolly-is-a-free-open-source-chatgpt-style-ai-model/</a></p><p>US Commerce Dept working on AI safety rules <a href=\"https://www.axios.com/2023/04/11/ai-safety-rules-commerce-department-artificial-intelligence\">https://www.axios.com/2023/04/11/ai-safety-rules-commerce-department-artificial-intelligence</a></p><p>NTIA accepting comments <a href=\"https://ntia.gov/issues/artificial-intelligence/request-for-comments\">https://ntia.gov/issues/artificial-intelligence/request-for-comments</a></p><p><br /></p><p>HAND-SIZED WINDOW</p><p>Microsoft experimenting with a Steam Deck-friendly “handheld mode” for Windows</p><p><a href=\"https://twitter.com/_h0x0d_/status/1646339289230483458\">https://twitter.com/_h0x0d_/status/1646339289230483458</a></p><p><a href=\"https://www.theverge.com/2023/4/13/23681492/microsoft-windows-handheld-mode-gaming-xbox-steam-deck\">https://www.theverge.com/2023/4/13/23681492/microsoft-windows-handheld-mode-gaming-xbox-steam-deck</a></p><p>or is it for Steam Deck rivals?</p><p><a href=\"https://www.pcworld.com/article/1785380/of-course-microsoft-is-working-on-windows-handheld-mode-for-steam-deck-rivals.html\">https://www.pcworld.com/article/1785380/of-course-microsoft-is-working-on-windows-handheld-mode-for-steam-deck-rivals.html</a></p><p>Windows 11 is getting a new “Presence Mode”</p><p><a href=\"https://www.thurrott.com/windows/281855/microsoft-starts-testing-presence-sensing-privacy-settings-on-windows-11\">https://www.thurrott.com/windows/281855/microsoft-starts-testing-presence-sensing-privacy-settings-on-windows-11</a></p><p>Will allow you to choose whether applications can detect if you are interacting with your device</p><p><a href=\"https://www.xda-developers.com/windows-11-beta-apps-track-presense-privacy-page/\">https://www.xda-developers.com/windows-11-beta-apps-track-presense-privacy-page/</a></p><p><a href=\"https://www.windowscentral.com/software-apps/windows-11/windows-11-apps-will-soon-be-able-to-detect-when-you-are-present-in-front-of-your-pc\">https://www.windowscentral.com/software-apps/windows-11/windows-11-apps-will-soon-be-able-to-detect-when-you-are-present-in-front-of-your-pc</a></p><p><br /></p><p>WESTERN PITIFUL</p><p>Hackers reportedly holding Western Digital data hostage</p><p><a href=\"https://techcrunch.com/2023/04/13/hackers-claim-vast-access-to-western-digital-systems/\">https://techcrunch.com/2023/04/13/hackers-claim-vast-access-to-western-digital-systems/</a></p><p>original statement <a href=\"https://www.businesswire.com/news/home/20230402005076/en/Western-Digital-Provides-Information-on-Network-Security-Incident\">https://www.businesswire.com/news/home/20230402005076/en/Western-Digital-Provides-Information-on-Network-Security-Incident</a></p><p><a href=\"https://www.pcmag.com/news/after-10-days-western-digitals-my-cloud-finally-restored-following-hack\">https://www.pcmag.com/news/after-10-days-western-digitals-my-cloud-finally-restored-following-hack</a></p><p>if WD doesn’t pay, hackers will publish data on website of “professional” hacking group <a href=\"https://lmg.gg/HR4lt\">https://lmg.gg/HR4lt</a></p><p><br /></p><p>QUICK BITS</p><p><br /></p><p>SOWING DISCORD</p><p>National Guard member allegedly leaked classified documents on Discord</p><p><a href=\"https://www.nbcnews.com/politics/national-security/us-officials-identify-leaked-classified-documents-suspect-21-year-old-rcna79577?cid=ed_npd_bn_tw_bn\">https://www.nbcnews.com/politics/national-security/us-officials-identify-leaked-classified-documents-suspect-21-year-old-rcna79577?cid=ed_npd_bn_tw_bn</a></p><p><a href=\"https://www.youtube.com/watch?v=Dc8wbH6juG8\">https://www.youtube.com/watch?v=Dc8wbH6juG8</a></p><p><a href=\"https://www.washingtonpost.com/national-security/2023/04/12/discord-leaked-documents/\">https://www.washingtonpost.com/national-security/2023/04/12/discord-leaked-documents/</a></p><p><br /></p><p>IT TURNS RAY TRACING ON, OR ELSE…</p><p>Nvidia: 83% of RTX 40-series gamers enable ray tracing, but… what does that mean?</p><p><a href=\"https://www.pcgamer.com/nvidia-says-83-of-rtx-40-series-gamers-enable-ray-tracing/\">https://www.pcgamer.com/nvidia-says-83-of-rtx-40-series-gamers-enable-ray-tracing/</a></p><p><a href=\"https://arstechnica.com/gadgets/2023/04/nvidia-proud-that-83-of-people-with-1200-ray-tracing-gpus-actually-use-rtx/\">https://arstechnica.com/gadgets/2023/04/nvidia-proud-that-83-of-people-with-1200-ray-tracing-gpus-actually-use-rtx/</a></p><p><a href=\"https://www.reddit.com/r/hardware/comments/12ldh21/comment/jg6u2wg/?utm_source=reddit&amp;utm_medium=web2x&amp;context=3\">https://www.reddit.com/r/hardware/comments/12ldh21/comment/jg6u2wg/?utm_source=reddit&amp;utm_medium=web2x&amp;context=3</a></p><p><br /></p><p>THE SAG AWARDS</p><p>SURPRISE! GPU sag can kill your graphics card</p><p><a href=\"https://www.tomshardware.com/news/rtx-2080-ti-dying-from-gpu-sag\">https://www.tomshardware.com/news/rtx-2080-ti-dying-from-gpu-sag</a></p><p>German repair ubermensch KrisFix claims that 2080 Ti’s commonly die late in life due to being so thick</p><p><a href=\"https://youtu.be/m3oM3huKl8c\">https://youtu.be/m3oM3huKl8c</a></p><p>I CAN’T BELIEVE that Nvidia engineers didn’t fucking study how torque works</p><p><a href=\"https://www.pcgamer.com/dont-let-your-chonk-graphics-card-sag-or-it-might-actually-die/\">https://www.pcgamer.com/dont-let-your-chonk-graphics-card-sag-or-it-might-actually-die/</a></p><p><br /></p><p>UH OH, HOW MONEY WORK?</p><p>Twitter Subscriptions</p><p><a href=\"https://www.engadget.com/twitter-replaces-super-follows-with-subscriptions-203711756.html\">https://www.engadget.com/twitter-replaces-super-follows-with-subscriptions-203711756.html</a></p><p><a href=\"https://twitter.com/elonmusk/status/1646560815003373568\">https://twitter.com/elonmusk/status/1646560815003373568</a></p><p><br /></p><p>FLY ME TO THEM MOONS</p><p>Europe’s ESA launches rocket to Jupiter</p><p><a href=\"https://news.sky.com/story/european-space-agencys-juice-mission-launches-to-search-for-life-on-jupiters-moons-12855869\">https://news.sky.com/story/european-space-agencys-juice-mission-launches-to-search-for-life-on-jupiters-moons-12855869</a></p><p>postponed <a href=\"https://www.telegraph.co.uk/world-news/2023/04/13/juice-rocket-launch-jupiter-european-space-agency-watch/\">https://www.telegraph.co.uk/world-news/2023/04/13/juice-rocket-launch-jupiter-european-space-agency-watch/</a></p><p><a href=\"https://www.esa.int/Science_Exploration/Space_Science/Juice/ESA_s_Juice_lifts_off_on_quest_to_discover_secrets_of_Jupiter_s_icy_moons\">https://www.esa.int/Science_Exploration/Space_Science/Juice/ESA_s_Juice_lifts_off_on_quest_to_discover_secrets_of_Jupiter_s_icy_moons</a></p>",
				"type": "blogPost",
				"channel": {
					"id": "6413534d88c13c181c3e2809",
					"creator": "59f94c0bdd241b70349eb72b",
					"title": "TechLinked",
					"urlname": "techlinked",
					"about": "News about tech + gaming culture, delivered thrice weekly.\n\nWe're also doing long-form video essays now, apparently. \n\nThe TalkLinked talk show/podcast will probably come back at some point, too!\n\nWriters: Riley Murdock, Jon Martin, James Strieb",
					"order": 2,
					"cover": null,
					"card": null,
					"icon": {
						"width": 88,
						"height": 88,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/6413534d88c13c181c3e2809/955526950207988_1678988110287.jpeg",
						"childImages": []
					}
				},
				"tags": [],
				"attachmentOrder": [
					"kx3hhG4yjR"
				],
				"releaseDate": "2023-04-15T06:41:00.041Z",
				"likes": 182,
				"dislikes": 0,
				"score": 182,
				"comments": 18,
				"creator": {
					"id": "59f94c0bdd241b70349eb72b",
					"owner": {
						"id": "59f94c0bdd241b70349eb723",
						"username": "Linus"
					},
					"title": "LinusTechTips",
					"urlname": "linustechtips",
					"description": "We make entertaining videos about technology, including tech reviews, showcases and other content.",
					"about": "# We're LinusTechTips\nWe make videos and stuff, cool eh?",
					"category": {
						"id": "59f94c0bdd241b70349eb727",
						"title": "Technology"
					},
					"cover": {
						"width": 1990,
						"height": 519,
						"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867.jpeg",
						"childImages": [
							{
								"width": 1245,
								"height": 325,
								"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867_1245x325.jpeg"
							}
						]
					},
					"icon": {
						"width": 600,
						"height": 600,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205.jpeg",
						"childImages": [
							{
								"width": 250,
								"height": 250,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_250x250.jpeg"
							},
							{
								"width": 100,
								"height": 100,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_100x100.jpeg"
							}
						]
					},
					"liveStream": {
						"id": "5c13f3c006f1be15e08e05c0",
						"title": "I Give Up - WAN Show April 14, 2023",
						"description": "<p>JumpCloud offers an Open Directory Platform that makes it possible to unify your technology stack across identity, access, and device management. Learn more here: <a href=\"https://lmg.gg/JumpCloud\" rel=\"noopener noreferrer\" target=\"_blank\">https://lmg.gg/JumpCloud</a></p><p>Check out Goliath today and save 20% at <a href=\"https://lmg.gg/Goliath-Technologies\" rel=\"noopener noreferrer\" target=\"_blank\">https://lmg.gg/Goliath-Technologies</a></p><p>Buy a Seasonic Prime TX 1000W PSU:<a href=\"https://geni.us/aryiquT\" rel=\"noopener noreferrer\" target=\"_blank\"> https://geni.us/aryiquT</a></p><p><br></p><p>Purchases made through some store links may provide some compensation to Linus Media Group.</p><p><br></p><p>Podcast Download: TBD</p>",
						"thumbnail": {
							"width": 1920,
							"height": 1080,
							"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325.jpeg",
							"childImages": [
								{
									"width": 400,
									"height": 225,
									"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325_400x225.jpeg"
								},
								{
									"width": 1200,
									"height": 675,
									"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325_1200x675.jpeg"
								}
							]
						},
						"owner": "59f94c0bdd241b70349eb72b",
						"channel": "63fe42c309e691e4e36de93d",
						"streamPath": "/api/video/v1/us-east-1.758417551536.channel.yKkxur4ukc0B.m3u8",
						"offline": {
							"title": "Offline",
							"description": "We're offline for now – please check back later!",
							"thumbnail": {
								"width": 1920,
								"height": 1080,
								"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026.jpeg",
								"childImages": [
									{
										"width": 400,
										"height": 225,
										"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_400x225.jpeg"
									},
									{
										"width": 1200,
										"height": 675,
										"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_1200x675.jpeg"
									}
								]
							}
						}
					},
					"subscriptionPlans": [
						{
							"id": "5d48d0306825b5780db93d07",
							"title": "LTT Supporter",
							"description": "- 2 Exclusives Per Week (Meet the Team, Extras, Behind the Scenes) \n- Exclusive livestreams\n- Save $10 by purchasing an annual subscription\n- Our gratitude for your support",
							"price": "5.00",
							"priceYearly": "50.00",
							"currency": "usd",
							"logo": null,
							"interval": "month",
							"featured": true,
							"allowGrandfatheredAccess": false,
							"discordServers": [],
							"discordRoles": []
						},
						{
							"id": "5e0ba6ac14e2590f760a0f0f",
							"title": "LTT Supporter Plus",
							"description": "- 4K Bitrate Streaming\n- 2 Exclusives Per Week (Meet the Team, Extras, Behind the Scenes) \n- Exclusive livestreams\n- Save $20 by purchasing an annual subscription\n- Our gratitude for your support",
							"price": "10.00",
							"priceYearly": "100.00",
							"currency": "usd",
							"logo": null,
							"interval": "month",
							"featured": true,
							"allowGrandfatheredAccess": false,
							"discordServers": [],
							"discordRoles": []
						}
					],
					"discoverable": true,
					"subscriberCountDisplay": "total",
					"incomeDisplay": false,
					"defaultChannel": "63fe42c309e691e4e36de93d",
					"channels": [
						"63fe42c309e691e4e36de93d",
						"6413534d88c13c181c3e2809",
						"64135da7ce81077a8480c679",
						"64135e27c773b27ff22c97eb",
						"64135e901ebaee42e258eb0b",
						"64135ed078d6262f717341b7",
						"64135f82fc76ab7f9fbdc876",
						"6413623f5b12cca228a28e78"
					],
					"card": {
						"width": 375,
						"height": 500,
						"path": "https://pbs.floatplane.com/creator_card/59f94c0bdd241b70349eb72b/281467946609369_1551250329871.jpeg",
						"childImages": [
							{
								"width": 300,
								"height": 400,
								"path": "https://pbs.floatplane.com/creator_card/59f94c0bdd241b70349eb72b/281467946609369_1551250329871_300x400.jpeg"
							}
						]
					}
				},
				"wasReleasedSilently": false,
				"metadata": {
					"hasVideo": true,
					"videoCount": 1,
					"videoDuration": 482,
					"hasAudio": false,
					"audioCount": 0,
					"audioDuration": 0,
					"hasPicture": false,
					"pictureCount": 0,
					"isFeatured": false,
					"hasGallery": false,
					"galleryCount": 0
				},
				"galleryAttachments": [],
				"thumbnail": {
					"width": 1920,
					"height": 1080,
					"path": "https://pbs.floatplane.com/blogPost_thumbnails/iKl5zXTlaP/096118745514196_1681526329366.jpeg",
					"childImages": [
						{
							"width": 400,
							"height": 225,
							"path": "https://pbs.floatplane.com/blogPost_thumbnails/iKl5zXTlaP/096118745514196_1681526329366_400x225.jpeg"
						},
						{
							"width": 1200,
							"height": 675,
							"path": "https://pbs.floatplane.com/blogPost_thumbnails/iKl5zXTlaP/096118745514196_1681526329366_1200x675.jpeg"
						}
					]
				},
				"isAccessible": true,
				"videoAttachments": [
					"kx3hhG4yjR"
				],
				"audioAttachments": [],
				"pictureAttachments": []
			},
			{
				"id": "TLRruUT6zC",
				"guid": "TLRruUT6zC",
				"title": "MA: Living with ONLY the Apple Watch for a Week",
				"text": "<p>Apple has offered cellular connectivity on the Apple Watch for almost six years now. But it’s a hard option to justify. So to find out who it’s for, Jonathan use one as his ONLY mobile device for an entire week.</p>",
				"type": "blogPost",
				"channel": {
					"id": "64135e901ebaee42e258eb0b",
					"creator": "59f94c0bdd241b70349eb72b",
					"title": "Mac Address",
					"urlname": "macaddress",
					"about": "The exploration of all things Apple, from iPhones underwater to full iClouds in the sky. We want to be the channel that you come to first for an unexpected viewpoint about the devices you love.",
					"order": 4,
					"cover": null,
					"card": null,
					"icon": {
						"width": 88,
						"height": 88,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/64135e901ebaee42e258eb0b/979475909700348_1678990993114.jpeg",
						"childImages": []
					}
				},
				"tags": [
					"MA"
				],
				"attachmentOrder": [
					"PYL44Jllyb"
				],
				"releaseDate": "2023-04-15T00:44:00.052Z",
				"likes": 299,
				"dislikes": 2,
				"score": 297,
				"comments": 70,
				"creator": {
					"id": "59f94c0bdd241b70349eb72b",
					"owner": {
						"id": "59f94c0bdd241b70349eb723",
						"username": "Linus"
					},
					"title": "LinusTechTips",
					"urlname": "linustechtips",
					"description": "We make entertaining videos about technology, including tech reviews, showcases and other content.",
					"about": "# We're LinusTechTips\nWe make videos and stuff, cool eh?",
					"category": {
						"id": "59f94c0bdd241b70349eb727",
						"title": "Technology"
					},
					"cover": {
						"width": 1990,
						"height": 519,
						"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867.jpeg",
						"childImages": [
							{
								"width": 1245,
								"height": 325,
								"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867_1245x325.jpeg"
							}
						]
					},
					"icon": {
						"width": 600,
						"height": 600,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205.jpeg",
						"childImages": [
							{
								"width": 250,
								"height": 250,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_250x250.jpeg"
							},
							{
								"width": 100,
								"height": 100,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_100x100.jpeg"
							}
						]
					},
					"liveStream": {
						"id": "5c13f3c006f1be15e08e05c0",
						"title": "I Give Up - WAN Show April 14, 2023",
						"description": "<p>JumpCloud offers an Open Directory Platform that makes it possible to unify your technology stack across identity, access, and device management. Learn more here: <a href=\"https://lmg.gg/JumpCloud\" rel=\"noopener noreferrer\" target=\"_blank\">https://lmg.gg/JumpCloud</a></p><p>Check out Goliath today and save 20% at <a href=\"https://lmg.gg/Goliath-Technologies\" rel=\"noopener noreferrer\" target=\"_blank\">https://lmg.gg/Goliath-Technologies</a></p><p>Buy a Seasonic Prime TX 1000W PSU:<a href=\"https://geni.us/aryiquT\" rel=\"noopener noreferrer\" target=\"_blank\"> https://geni.us/aryiquT</a></p><p><br></p><p>Purchases made through some store links may provide some compensation to Linus Media Group.</p><p><br></p><p>Podcast Download: TBD</p>",
						"thumbnail": {
							"width": 1920,
							"height": 1080,
							"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325.jpeg",
							"childImages": [
								{
									"width": 400,
									"height": 225,
									"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325_400x225.jpeg"
								},
								{
									"width": 1200,
									"height": 675,
									"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325_1200x675.jpeg"
								}
							]
						},
						"owner": "59f94c0bdd241b70349eb72b",
						"channel": "63fe42c309e691e4e36de93d",
						"streamPath": "/api/video/v1/us-east-1.758417551536.channel.yKkxur4ukc0B.m3u8",
						"offline": {
							"title": "Offline",
							"description": "We're offline for now – please check back later!",
							"thumbnail": {
								"width": 1920,
								"height": 1080,
								"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026.jpeg",
								"childImages": [
									{
										"width": 400,
										"height": 225,
										"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_400x225.jpeg"
									},
									{
										"width": 1200,
										"height": 675,
										"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_1200x675.jpeg"
									}
								]
							}
						}
					},
					"subscriptionPlans": [
						{
							"id": "5d48d0306825b5780db93d07",
							"title": "LTT Supporter",
							"description": "- 2 Exclusives Per Week (Meet the Team, Extras, Behind the Scenes) \n- Exclusive livestreams\n- Save $10 by purchasing an annual subscription\n- Our gratitude for your support",
							"price": "5.00",
							"priceYearly": "50.00",
							"currency": "usd",
							"logo": null,
							"interval": "month",
							"featured": true,
							"allowGrandfatheredAccess": false,
							"discordServers": [],
							"discordRoles": []
						},
						{
							"id": "5e0ba6ac14e2590f760a0f0f",
							"title": "LTT Supporter Plus",
							"description": "- 4K Bitrate Streaming\n- 2 Exclusives Per Week (Meet the Team, Extras, Behind the Scenes) \n- Exclusive livestreams\n- Save $20 by purchasing an annual subscription\n- Our gratitude for your support",
							"price": "10.00",
							"priceYearly": "100.00",
							"currency": "usd",
							"logo": null,
							"interval": "month",
							"featured": true,
							"allowGrandfatheredAccess": false,
							"discordServers": [],
							"discordRoles": []
						}
					],
					"discoverable": true,
					"subscriberCountDisplay": "total",
					"incomeDisplay": false,
					"defaultChannel": "63fe42c309e691e4e36de93d",
					"channels": [
						"63fe42c309e691e4e36de93d",
						"6413534d88c13c181c3e2809",
						"64135da7ce81077a8480c679",
						"64135e27c773b27ff22c97eb",
						"64135e901ebaee42e258eb0b",
						"64135ed078d6262f717341b7",
						"64135f82fc76ab7f9fbdc876",
						"6413623f5b12cca228a28e78"
					],
					"card": {
						"width": 375,
						"height": 500,
						"path": "https://pbs.floatplane.com/creator_card/59f94c0bdd241b70349eb72b/281467946609369_1551250329871.jpeg",
						"childImages": [
							{
								"width": 300,
								"height": 400,
								"path": "https://pbs.floatplane.com/creator_card/59f94c0bdd241b70349eb72b/281467946609369_1551250329871_300x400.jpeg"
							}
						]
					}
				},
				"wasReleasedSilently": false,
				"metadata": {
					"hasVideo": true,
					"videoCount": 1,
					"videoDuration": 444,
					"hasAudio": false,
					"audioCount": 0,
					"audioDuration": 0,
					"hasPicture": false,
					"pictureCount": 0,
					"isFeatured": false,
					"hasGallery": false,
					"galleryCount": 0
				},
				"galleryAttachments": [],
				"thumbnail": {
					"width": 1920,
					"height": 1080,
					"path": "https://pbs.floatplane.com/blogPost_thumbnails/TLRruUT6zC/096193645801244_1681519248143.jpeg",
					"childImages": [
						{
							"width": 400,
							"height": 225,
							"path": "https://pbs.floatplane.com/blogPost_thumbnails/TLRruUT6zC/096193645801244_1681519248143_400x225.jpeg"
						},
						{
							"width": 1200,
							"height": 675,
							"path": "https://pbs.floatplane.com/blogPost_thumbnails/TLRruUT6zC/096193645801244_1681519248143_1200x675.jpeg"
						}
					]
				},
				"isAccessible": true,
				"videoAttachments": [
					"PYL44Jllyb"
				],
				"audioAttachments": [],
				"pictureAttachments": []
			},
			{
				"id": "qlYDlxNymw",
				"guid": "qlYDlxNymw",
				"title": "FP Exclusive: Working for LMG Full Interviews (Pt. 1)",
				"text": "<p>Here's the first batch of FULL INTERVIEWS from the 2023 version of \"What's it Like to Work for LMG\". A new batch is coming next week!</p>",
				"type": "blogPost",
				"channel": {
					"id": "6413623f5b12cca228a28e78",
					"creator": "59f94c0bdd241b70349eb72b",
					"title": "FP Exclusive",
					"urlname": "fpexclusive",
					"about": "wow... so empty",
					"order": 1,
					"cover": null,
					"card": null,
					"icon": {
						"width": 720,
						"height": 720,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/6413623f5b12cca228a28e78/069457536750544_1678991936484.jpeg",
						"childImages": [
							{
								"width": 100,
								"height": 100,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/6413623f5b12cca228a28e78/069457536750544_1678991936484_100x100.jpeg"
							},
							{
								"width": 250,
								"height": 250,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/6413623f5b12cca228a28e78/069457536750544_1678991936484_250x250.jpeg"
							}
						]
					}
				},
				"tags": [],
				"attachmentOrder": [
					"sCneVgX28r",
					"Yiq7ukwX5Q",
					"gAoWs7L6oz"
				],
				"releaseDate": "2023-04-15T00:08:00.062Z",
				"likes": 532,
				"dislikes": 1,
				"score": 531,
				"comments": 108,
				"creator": {
					"id": "59f94c0bdd241b70349eb72b",
					"owner": {
						"id": "59f94c0bdd241b70349eb723",
						"username": "Linus"
					},
					"title": "LinusTechTips",
					"urlname": "linustechtips",
					"description": "We make entertaining videos about technology, including tech reviews, showcases and other content.",
					"about": "# We're LinusTechTips\nWe make videos and stuff, cool eh?",
					"category": {
						"id": "59f94c0bdd241b70349eb727",
						"title": "Technology"
					},
					"cover": {
						"width": 1990,
						"height": 519,
						"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867.jpeg",
						"childImages": [
							{
								"width": 1245,
								"height": 325,
								"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867_1245x325.jpeg"
							}
						]
					},
					"icon": {
						"width": 600,
						"height": 600,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205.jpeg",
						"childImages": [
							{
								"width": 250,
								"height": 250,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_250x250.jpeg"
							},
							{
								"width": 100,
								"height": 100,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_100x100.jpeg"
							}
						]
					},
					"liveStream": {
						"id": "5c13f3c006f1be15e08e05c0",
						"title": "I Give Up - WAN Show April 14, 2023",
						"description": "<p>JumpCloud offers an Open Directory Platform that makes it possible to unify your technology stack across identity, access, and device management. Learn more here: <a href=\"https://lmg.gg/JumpCloud\" rel=\"noopener noreferrer\" target=\"_blank\">https://lmg.gg/JumpCloud</a></p><p>Check out Goliath today and save 20% at <a href=\"https://lmg.gg/Goliath-Technologies\" rel=\"noopener noreferrer\" target=\"_blank\">https://lmg.gg/Goliath-Technologies</a></p><p>Buy a Seasonic Prime TX 1000W PSU:<a href=\"https://geni.us/aryiquT\" rel=\"noopener noreferrer\" target=\"_blank\"> https://geni.us/aryiquT</a></p><p><br></p><p>Purchases made through some store links may provide some compensation to Linus Media Group.</p><p><br></p><p>Podcast Download: TBD</p>",
						"thumbnail": {
							"width": 1920,
							"height": 1080,
							"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325.jpeg",
							"childImages": [
								{
									"width": 400,
									"height": 225,
									"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325_400x225.jpeg"
								},
								{
									"width": 1200,
									"height": 675,
									"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325_1200x675.jpeg"
								}
							]
						},
						"owner": "59f94c0bdd241b70349eb72b",
						"channel": "63fe42c309e691e4e36de93d",
						"streamPath": "/api/video/v1/us-east-1.758417551536.channel.yKkxur4ukc0B.m3u8",
						"offline": {
							"title": "Offline",
							"description": "We're offline for now – please check back later!",
							"thumbnail": {
								"width": 1920,
								"height": 1080,
								"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026.jpeg",
								"childImages": [
									{
										"width": 400,
										"height": 225,
										"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_400x225.jpeg"
									},
									{
										"width": 1200,
										"height": 675,
										"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_1200x675.jpeg"
									}
								]
							}
						}
					},
					"subscriptionPlans": [
						{
							"id": "5d48d0306825b5780db93d07",
							"title": "LTT Supporter",
							"description": "- 2 Exclusives Per Week (Meet the Team, Extras, Behind the Scenes) \n- Exclusive livestreams\n- Save $10 by purchasing an annual subscription\n- Our gratitude for your support",
							"price": "5.00",
							"priceYearly": "50.00",
							"currency": "usd",
							"logo": null,
							"interval": "month",
							"featured": true,
							"allowGrandfatheredAccess": false,
							"discordServers": [],
							"discordRoles": []
						},
						{
							"id": "5e0ba6ac14e2590f760a0f0f",
							"title": "LTT Supporter Plus",
							"description": "- 4K Bitrate Streaming\n- 2 Exclusives Per Week (Meet the Team, Extras, Behind the Scenes) \n- Exclusive livestreams\n- Save $20 by purchasing an annual subscription\n- Our gratitude for your support",
							"price": "10.00",
							"priceYearly": "100.00",
							"currency": "usd",
							"logo": null,
							"interval": "month",
							"featured": true,
							"allowGrandfatheredAccess": false,
							"discordServers": [],
							"discordRoles": []
						}
					],
					"discoverable": true,
					"subscriberCountDisplay": "total",
					"incomeDisplay": false,
					"defaultChannel": "63fe42c309e691e4e36de93d",
					"channels": [
						"63fe42c309e691e4e36de93d",
						"6413534d88c13c181c3e2809",
						"64135da7ce81077a8480c679",
						"64135e27c773b27ff22c97eb",
						"64135e901ebaee42e258eb0b",
						"64135ed078d6262f717341b7",
						"64135f82fc76ab7f9fbdc876",
						"6413623f5b12cca228a28e78"
					],
					"card": {
						"width": 375,
						"height": 500,
						"path": "https://pbs.floatplane.com/creator_card/59f94c0bdd241b70349eb72b/281467946609369_1551250329871.jpeg",
						"childImages": [
							{
								"width": 300,
								"height": 400,
								"path": "https://pbs.floatplane.com/creator_card/59f94c0bdd241b70349eb72b/281467946609369_1551250329871_300x400.jpeg"
							}
						]
					}
				},
				"wasReleasedSilently": false,
				"metadata": {
					"hasVideo": true,
					"videoCount": 3,
					"videoDuration": 2134,
					"hasAudio": false,
					"audioCount": 0,
					"audioDuration": 0,
					"hasPicture": false,
					"pictureCount": 0,
					"isFeatured": false,
					"hasGallery": false,
					"galleryCount": 0
				},
				"galleryAttachments": [],
				"thumbnail": {
					"width": 1920,
					"height": 1080,
					"path": "https://pbs.floatplane.com/blogPost_thumbnails/qlYDlxNymw/915562739196985_1681518010070.jpeg",
					"childImages": [
						{
							"width": 400,
							"height": 225,
							"path": "https://pbs.floatplane.com/blogPost_thumbnails/qlYDlxNymw/915562739196985_1681518010070_400x225.jpeg"
						},
						{
							"width": 1200,
							"height": 675,
							"path": "https://pbs.floatplane.com/blogPost_thumbnails/qlYDlxNymw/915562739196985_1681518010070_1200x675.jpeg"
						}
					]
				},
				"isAccessible": true,
				"videoAttachments": [
					"Yiq7ukwX5Q",
					"gAoWs7L6oz",
					"sCneVgX28r"
				],
				"audioAttachments": [],
				"pictureAttachments": []
			},
			{
				"id": "EZBOOhcLO0",
				"guid": "EZBOOhcLO0",
				"title": "What is it like to work for Linus? - 2023 Update",
				"text": "<p>This video was produced completely without any oversight by LMG management. Good luck everyone.</p><p><br /></p>",
				"type": "blogPost",
				"channel": {
					"id": "63fe42c309e691e4e36de93d",
					"creator": "59f94c0bdd241b70349eb72b",
					"title": "Linus Tech Tips",
					"urlname": "main",
					"about": "# We're LinusTechTips\nWe make videos and stuff, cool eh?",
					"order": 0,
					"cover": null,
					"card": null,
					"icon": {
						"width": 600,
						"height": 600,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205.jpeg",
						"childImages": [
							{
								"width": 250,
								"height": 250,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_250x250.jpeg"
							},
							{
								"width": 100,
								"height": 100,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_100x100.jpeg"
							}
						]
					}
				},
				"tags": [],
				"attachmentOrder": [
					"qJq8gK3RtW"
				],
				"releaseDate": "2023-04-14T23:45:00.037Z",
				"likes": 802,
				"dislikes": 2,
				"score": 800,
				"comments": 146,
				"creator": {
					"id": "59f94c0bdd241b70349eb72b",
					"owner": {
						"id": "59f94c0bdd241b70349eb723",
						"username": "Linus"
					},
					"title": "LinusTechTips",
					"urlname": "linustechtips",
					"description": "We make entertaining videos about technology, including tech reviews, showcases and other content.",
					"about": "# We're LinusTechTips\nWe make videos and stuff, cool eh?",
					"category": {
						"id": "59f94c0bdd241b70349eb727",
						"title": "Technology"
					},
					"cover": {
						"width": 1990,
						"height": 519,
						"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867.jpeg",
						"childImages": [
							{
								"width": 1245,
								"height": 325,
								"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867_1245x325.jpeg"
							}
						]
					},
					"icon": {
						"width": 600,
						"height": 600,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205.jpeg",
						"childImages": [
							{
								"width": 250,
								"height": 250,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_250x250.jpeg"
							},
							{
								"width": 100,
								"height": 100,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_100x100.jpeg"
							}
						]
					},
					"liveStream": {
						"id": "5c13f3c006f1be15e08e05c0",
						"title": "I Give Up - WAN Show April 14, 2023",
						"description": "<p>JumpCloud offers an Open Directory Platform that makes it possible to unify your technology stack across identity, access, and device management. Learn more here: <a href=\"https://lmg.gg/JumpCloud\" rel=\"noopener noreferrer\" target=\"_blank\">https://lmg.gg/JumpCloud</a></p><p>Check out Goliath today and save 20% at <a href=\"https://lmg.gg/Goliath-Technologies\" rel=\"noopener noreferrer\" target=\"_blank\">https://lmg.gg/Goliath-Technologies</a></p><p>Buy a Seasonic Prime TX 1000W PSU:<a href=\"https://geni.us/aryiquT\" rel=\"noopener noreferrer\" target=\"_blank\"> https://geni.us/aryiquT</a></p><p><br></p><p>Purchases made through some store links may provide some compensation to Linus Media Group.</p><p><br></p><p>Podcast Download: TBD</p>",
						"thumbnail": {
							"width": 1920,
							"height": 1080,
							"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325.jpeg",
							"childImages": [
								{
									"width": 400,
									"height": 225,
									"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325_400x225.jpeg"
								},
								{
									"width": 1200,
									"height": 675,
									"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325_1200x675.jpeg"
								}
							]
						},
						"owner": "59f94c0bdd241b70349eb72b",
						"channel": "63fe42c309e691e4e36de93d",
						"streamPath": "/api/video/v1/us-east-1.758417551536.channel.yKkxur4ukc0B.m3u8",
						"offline": {
							"title": "Offline",
							"description": "We're offline for now – please check back later!",
							"thumbnail": {
								"width": 1920,
								"height": 1080,
								"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026.jpeg",
								"childImages": [
									{
										"width": 400,
										"height": 225,
										"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_400x225.jpeg"
									},
									{
										"width": 1200,
										"height": 675,
										"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_1200x675.jpeg"
									}
								]
							}
						}
					},
					"subscriptionPlans": [
						{
							"id": "5d48d0306825b5780db93d07",
							"title": "LTT Supporter",
							"description": "- 2 Exclusives Per Week (Meet the Team, Extras, Behind the Scenes) \n- Exclusive livestreams\n- Save $10 by purchasing an annual subscription\n- Our gratitude for your support",
							"price": "5.00",
							"priceYearly": "50.00",
							"currency": "usd",
							"logo": null,
							"interval": "month",
							"featured": true,
							"allowGrandfatheredAccess": false,
							"discordServers": [],
							"discordRoles": []
						},
						{
							"id": "5e0ba6ac14e2590f760a0f0f",
							"title": "LTT Supporter Plus",
							"description": "- 4K Bitrate Streaming\n- 2 Exclusives Per Week (Meet the Team, Extras, Behind the Scenes) \n- Exclusive livestreams\n- Save $20 by purchasing an annual subscription\n- Our gratitude for your support",
							"price": "10.00",
							"priceYearly": "100.00",
							"currency": "usd",
							"logo": null,
							"interval": "month",
							"featured": true,
							"allowGrandfatheredAccess": false,
							"discordServers": [],
							"discordRoles": []
						}
					],
					"discoverable": true,
					"subscriberCountDisplay": "total",
					"incomeDisplay": false,
					"defaultChannel": "63fe42c309e691e4e36de93d",
					"channels": [
						"63fe42c309e691e4e36de93d",
						"6413534d88c13c181c3e2809",
						"64135da7ce81077a8480c679",
						"64135e27c773b27ff22c97eb",
						"64135e901ebaee42e258eb0b",
						"64135ed078d6262f717341b7",
						"64135f82fc76ab7f9fbdc876",
						"6413623f5b12cca228a28e78"
					],
					"card": {
						"width": 375,
						"height": 500,
						"path": "https://pbs.floatplane.com/creator_card/59f94c0bdd241b70349eb72b/281467946609369_1551250329871.jpeg",
						"childImages": [
							{
								"width": 300,
								"height": 400,
								"path": "https://pbs.floatplane.com/creator_card/59f94c0bdd241b70349eb72b/281467946609369_1551250329871_300x400.jpeg"
							}
						]
					}
				},
				"wasReleasedSilently": false,
				"metadata": {
					"hasVideo": true,
					"videoCount": 1,
					"videoDuration": 1078,
					"hasAudio": false,
					"audioCount": 0,
					"audioDuration": 0,
					"hasPicture": false,
					"pictureCount": 0,
					"isFeatured": false,
					"hasGallery": false,
					"galleryCount": 0
				},
				"galleryAttachments": [],
				"thumbnail": {
					"width": 1920,
					"height": 1080,
					"path": "https://pbs.floatplane.com/blogPost_thumbnails/EZBOOhcLO0/012912733019369_1681509005404.jpeg",
					"childImages": [
						{
							"width": 400,
							"height": 225,
							"path": "https://pbs.floatplane.com/blogPost_thumbnails/EZBOOhcLO0/012912733019369_1681509005404_400x225.jpeg"
						},
						{
							"width": 1200,
							"height": 675,
							"path": "https://pbs.floatplane.com/blogPost_thumbnails/EZBOOhcLO0/012912733019369_1681509005404_1200x675.jpeg"
						}
					]
				},
				"isAccessible": true,
				"videoAttachments": [
					"qJq8gK3RtW"
				],
				"audioAttachments": [],
				"pictureAttachments": []
			},
			{
				"id": "GInQKQr7lK",
				"guid": "GInQKQr7lK",
				"title": "Captions for Future Floatplane Exclusives",
				"text": "<p>Hey Floatplane,</p><p><br /></p><p>We've noticed quite a few people mentioning that they don't like baked-in captions on the exclusives because it can be distracting.</p><p><br /></p><p>Going forward, we're going to be testing uploads of 2 versions for each Floatplane Exclusive video - one with captions, one without captions. (You may have already seen our last exclusive where we've done this).</p><p><br /></p><p>You will be able to choose which version to watch, under the video player (as shown in the screenshot).</p><p><br /></p><p>Hopefully, this is a good solution for now, at least until we add more functionality to the Floatplane player.</p><p><br /></p><p>We appreciate your feedback and would love to hear more in the comments below!</p><p><br /></p><p>- The Social Team</p>",
				"type": "blogPost",
				"channel": {
					"id": "6413623f5b12cca228a28e78",
					"creator": "59f94c0bdd241b70349eb72b",
					"title": "FP Exclusive",
					"urlname": "fpexclusive",
					"about": "wow... so empty",
					"order": 1,
					"cover": null,
					"card": null,
					"icon": {
						"width": 720,
						"height": 720,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/6413623f5b12cca228a28e78/069457536750544_1678991936484.jpeg",
						"childImages": [
							{
								"width": 100,
								"height": 100,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/6413623f5b12cca228a28e78/069457536750544_1678991936484_100x100.jpeg"
							},
							{
								"width": 250,
								"height": 250,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/6413623f5b12cca228a28e78/069457536750544_1678991936484_250x250.jpeg"
							}
						]
					}
				},
				"tags": [],
				"attachmentOrder": [
					"TPcb2sWNU3"
				],
				"releaseDate": "2023-04-14T22:52:00.034Z",
				"likes": 236,
				"dislikes": 0,
				"score": 236,
				"comments": 39,
				"creator": {
					"id": "59f94c0bdd241b70349eb72b",
					"owner": {
						"id": "59f94c0bdd241b70349eb723",
						"username": "Linus"
					},
					"title": "LinusTechTips",
					"urlname": "linustechtips",
					"description": "We make entertaining videos about technology, including tech reviews, showcases and other content.",
					"about": "# We're LinusTechTips\nWe make videos and stuff, cool eh?",
					"category": {
						"id": "59f94c0bdd241b70349eb727",
						"title": "Technology"
					},
					"cover": {
						"width": 1990,
						"height": 519,
						"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867.jpeg",
						"childImages": [
							{
								"width": 1245,
								"height": 325,
								"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867_1245x325.jpeg"
							}
						]
					},
					"icon": {
						"width": 600,
						"height": 600,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205.jpeg",
						"childImages": [
							{
								"width": 250,
								"height": 250,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_250x250.jpeg"
							},
							{
								"width": 100,
								"height": 100,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_100x100.jpeg"
							}
						]
					},
					"liveStream": {
						"id": "5c13f3c006f1be15e08e05c0",
						"title": "I Give Up - WAN Show April 14, 2023",
						"description": "<p>JumpCloud offers an Open Directory Platform that makes it possible to unify your technology stack across identity, access, and device management. Learn more here: <a href=\"https://lmg.gg/JumpCloud\" rel=\"noopener noreferrer\" target=\"_blank\">https://lmg.gg/JumpCloud</a></p><p>Check out Goliath today and save 20% at <a href=\"https://lmg.gg/Goliath-Technologies\" rel=\"noopener noreferrer\" target=\"_blank\">https://lmg.gg/Goliath-Technologies</a></p><p>Buy a Seasonic Prime TX 1000W PSU:<a href=\"https://geni.us/aryiquT\" rel=\"noopener noreferrer\" target=\"_blank\"> https://geni.us/aryiquT</a></p><p><br></p><p>Purchases made through some store links may provide some compensation to Linus Media Group.</p><p><br></p><p>Podcast Download: TBD</p>",
						"thumbnail": {
							"width": 1920,
							"height": 1080,
							"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325.jpeg",
							"childImages": [
								{
									"width": 400,
									"height": 225,
									"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325_400x225.jpeg"
								},
								{
									"width": 1200,
									"height": 675,
									"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325_1200x675.jpeg"
								}
							]
						},
						"owner": "59f94c0bdd241b70349eb72b",
						"channel": "63fe42c309e691e4e36de93d",
						"streamPath": "/api/video/v1/us-east-1.758417551536.channel.yKkxur4ukc0B.m3u8",
						"offline": {
							"title": "Offline",
							"description": "We're offline for now – please check back later!",
							"thumbnail": {
								"width": 1920,
								"height": 1080,
								"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026.jpeg",
								"childImages": [
									{
										"width": 400,
										"height": 225,
										"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_400x225.jpeg"
									},
									{
										"width": 1200,
										"height": 675,
										"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_1200x675.jpeg"
									}
								]
							}
						}
					},
					"subscriptionPlans": [
						{
							"id": "5d48d0306825b5780db93d07",
							"title": "LTT Supporter",
							"description": "- 2 Exclusives Per Week (Meet the Team, Extras, Behind the Scenes) \n- Exclusive livestreams\n- Save $10 by purchasing an annual subscription\n- Our gratitude for your support",
							"price": "5.00",
							"priceYearly": "50.00",
							"currency": "usd",
							"logo": null,
							"interval": "month",
							"featured": true,
							"allowGrandfatheredAccess": false,
							"discordServers": [],
							"discordRoles": []
						},
						{
							"id": "5e0ba6ac14e2590f760a0f0f",
							"title": "LTT Supporter Plus",
							"description": "- 4K Bitrate Streaming\n- 2 Exclusives Per Week (Meet the Team, Extras, Behind the Scenes) \n- Exclusive livestreams\n- Save $20 by purchasing an annual subscription\n- Our gratitude for your support",
							"price": "10.00",
							"priceYearly": "100.00",
							"currency": "usd",
							"logo": null,
							"interval": "month",
							"featured": true,
							"allowGrandfatheredAccess": false,
							"discordServers": [],
							"discordRoles": []
						}
					],
					"discoverable": true,
					"subscriberCountDisplay": "total",
					"incomeDisplay": false,
					"defaultChannel": "63fe42c309e691e4e36de93d",
					"channels": [
						"63fe42c309e691e4e36de93d",
						"6413534d88c13c181c3e2809",
						"64135da7ce81077a8480c679",
						"64135e27c773b27ff22c97eb",
						"64135e901ebaee42e258eb0b",
						"64135ed078d6262f717341b7",
						"64135f82fc76ab7f9fbdc876",
						"6413623f5b12cca228a28e78"
					],
					"card": {
						"width": 375,
						"height": 500,
						"path": "https://pbs.floatplane.com/creator_card/59f94c0bdd241b70349eb72b/281467946609369_1551250329871.jpeg",
						"childImages": [
							{
								"width": 300,
								"height": 400,
								"path": "https://pbs.floatplane.com/creator_card/59f94c0bdd241b70349eb72b/281467946609369_1551250329871_300x400.jpeg"
							}
						]
					}
				},
				"wasReleasedSilently": false,
				"metadata": {
					"hasVideo": false,
					"videoCount": 0,
					"videoDuration": 0,
					"hasAudio": false,
					"audioCount": 0,
					"audioDuration": 0,
					"hasPicture": true,
					"pictureCount": 1,
					"isFeatured": false,
					"hasGallery": false,
					"galleryCount": 0
				},
				"galleryAttachments": [],
				"thumbnail": {
					"width": 1200,
					"height": 675,
					"path": "https://pbs.floatplane.com/picture_thumbnails/lBcWf6foDQ/959540447767096_1681512555283.jpeg",
					"childImages": []
				},
				"isAccessible": true,
				"videoAttachments": [],
				"audioAttachments": [],
				"pictureAttachments": [
					"TPcb2sWNU3"
				]
			},
			{
				"id": "ZiH9pA2p1f",
				"guid": "ZiH9pA2p1f",
				"title": "TQ: The Truth About Lie Detectors",
				"text": "<p><br /></p>",
				"type": "blogPost",
				"channel": {
					"id": "64135e27c773b27ff22c97eb",
					"creator": "59f94c0bdd241b70349eb72b",
					"title": "Techquickie",
					"urlname": "techquickie",
					"about": "Ever wanted to learn more about your favorite gadgets or a trending topic in tech? \n\nWith a mix of humor, cynicism, and insight, Techquickie brings you the answers to all your tech questions every Tuesday and Friday.",
					"order": 5,
					"cover": null,
					"card": null,
					"icon": {
						"width": 88,
						"height": 88,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/64135e27c773b27ff22c97eb/666841640245092_1678990909616.jpeg",
						"childImages": []
					}
				},
				"tags": [],
				"attachmentOrder": [
					"PaStZw5N8I"
				],
				"releaseDate": "2023-04-14T19:34:00.049Z",
				"likes": 366,
				"dislikes": 2,
				"score": 364,
				"comments": 48,
				"creator": {
					"id": "59f94c0bdd241b70349eb72b",
					"owner": {
						"id": "59f94c0bdd241b70349eb723",
						"username": "Linus"
					},
					"title": "LinusTechTips",
					"urlname": "linustechtips",
					"description": "We make entertaining videos about technology, including tech reviews, showcases and other content.",
					"about": "# We're LinusTechTips\nWe make videos and stuff, cool eh?",
					"category": {
						"id": "59f94c0bdd241b70349eb727",
						"title": "Technology"
					},
					"cover": {
						"width": 1990,
						"height": 519,
						"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867.jpeg",
						"childImages": [
							{
								"width": 1245,
								"height": 325,
								"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867_1245x325.jpeg"
							}
						]
					},
					"icon": {
						"width": 600,
						"height": 600,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205.jpeg",
						"childImages": [
							{
								"width": 250,
								"height": 250,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_250x250.jpeg"
							},
							{
								"width": 100,
								"height": 100,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_100x100.jpeg"
							}
						]
					},
					"liveStream": {
						"id": "5c13f3c006f1be15e08e05c0",
						"title": "I Give Up - WAN Show April 14, 2023",
						"description": "<p>JumpCloud offers an Open Directory Platform that makes it possible to unify your technology stack across identity, access, and device management. Learn more here: <a href=\"https://lmg.gg/JumpCloud\" rel=\"noopener noreferrer\" target=\"_blank\">https://lmg.gg/JumpCloud</a></p><p>Check out Goliath today and save 20% at <a href=\"https://lmg.gg/Goliath-Technologies\" rel=\"noopener noreferrer\" target=\"_blank\">https://lmg.gg/Goliath-Technologies</a></p><p>Buy a Seasonic Prime TX 1000W PSU:<a href=\"https://geni.us/aryiquT\" rel=\"noopener noreferrer\" target=\"_blank\"> https://geni.us/aryiquT</a></p><p><br></p><p>Purchases made through some store links may provide some compensation to Linus Media Group.</p><p><br></p><p>Podcast Download: TBD</p>",
						"thumbnail": {
							"width": 1920,
							"height": 1080,
							"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325.jpeg",
							"childImages": [
								{
									"width": 400,
									"height": 225,
									"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325_400x225.jpeg"
								},
								{
									"width": 1200,
									"height": 675,
									"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325_1200x675.jpeg"
								}
							]
						},
						"owner": "59f94c0bdd241b70349eb72b",
						"channel": "63fe42c309e691e4e36de93d",
						"streamPath": "/api/video/v1/us-east-1.758417551536.channel.yKkxur4ukc0B.m3u8",
						"offline": {
							"title": "Offline",
							"description": "We're offline for now – please check back later!",
							"thumbnail": {
								"width": 1920,
								"height": 1080,
								"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026.jpeg",
								"childImages": [
									{
										"width": 400,
										"height": 225,
										"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_400x225.jpeg"
									},
									{
										"width": 1200,
										"height": 675,
										"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_1200x675.jpeg"
									}
								]
							}
						}
					},
					"subscriptionPlans": [
						{
							"id": "5d48d0306825b5780db93d07",
							"title": "LTT Supporter",
							"description": "- 2 Exclusives Per Week (Meet the Team, Extras, Behind the Scenes) \n- Exclusive livestreams\n- Save $10 by purchasing an annual subscription\n- Our gratitude for your support",
							"price": "5.00",
							"priceYearly": "50.00",
							"currency": "usd",
							"logo": null,
							"interval": "month",
							"featured": true,
							"allowGrandfatheredAccess": false,
							"discordServers": [],
							"discordRoles": []
						},
						{
							"id": "5e0ba6ac14e2590f760a0f0f",
							"title": "LTT Supporter Plus",
							"description": "- 4K Bitrate Streaming\n- 2 Exclusives Per Week (Meet the Team, Extras, Behind the Scenes) \n- Exclusive livestreams\n- Save $20 by purchasing an annual subscription\n- Our gratitude for your support",
							"price": "10.00",
							"priceYearly": "100.00",
							"currency": "usd",
							"logo": null,
							"interval": "month",
							"featured": true,
							"allowGrandfatheredAccess": false,
							"discordServers": [],
							"discordRoles": []
						}
					],
					"discoverable": true,
					"subscriberCountDisplay": "total",
					"incomeDisplay": false,
					"defaultChannel": "63fe42c309e691e4e36de93d",
					"channels": [
						"63fe42c309e691e4e36de93d",
						"6413534d88c13c181c3e2809",
						"64135da7ce81077a8480c679",
						"64135e27c773b27ff22c97eb",
						"64135e901ebaee42e258eb0b",
						"64135ed078d6262f717341b7",
						"64135f82fc76ab7f9fbdc876",
						"6413623f5b12cca228a28e78"
					],
					"card": {
						"width": 375,
						"height": 500,
						"path": "https://pbs.floatplane.com/creator_card/59f94c0bdd241b70349eb72b/281467946609369_1551250329871.jpeg",
						"childImages": [
							{
								"width": 300,
								"height": 400,
								"path": "https://pbs.floatplane.com/creator_card/59f94c0bdd241b70349eb72b/281467946609369_1551250329871_300x400.jpeg"
							}
						]
					}
				},
				"wasReleasedSilently": false,
				"metadata": {
					"hasVideo": true,
					"videoCount": 1,
					"videoDuration": 375,
					"hasAudio": false,
					"audioCount": 0,
					"audioDuration": 0,
					"hasPicture": false,
					"pictureCount": 0,
					"isFeatured": false,
					"hasGallery": false,
					"galleryCount": 0
				},
				"galleryAttachments": [],
				"thumbnail": {
					"width": 1920,
					"height": 1080,
					"path": "https://pbs.floatplane.com/blogPost_thumbnails/ZiH9pA2p1f/861123898473436_1681429909341.jpeg",
					"childImages": [
						{
							"width": 400,
							"height": 225,
							"path": "https://pbs.floatplane.com/blogPost_thumbnails/ZiH9pA2p1f/861123898473436_1681429909341_400x225.jpeg"
						},
						{
							"width": 1200,
							"height": 675,
							"path": "https://pbs.floatplane.com/blogPost_thumbnails/ZiH9pA2p1f/861123898473436_1681429909341_1200x675.jpeg"
						}
					]
				},
				"isAccessible": true,
				"videoAttachments": [
					"PaStZw5N8I"
				],
				"audioAttachments": [],
				"pictureAttachments": []
			},
			{
				"id": "FAxXHiH3cq",
				"guid": "FAxXHiH3cq",
				"title": "SC: One Keyboard to Rule Them All - DROP x LOTR Keyboards",
				"text": "<p>Plouffe loves three things, two of which are keyboards and Lord of The Rings, so when Drop sent over their new LOTR keyboards for us to check out, he jumped with joy. Will Plouffe be impressed by the fan service or is this keyboard bound for the depths of Mordor? (if that doesn't make sense I'm sorry I'm not a huge fan of LOTR I just write descriptions)</p><p><br /></p><p>Check out the Drop x The Lord of the Rings Products: <a href=\"https://lmg.gg/YbBWk\">https://lmg.gg/YbBWk</a></p><p>Buy a Keychron K4 Wireless Mechanical Keyboard: <a href=\"https://geni.us/BxSdSl\">https://geni.us/BxSdSl</a></p><p>Check out the KBDfans Odin V2 Mechanical Keyboard: <a href=\"https://lmg.gg/npCtE\">https://lmg.gg/npCtE</a></p><p>Check out Jelly Key Keycaps: <a href=\"https://lmg.gg/lkLgW\">https://lmg.gg/lkLgW</a></p><p><br /></p><p>Purchases made through some store links may provide some compensation to Linus Media Group.</p>",
				"type": "blogPost",
				"channel": {
					"id": "64135da7ce81077a8480c679",
					"creator": "59f94c0bdd241b70349eb72b",
					"title": "ShortCircuit",
					"urlname": "shortcircuit",
					"about": "What's in the box? Let's find out!\n\nOfficial channel under Linus Media Group.",
					"order": 3,
					"cover": null,
					"card": null,
					"icon": {
						"width": 88,
						"height": 88,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/64135da7ce81077a8480c679/470304051261927_1678990806883.jpeg",
						"childImages": []
					}
				},
				"tags": [
					"ShortCircuit"
				],
				"attachmentOrder": [
					"UPbbDdKyQc"
				],
				"releaseDate": "2023-04-13T21:31:00.056Z",
				"likes": 234,
				"dislikes": 13,
				"score": 221,
				"comments": 28,
				"creator": {
					"id": "59f94c0bdd241b70349eb72b",
					"owner": {
						"id": "59f94c0bdd241b70349eb723",
						"username": "Linus"
					},
					"title": "LinusTechTips",
					"urlname": "linustechtips",
					"description": "We make entertaining videos about technology, including tech reviews, showcases and other content.",
					"about": "# We're LinusTechTips\nWe make videos and stuff, cool eh?",
					"category": {
						"id": "59f94c0bdd241b70349eb727",
						"title": "Technology"
					},
					"cover": {
						"width": 1990,
						"height": 519,
						"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867.jpeg",
						"childImages": [
							{
								"width": 1245,
								"height": 325,
								"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867_1245x325.jpeg"
							}
						]
					},
					"icon": {
						"width": 600,
						"height": 600,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205.jpeg",
						"childImages": [
							{
								"width": 250,
								"height": 250,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_250x250.jpeg"
							},
							{
								"width": 100,
								"height": 100,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_100x100.jpeg"
							}
						]
					},
					"liveStream": {
						"id": "5c13f3c006f1be15e08e05c0",
						"title": "I Give Up - WAN Show April 14, 2023",
						"description": "<p>JumpCloud offers an Open Directory Platform that makes it possible to unify your technology stack across identity, access, and device management. Learn more here: <a href=\"https://lmg.gg/JumpCloud\" rel=\"noopener noreferrer\" target=\"_blank\">https://lmg.gg/JumpCloud</a></p><p>Check out Goliath today and save 20% at <a href=\"https://lmg.gg/Goliath-Technologies\" rel=\"noopener noreferrer\" target=\"_blank\">https://lmg.gg/Goliath-Technologies</a></p><p>Buy a Seasonic Prime TX 1000W PSU:<a href=\"https://geni.us/aryiquT\" rel=\"noopener noreferrer\" target=\"_blank\"> https://geni.us/aryiquT</a></p><p><br></p><p>Purchases made through some store links may provide some compensation to Linus Media Group.</p><p><br></p><p>Podcast Download: TBD</p>",
						"thumbnail": {
							"width": 1920,
							"height": 1080,
							"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325.jpeg",
							"childImages": [
								{
									"width": 400,
									"height": 225,
									"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325_400x225.jpeg"
								},
								{
									"width": 1200,
									"height": 675,
									"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325_1200x675.jpeg"
								}
							]
						},
						"owner": "59f94c0bdd241b70349eb72b",
						"channel": "63fe42c309e691e4e36de93d",
						"streamPath": "/api/video/v1/us-east-1.758417551536.channel.yKkxur4ukc0B.m3u8",
						"offline": {
							"title": "Offline",
							"description": "We're offline for now – please check back later!",
							"thumbnail": {
								"width": 1920,
								"height": 1080,
								"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026.jpeg",
								"childImages": [
									{
										"width": 400,
										"height": 225,
										"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_400x225.jpeg"
									},
									{
										"width": 1200,
										"height": 675,
										"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_1200x675.jpeg"
									}
								]
							}
						}
					},
					"subscriptionPlans": [
						{
							"id": "5d48d0306825b5780db93d07",
							"title": "LTT Supporter",
							"description": "- 2 Exclusives Per Week (Meet the Team, Extras, Behind the Scenes) \n- Exclusive livestreams\n- Save $10 by purchasing an annual subscription\n- Our gratitude for your support",
							"price": "5.00",
							"priceYearly": "50.00",
							"currency": "usd",
							"logo": null,
							"interval": "month",
							"featured": true,
							"allowGrandfatheredAccess": false,
							"discordServers": [],
							"discordRoles": []
						},
						{
							"id": "5e0ba6ac14e2590f760a0f0f",
							"title": "LTT Supporter Plus",
							"description": "- 4K Bitrate Streaming\n- 2 Exclusives Per Week (Meet the Team, Extras, Behind the Scenes) \n- Exclusive livestreams\n- Save $20 by purchasing an annual subscription\n- Our gratitude for your support",
							"price": "10.00",
							"priceYearly": "100.00",
							"currency": "usd",
							"logo": null,
							"interval": "month",
							"featured": true,
							"allowGrandfatheredAccess": false,
							"discordServers": [],
							"discordRoles": []
						}
					],
					"discoverable": true,
					"subscriberCountDisplay": "total",
					"incomeDisplay": false,
					"defaultChannel": "63fe42c309e691e4e36de93d",
					"channels": [
						"63fe42c309e691e4e36de93d",
						"6413534d88c13c181c3e2809",
						"64135da7ce81077a8480c679",
						"64135e27c773b27ff22c97eb",
						"64135e901ebaee42e258eb0b",
						"64135ed078d6262f717341b7",
						"64135f82fc76ab7f9fbdc876",
						"6413623f5b12cca228a28e78"
					],
					"card": {
						"width": 375,
						"height": 500,
						"path": "https://pbs.floatplane.com/creator_card/59f94c0bdd241b70349eb72b/281467946609369_1551250329871.jpeg",
						"childImages": [
							{
								"width": 300,
								"height": 400,
								"path": "https://pbs.floatplane.com/creator_card/59f94c0bdd241b70349eb72b/281467946609369_1551250329871_300x400.jpeg"
							}
						]
					}
				},
				"wasReleasedSilently": false,
				"metadata": {
					"hasVideo": true,
					"videoCount": 1,
					"videoDuration": 948,
					"hasAudio": false,
					"audioCount": 0,
					"audioDuration": 0,
					"hasPicture": false,
					"pictureCount": 0,
					"isFeatured": false,
					"hasGallery": false,
					"galleryCount": 0
				},
				"galleryAttachments": [],
				"thumbnail": {
					"width": 1920,
					"height": 1080,
					"path": "https://pbs.floatplane.com/blogPost_thumbnails/FAxXHiH3cq/951700435525588_1681328098603.jpeg",
					"childImages": [
						{
							"width": 400,
							"height": 225,
							"path": "https://pbs.floatplane.com/blogPost_thumbnails/FAxXHiH3cq/951700435525588_1681328098603_400x225.jpeg"
						},
						{
							"width": 1200,
							"height": 675,
							"path": "https://pbs.floatplane.com/blogPost_thumbnails/FAxXHiH3cq/951700435525588_1681328098603_1200x675.jpeg"
						}
					]
				},
				"isAccessible": true,
				"videoAttachments": [
					"UPbbDdKyQc"
				],
				"audioAttachments": [],
				"pictureAttachments": []
			},
			{
				"id": "lBhG8ZtB25",
				"guid": "lBhG8ZtB25",
				"title": "A Monster Lawsuit Is Coming For Me - WAN Show April 7, 2023",
				"text": "<p>Hello there!</p><p><br /></p><p>The thumbnail for this WAN was very fitting apparently... Sorry for the big delay here. We've been having issues recently with our upload/transcode setup. While we’ve been able to more or less hold it together for everything else, this WAN Show VOD was a massive 65gig 5-and-a-half-hour-long beast and thus was a little more prone to error. This normally would not, and absolutely should not actually be a problem in the future... But it gave us trouble this time around due to the other issues going on.</p><p><br /></p><p>We’ve got some big behind the scenes improvements coming in these areas, including much faster upload speeds... While that may not help Subscribers this should be a pretty nice improvement for Creators on the platform.</p><p><br /></p><p>Thank you for your patience, BYE!</p><p><br /></p><p>P.S. If you're not using beta.floatplane.com you're missing out!</p><p><br /></p><p>-- Luke</p><p><br /></p><p><br /></p><p>Don't just browse the web – build it. Apply for free today using the link <a href=\"https://covalence.io/wan\">https://covalence.io/wan</a> and take your first step toward a career in software development with Covalence.</p><p><br /></p><p>Try Zoho One free for 30 days with no credit card required here: <a href=\"https://www.zoho.com/one/lp/linus.html\">https://www.zoho.com/one/lp/linus.html</a></p><p><br /></p><p>Visit <a href=\"https://www.squarespace.com/WAN\">https://www.squarespace.com/WAN</a> and use offer code WAN for 10% off</p><p><br /></p><p>Podcast Download: <a href=\"https://spotifyanchor-web.app.link/e/...\">https://spotifyanchor-web.app.link/e/...</a></p>",
				"type": "blogPost",
				"channel": {
					"id": "63fe42c309e691e4e36de93d",
					"creator": "59f94c0bdd241b70349eb72b",
					"title": "Linus Tech Tips",
					"urlname": "main",
					"about": "# We're LinusTechTips\nWe make videos and stuff, cool eh?",
					"order": 0,
					"cover": null,
					"card": null,
					"icon": {
						"width": 600,
						"height": 600,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205.jpeg",
						"childImages": [
							{
								"width": 250,
								"height": 250,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_250x250.jpeg"
							},
							{
								"width": 100,
								"height": 100,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_100x100.jpeg"
							}
						]
					}
				},
				"tags": [],
				"attachmentOrder": [
					"x2X5LEHhJy"
				],
				"releaseDate": "2023-04-13T05:15:00.038Z",
				"likes": 371,
				"dislikes": 3,
				"score": 368,
				"comments": 138,
				"creator": {
					"id": "59f94c0bdd241b70349eb72b",
					"owner": {
						"id": "59f94c0bdd241b70349eb723",
						"username": "Linus"
					},
					"title": "LinusTechTips",
					"urlname": "linustechtips",
					"description": "We make entertaining videos about technology, including tech reviews, showcases and other content.",
					"about": "# We're LinusTechTips\nWe make videos and stuff, cool eh?",
					"category": {
						"id": "59f94c0bdd241b70349eb727",
						"title": "Technology"
					},
					"cover": {
						"width": 1990,
						"height": 519,
						"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867.jpeg",
						"childImages": [
							{
								"width": 1245,
								"height": 325,
								"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867_1245x325.jpeg"
							}
						]
					},
					"icon": {
						"width": 600,
						"height": 600,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205.jpeg",
						"childImages": [
							{
								"width": 250,
								"height": 250,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_250x250.jpeg"
							},
							{
								"width": 100,
								"height": 100,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_100x100.jpeg"
							}
						]
					},
					"liveStream": {
						"id": "5c13f3c006f1be15e08e05c0",
						"title": "I Give Up - WAN Show April 14, 2023",
						"description": "<p>JumpCloud offers an Open Directory Platform that makes it possible to unify your technology stack across identity, access, and device management. Learn more here: <a href=\"https://lmg.gg/JumpCloud\" rel=\"noopener noreferrer\" target=\"_blank\">https://lmg.gg/JumpCloud</a></p><p>Check out Goliath today and save 20% at <a href=\"https://lmg.gg/Goliath-Technologies\" rel=\"noopener noreferrer\" target=\"_blank\">https://lmg.gg/Goliath-Technologies</a></p><p>Buy a Seasonic Prime TX 1000W PSU:<a href=\"https://geni.us/aryiquT\" rel=\"noopener noreferrer\" target=\"_blank\"> https://geni.us/aryiquT</a></p><p><br></p><p>Purchases made through some store links may provide some compensation to Linus Media Group.</p><p><br></p><p>Podcast Download: TBD</p>",
						"thumbnail": {
							"width": 1920,
							"height": 1080,
							"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325.jpeg",
							"childImages": [
								{
									"width": 400,
									"height": 225,
									"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325_400x225.jpeg"
								},
								{
									"width": 1200,
									"height": 675,
									"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325_1200x675.jpeg"
								}
							]
						},
						"owner": "59f94c0bdd241b70349eb72b",
						"channel": "63fe42c309e691e4e36de93d",
						"streamPath": "/api/video/v1/us-east-1.758417551536.channel.yKkxur4ukc0B.m3u8",
						"offline": {
							"title": "Offline",
							"description": "We're offline for now – please check back later!",
							"thumbnail": {
								"width": 1920,
								"height": 1080,
								"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026.jpeg",
								"childImages": [
									{
										"width": 400,
										"height": 225,
										"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_400x225.jpeg"
									},
									{
										"width": 1200,
										"height": 675,
										"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_1200x675.jpeg"
									}
								]
							}
						}
					},
					"subscriptionPlans": [
						{
							"id": "5d48d0306825b5780db93d07",
							"title": "LTT Supporter",
							"description": "- 2 Exclusives Per Week (Meet the Team, Extras, Behind the Scenes) \n- Exclusive livestreams\n- Save $10 by purchasing an annual subscription\n- Our gratitude for your support",
							"price": "5.00",
							"priceYearly": "50.00",
							"currency": "usd",
							"logo": null,
							"interval": "month",
							"featured": true,
							"allowGrandfatheredAccess": false,
							"discordServers": [],
							"discordRoles": []
						},
						{
							"id": "5e0ba6ac14e2590f760a0f0f",
							"title": "LTT Supporter Plus",
							"description": "- 4K Bitrate Streaming\n- 2 Exclusives Per Week (Meet the Team, Extras, Behind the Scenes) \n- Exclusive livestreams\n- Save $20 by purchasing an annual subscription\n- Our gratitude for your support",
							"price": "10.00",
							"priceYearly": "100.00",
							"currency": "usd",
							"logo": null,
							"interval": "month",
							"featured": true,
							"allowGrandfatheredAccess": false,
							"discordServers": [],
							"discordRoles": []
						}
					],
					"discoverable": true,
					"subscriberCountDisplay": "total",
					"incomeDisplay": false,
					"defaultChannel": "63fe42c309e691e4e36de93d",
					"channels": [
						"63fe42c309e691e4e36de93d",
						"6413534d88c13c181c3e2809",
						"64135da7ce81077a8480c679",
						"64135e27c773b27ff22c97eb",
						"64135e901ebaee42e258eb0b",
						"64135ed078d6262f717341b7",
						"64135f82fc76ab7f9fbdc876",
						"6413623f5b12cca228a28e78"
					],
					"card": {
						"width": 375,
						"height": 500,
						"path": "https://pbs.floatplane.com/creator_card/59f94c0bdd241b70349eb72b/281467946609369_1551250329871.jpeg",
						"childImages": [
							{
								"width": 300,
								"height": 400,
								"path": "https://pbs.floatplane.com/creator_card/59f94c0bdd241b70349eb72b/281467946609369_1551250329871_300x400.jpeg"
							}
						]
					}
				},
				"wasReleasedSilently": false,
				"metadata": {
					"hasVideo": true,
					"videoCount": 1,
					"videoDuration": 19794,
					"hasAudio": false,
					"audioCount": 0,
					"audioDuration": 0,
					"hasPicture": false,
					"pictureCount": 0,
					"isFeatured": false,
					"hasGallery": false,
					"galleryCount": 0
				},
				"galleryAttachments": [],
				"thumbnail": {
					"width": 1280,
					"height": 720,
					"path": "https://pbs.floatplane.com/blogPost_thumbnails/lBhG8ZtB25/480023644153767_1681362747307.jpeg",
					"childImages": [
						{
							"width": 400,
							"height": 225,
							"path": "https://pbs.floatplane.com/blogPost_thumbnails/lBhG8ZtB25/480023644153767_1681362747307_400x225.jpeg"
						},
						{
							"width": 1200,
							"height": 675,
							"path": "https://pbs.floatplane.com/blogPost_thumbnails/lBhG8ZtB25/480023644153767_1681362747307_1200x675.jpeg"
						}
					]
				},
				"isAccessible": true,
				"videoAttachments": [
					"x2X5LEHhJy"
				],
				"audioAttachments": [],
				"pictureAttachments": []
			},
			{
				"id": "pTYIRJldbL",
				"guid": "pTYIRJldbL",
				"title": "Malware on Android TV Boxes",
				"text": "<p>These Android TV boxes have been around just about as long as Android has. Odds are, you or someone you know has had one over the years. But beneath their crunchy Android exterior lies a deep, dark secret. What evils will befall you should you choose to bring such a device into your house? And what alternatives are there? Are they useful for anything at all?</p>",
				"type": "blogPost",
				"channel": {
					"id": "63fe42c309e691e4e36de93d",
					"creator": "59f94c0bdd241b70349eb72b",
					"title": "Linus Tech Tips",
					"urlname": "main",
					"about": "# We're LinusTechTips\nWe make videos and stuff, cool eh?",
					"order": 0,
					"cover": null,
					"card": null,
					"icon": {
						"width": 600,
						"height": 600,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205.jpeg",
						"childImages": [
							{
								"width": 250,
								"height": 250,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_250x250.jpeg"
							},
							{
								"width": 100,
								"height": 100,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_100x100.jpeg"
							}
						]
					}
				},
				"tags": [],
				"attachmentOrder": [
					"UX8pk50G90"
				],
				"releaseDate": "2023-04-13T04:00:00.384Z",
				"likes": 759,
				"dislikes": 1,
				"score": 758,
				"comments": 100,
				"creator": {
					"id": "59f94c0bdd241b70349eb72b",
					"owner": {
						"id": "59f94c0bdd241b70349eb723",
						"username": "Linus"
					},
					"title": "LinusTechTips",
					"urlname": "linustechtips",
					"description": "We make entertaining videos about technology, including tech reviews, showcases and other content.",
					"about": "# We're LinusTechTips\nWe make videos and stuff, cool eh?",
					"category": {
						"id": "59f94c0bdd241b70349eb727",
						"title": "Technology"
					},
					"cover": {
						"width": 1990,
						"height": 519,
						"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867.jpeg",
						"childImages": [
							{
								"width": 1245,
								"height": 325,
								"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867_1245x325.jpeg"
							}
						]
					},
					"icon": {
						"width": 600,
						"height": 600,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205.jpeg",
						"childImages": [
							{
								"width": 250,
								"height": 250,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_250x250.jpeg"
							},
							{
								"width": 100,
								"height": 100,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_100x100.jpeg"
							}
						]
					},
					"liveStream": {
						"id": "5c13f3c006f1be15e08e05c0",
						"title": "I Give Up - WAN Show April 14, 2023",
						"description": "<p>JumpCloud offers an Open Directory Platform that makes it possible to unify your technology stack across identity, access, and device management. Learn more here: <a href=\"https://lmg.gg/JumpCloud\" rel=\"noopener noreferrer\" target=\"_blank\">https://lmg.gg/JumpCloud</a></p><p>Check out Goliath today and save 20% at <a href=\"https://lmg.gg/Goliath-Technologies\" rel=\"noopener noreferrer\" target=\"_blank\">https://lmg.gg/Goliath-Technologies</a></p><p>Buy a Seasonic Prime TX 1000W PSU:<a href=\"https://geni.us/aryiquT\" rel=\"noopener noreferrer\" target=\"_blank\"> https://geni.us/aryiquT</a></p><p><br></p><p>Purchases made through some store links may provide some compensation to Linus Media Group.</p><p><br></p><p>Podcast Download: TBD</p>",
						"thumbnail": {
							"width": 1920,
							"height": 1080,
							"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325.jpeg",
							"childImages": [
								{
									"width": 400,
									"height": 225,
									"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325_400x225.jpeg"
								},
								{
									"width": 1200,
									"height": 675,
									"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325_1200x675.jpeg"
								}
							]
						},
						"owner": "59f94c0bdd241b70349eb72b",
						"channel": "63fe42c309e691e4e36de93d",
						"streamPath": "/api/video/v1/us-east-1.758417551536.channel.yKkxur4ukc0B.m3u8",
						"offline": {
							"title": "Offline",
							"description": "We're offline for now – please check back later!",
							"thumbnail": {
								"width": 1920,
								"height": 1080,
								"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026.jpeg",
								"childImages": [
									{
										"width": 400,
										"height": 225,
										"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_400x225.jpeg"
									},
									{
										"width": 1200,
										"height": 675,
										"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_1200x675.jpeg"
									}
								]
							}
						}
					},
					"subscriptionPlans": [
						{
							"id": "5d48d0306825b5780db93d07",
							"title": "LTT Supporter",
							"description": "- 2 Exclusives Per Week (Meet the Team, Extras, Behind the Scenes) \n- Exclusive livestreams\n- Save $10 by purchasing an annual subscription\n- Our gratitude for your support",
							"price": "5.00",
							"priceYearly": "50.00",
							"currency": "usd",
							"logo": null,
							"interval": "month",
							"featured": true,
							"allowGrandfatheredAccess": false,
							"discordServers": [],
							"discordRoles": []
						},
						{
							"id": "5e0ba6ac14e2590f760a0f0f",
							"title": "LTT Supporter Plus",
							"description": "- 4K Bitrate Streaming\n- 2 Exclusives Per Week (Meet the Team, Extras, Behind the Scenes) \n- Exclusive livestreams\n- Save $20 by purchasing an annual subscription\n- Our gratitude for your support",
							"price": "10.00",
							"priceYearly": "100.00",
							"currency": "usd",
							"logo": null,
							"interval": "month",
							"featured": true,
							"allowGrandfatheredAccess": false,
							"discordServers": [],
							"discordRoles": []
						}
					],
					"discoverable": true,
					"subscriberCountDisplay": "total",
					"incomeDisplay": false,
					"defaultChannel": "63fe42c309e691e4e36de93d",
					"channels": [
						"63fe42c309e691e4e36de93d",
						"6413534d88c13c181c3e2809",
						"64135da7ce81077a8480c679",
						"64135e27c773b27ff22c97eb",
						"64135e901ebaee42e258eb0b",
						"64135ed078d6262f717341b7",
						"64135f82fc76ab7f9fbdc876",
						"6413623f5b12cca228a28e78"
					],
					"card": {
						"width": 375,
						"height": 500,
						"path": "https://pbs.floatplane.com/creator_card/59f94c0bdd241b70349eb72b/281467946609369_1551250329871.jpeg",
						"childImages": [
							{
								"width": 300,
								"height": 400,
								"path": "https://pbs.floatplane.com/creator_card/59f94c0bdd241b70349eb72b/281467946609369_1551250329871_300x400.jpeg"
							}
						]
					}
				},
				"wasReleasedSilently": false,
				"metadata": {
					"hasVideo": true,
					"videoCount": 1,
					"videoDuration": 569,
					"hasAudio": false,
					"audioCount": 0,
					"audioDuration": 0,
					"hasPicture": false,
					"pictureCount": 0,
					"isFeatured": false,
					"hasGallery": false,
					"galleryCount": 0
				},
				"galleryAttachments": [],
				"thumbnail": {
					"width": 1920,
					"height": 1080,
					"path": "https://pbs.floatplane.com/blogPost_thumbnails/pTYIRJldbL/454569176559006_1681347932893.jpeg",
					"childImages": [
						{
							"width": 400,
							"height": 225,
							"path": "https://pbs.floatplane.com/blogPost_thumbnails/pTYIRJldbL/454569176559006_1681347932893_400x225.jpeg"
						},
						{
							"width": 1200,
							"height": 675,
							"path": "https://pbs.floatplane.com/blogPost_thumbnails/pTYIRJldbL/454569176559006_1681347932893_1200x675.jpeg"
						}
					]
				},
				"isAccessible": true,
				"videoAttachments": [
					"UX8pk50G90"
				],
				"audioAttachments": [],
				"pictureAttachments": []
			},
			{
				"id": "GOpKuvGkJQ",
				"guid": "GOpKuvGkJQ",
				"title": "About the WAN Show...",
				"text": "<p>… we haven’t forgotten! We've been having issues recently with our upload/transcode setup for Floatplane. While we’ve been able to hold it together for everything else, the WAN Show VOD is a unique 5-and-a-half-hour-long beast. The length and size of the video mean a higher chance for the file to fail during the uploading process, but boy howdy are we trying. We still plan to get the VOD up.</p><p><br /></p><p>Additionally, we’ve got big improvements coming in these areas, including much faster upload speeds.</p><p><br /></p><p>Thank you for your patience!</p>",
				"type": "blogPost",
				"channel": {
					"id": "63fe42c309e691e4e36de93d",
					"creator": "59f94c0bdd241b70349eb72b",
					"title": "Linus Tech Tips",
					"urlname": "main",
					"about": "# We're LinusTechTips\nWe make videos and stuff, cool eh?",
					"order": 0,
					"cover": null,
					"card": null,
					"icon": {
						"width": 600,
						"height": 600,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205.jpeg",
						"childImages": [
							{
								"width": 250,
								"height": 250,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_250x250.jpeg"
							},
							{
								"width": 100,
								"height": 100,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_100x100.jpeg"
							}
						]
					}
				},
				"tags": [],
				"attachmentOrder": [
					"e1CKpm9IDz"
				],
				"releaseDate": "2023-04-13T01:13:00.070Z",
				"likes": 917,
				"dislikes": 4,
				"score": 913,
				"comments": 220,
				"creator": {
					"id": "59f94c0bdd241b70349eb72b",
					"owner": {
						"id": "59f94c0bdd241b70349eb723",
						"username": "Linus"
					},
					"title": "LinusTechTips",
					"urlname": "linustechtips",
					"description": "We make entertaining videos about technology, including tech reviews, showcases and other content.",
					"about": "# We're LinusTechTips\nWe make videos and stuff, cool eh?",
					"category": {
						"id": "59f94c0bdd241b70349eb727",
						"title": "Technology"
					},
					"cover": {
						"width": 1990,
						"height": 519,
						"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867.jpeg",
						"childImages": [
							{
								"width": 1245,
								"height": 325,
								"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867_1245x325.jpeg"
							}
						]
					},
					"icon": {
						"width": 600,
						"height": 600,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205.jpeg",
						"childImages": [
							{
								"width": 250,
								"height": 250,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_250x250.jpeg"
							},
							{
								"width": 100,
								"height": 100,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_100x100.jpeg"
							}
						]
					},
					"liveStream": {
						"id": "5c13f3c006f1be15e08e05c0",
						"title": "I Give Up - WAN Show April 14, 2023",
						"description": "<p>JumpCloud offers an Open Directory Platform that makes it possible to unify your technology stack across identity, access, and device management. Learn more here: <a href=\"https://lmg.gg/JumpCloud\" rel=\"noopener noreferrer\" target=\"_blank\">https://lmg.gg/JumpCloud</a></p><p>Check out Goliath today and save 20% at <a href=\"https://lmg.gg/Goliath-Technologies\" rel=\"noopener noreferrer\" target=\"_blank\">https://lmg.gg/Goliath-Technologies</a></p><p>Buy a Seasonic Prime TX 1000W PSU:<a href=\"https://geni.us/aryiquT\" rel=\"noopener noreferrer\" target=\"_blank\"> https://geni.us/aryiquT</a></p><p><br></p><p>Purchases made through some store links may provide some compensation to Linus Media Group.</p><p><br></p><p>Podcast Download: TBD</p>",
						"thumbnail": {
							"width": 1920,
							"height": 1080,
							"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325.jpeg",
							"childImages": [
								{
									"width": 400,
									"height": 225,
									"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325_400x225.jpeg"
								},
								{
									"width": 1200,
									"height": 675,
									"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325_1200x675.jpeg"
								}
							]
						},
						"owner": "59f94c0bdd241b70349eb72b",
						"channel": "63fe42c309e691e4e36de93d",
						"streamPath": "/api/video/v1/us-east-1.758417551536.channel.yKkxur4ukc0B.m3u8",
						"offline": {
							"title": "Offline",
							"description": "We're offline for now – please check back later!",
							"thumbnail": {
								"width": 1920,
								"height": 1080,
								"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026.jpeg",
								"childImages": [
									{
										"width": 400,
										"height": 225,
										"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_400x225.jpeg"
									},
									{
										"width": 1200,
										"height": 675,
										"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_1200x675.jpeg"
									}
								]
							}
						}
					},
					"subscriptionPlans": [
						{
							"id": "5d48d0306825b5780db93d07",
							"title": "LTT Supporter",
							"description": "- 2 Exclusives Per Week (Meet the Team, Extras, Behind the Scenes) \n- Exclusive livestreams\n- Save $10 by purchasing an annual subscription\n- Our gratitude for your support",
							"price": "5.00",
							"priceYearly": "50.00",
							"currency": "usd",
							"logo": null,
							"interval": "month",
							"featured": true,
							"allowGrandfatheredAccess": false,
							"discordServers": [],
							"discordRoles": []
						},
						{
							"id": "5e0ba6ac14e2590f760a0f0f",
							"title": "LTT Supporter Plus",
							"description": "- 4K Bitrate Streaming\n- 2 Exclusives Per Week (Meet the Team, Extras, Behind the Scenes) \n- Exclusive livestreams\n- Save $20 by purchasing an annual subscription\n- Our gratitude for your support",
							"price": "10.00",
							"priceYearly": "100.00",
							"currency": "usd",
							"logo": null,
							"interval": "month",
							"featured": true,
							"allowGrandfatheredAccess": false,
							"discordServers": [],
							"discordRoles": []
						}
					],
					"discoverable": true,
					"subscriberCountDisplay": "total",
					"incomeDisplay": false,
					"defaultChannel": "63fe42c309e691e4e36de93d",
					"channels": [
						"63fe42c309e691e4e36de93d",
						"6413534d88c13c181c3e2809",
						"64135da7ce81077a8480c679",
						"64135e27c773b27ff22c97eb",
						"64135e901ebaee42e258eb0b",
						"64135ed078d6262f717341b7",
						"64135f82fc76ab7f9fbdc876",
						"6413623f5b12cca228a28e78"
					],
					"card": {
						"width": 375,
						"height": 500,
						"path": "https://pbs.floatplane.com/creator_card/59f94c0bdd241b70349eb72b/281467946609369_1551250329871.jpeg",
						"childImages": [
							{
								"width": 300,
								"height": 400,
								"path": "https://pbs.floatplane.com/creator_card/59f94c0bdd241b70349eb72b/281467946609369_1551250329871_300x400.jpeg"
							}
						]
					}
				},
				"wasReleasedSilently": false,
				"metadata": {
					"hasVideo": false,
					"videoCount": 0,
					"videoDuration": 0,
					"hasAudio": false,
					"audioCount": 0,
					"audioDuration": 0,
					"hasPicture": true,
					"pictureCount": 1,
					"isFeatured": false,
					"hasGallery": false,
					"galleryCount": 0
				},
				"galleryAttachments": [],
				"thumbnail": {
					"width": 1200,
					"height": 675,
					"path": "https://pbs.floatplane.com/picture_thumbnails/e1CKpm9IDz/959076952518524_1681348309119.jpeg",
					"childImages": []
				},
				"isAccessible": true,
				"videoAttachments": [],
				"audioAttachments": [],
				"pictureAttachments": [
					"e1CKpm9IDz"
				]
			},
			{
				"id": "IQb3sQkDaw",
				"guid": "IQb3sQkDaw",
				"title": "TL: Intel + Arm deal, RTX 4070 launch, Twitter chatbot + more!",
				"text": "<p><strong>NEWS SOURCES:</strong></p><p><br /></p><p>INTEL ARMS ITSELF</p><p>Intel partners with Arm</p><p><a href=\"https://www.engadget.com/intel-is-optimizing-its-fabs-to-become-an-arm-chip-manufacturer-164008043.html\">https://www.engadget.com/intel-is-optimizing-its-fabs-to-become-an-arm-chip-manufacturer-164008043.html</a></p><p><a href=\"https://www.thurrott.com/hardware/281800/arm-partners-with-intel-foundry-services\">https://www.thurrott.com/hardware/281800/arm-partners-with-intel-foundry-services</a></p><p>Everybody liked that. <a href=\"https://seekingalpha.com/news/3955973-intel-will-work-with-arm-on-next-gen-manufacturing-of-mobile-chips\">https://seekingalpha.com/news/3955973-intel-will-work-with-arm-on-next-gen-manufacturing-of-mobile-chips</a></p><p>Historical context: Intel’s plans to COMBINE x86, Arm, and RISC-V</p><p><a href=\"https://www.extremetech.com/computing/331740-intel-plans-to-license-cores-that-combine-arm-risc-v-and-x86\">https://www.extremetech.com/computing/331740-intel-plans-to-license-cores-that-combine-arm-risc-v-and-x86</a></p><p><br /></p><p>BUDGET AMBIVALENT</p><p>4070 Launch</p><p><a href=\"https://www.nvidia.com/en-us/geforce/news/geforce-rtx-4070/\">https://www.nvidia.com/en-us/geforce/news/geforce-rtx-4070/</a></p><p>Nvidia community manager jumped on Reddit to do damage control <a href=\"https://www.reddit.com/r/hardware/comments/12jlxt8/comment/jfyxbqa/?utm_source=reddit&amp;utm_medium=web2x&amp;context=3\">https://www.reddit.com/r/hardware/comments/12jlxt8/comment/jfyxbqa/?utm_source=reddit&amp;utm_medium=web2x&amp;context=3</a></p><p><a href=\"https://www.rockpapershotgun.com/nvidia-geforce-rtx-4070-price-specs-release-date-performance-features\">https://www.rockpapershotgun.com/nvidia-geforce-rtx-4070-price-specs-release-date-performance-features</a></p><p><a href=\"https://www.tomshardware.com/news/nvidia-maintains-lead-as-sales-of-graphics-cards-hit-all-time-low-in-2022-jpr\">https://www.tomshardware.com/news/nvidia-maintains-lead-as-sales-of-graphics-cards-hit-all-time-low-in-2022-jpr</a> </p><p><br /></p><p>X IS A VERY COOL LETTER</p><p>Twitter working on a ChatGPT rival apparently <a href=\"https://www.businessinsider.com/elon-musk-twitter-investment-generative-ai-project-2023-4\">https://www.businessinsider.com/elon-musk-twitter-investment-generative-ai-project-2023-4</a></p><p>Elon buys 10,000 GPUs</p><p><a href=\"https://www.toms\">https://www.toms</a><a href=\"https://www.tomshardware.com/news/elon-musk-buys-tens-of-thousands-of-gpus-for-twitter-ai-project\">hardware.com/news/elon-musk-buys-tens-of-thousands-of-gpus-for-twitter-ai-project</a></p><p>Twitter folded into X Corp</p><p><a href=\"https://techcrunch.com/2023/04/11/twitter-inc-is-now-x-corp/\">https://techcrunch.com/2023/04/11/twitter-inc-is-now-x-corp/</a></p><p>NPR Leaves Twitter over mis-labeling as “state-affiliated media.”</p><p><a href=\"https://www.nbcnews.com/tech/tech-news/npr-quits-twitter-says-platform-undermining-credibility-rcna79322\">https://www.nbcnews.com/tech/tech-news/npr-quits-twitter-says-platform-undermining-credibility-rcna79322</a></p><p><br /></p><p>QUICK BITS</p><p> </p><p>STOP LYING ON YOUR E-RESUME</p><p>Linked-in verified</p><p><a href=\"https://www.wired.com/story/linkedin-verification-clear/\">https://www.wired.com/story/linkedin-verification-clear/</a></p><p>-         EDITOR: <a href=\"https://12ft.io/proxy?q=https%3A%2F%2Fwww.wired.com%2Fstory%2Flinkedin-verification-clear%2F\">https://12ft.io/proxy?q=https%3A%2F%2Fwww.wired.com%2Fstory%2Flinkedin-verification-clear%2F</a></p><p><a href=\"https://www.linkedin.com/help/linkedin/answer/a1359065/verifications-on-your-linkedin-profile?lang=en\">https://www.linkedin.com/help/linkedin/answer/a1359065/verifications-on-your-linkedin-profile?lang=en</a></p><p><a href=\"https://techcrunch.com/2023/04/12/linkedin-rolls-out-ways-to-verify-your-identity-and-employment-without-a-price-tag/\">https://techcrunch.com/2023/04/12/linkedin-rolls-out-ways-to-verify-your-identity-and-employment-without-a-price-tag/</a></p><p><br /></p><p>YOUR DREAMS ARE OVER</p><p>Dreams for PS4 is ending support in September</p><p><a href=\"https://www.kitguru.net/gaming/mustafa-mahmoud/media-molecules-dreams-is-ending-support-later-this-year/\">https://www.kitguru.net/gaming/mustafa-mahmoud/media-molecules-dreams-is-ending-support-later-this-year/</a></p><p><a href=\"https://kotaku.com/dreams-ps4-ps5-media-molecule-last-update-date-1850323245\">https://kotaku.com/dreams-ps4-ps5-media-molecule-last-update-date-1850323245</a></p><p><a href=\"https://www.polygon.com/23678503/dreams-end-of-live-service-server-changes\">https://www.polygon.com/23678503/dreams-end-of-live-service-server-changes</a></p><p><br /></p><p>UMG tells Apple and Spotify to block AI music/lyrics scraping</p><p><a href=\"https://arstechnica.com/information-technology/2023/04/streaming-services-urged-to-clamp-down-on-ai-generated-music/\">https://arstechnica.com/information-technology/2023/04/streaming-services-urged-to-clamp-down-on-ai-generated-music/</a></p><p><a href=\"https://musically.com/2023/04/12/report-umg-wants-dsps-to-block-unlicensed-ai-training-scraping/\">https://musically.com/2023/04/12/report-umg-wants-dsps-to-block-unlicensed-ai-training-scraping/</a></p><p><a href=\"https://www.ft.com/content/aec1679b-5a34-4dad-9fc9-f4d8cdd124b9\">https://www.ft.com/content/aec1679b-5a34-4dad-9fc9-f4d8cdd124b9</a></p><p><br /></p><p>A PEACEFUL PASSING</p><p>No-longer-supported Network monitoring gadget gets graceful transition</p><p><a href=\"https://arstechnica.com/gadgets/2023/04/monitor-io-network-gadget-is-going-eol-but-in-the-best-possible-way/\">https://arstechnica.com/gadgets/2023/04/monitor-io-network-gadget-is-going-eol-but-in-the-best-possible-way/</a></p><p><a href=\"https://www.monitor-io.com/end-of-service.html\">https://www.monitor-io.com/end-of-service.html</a></p><p><br /></p><p>“JUICE JACKING?”</p><p>FBI warns not to use free phone charging stations</p><p><a href=\"https://www.cnbc.com/2023/04/10/fbi-says-you-shouldnt-use-public-phone-charging-stations.html\">https://www.cnbc.com/2023/04/10/fbi-says-you-shouldnt-use-public-phone-charging-stations.html</a></p><p><a href=\"https://www.axios.com/2023/04/10/fbi-warning-charging-stations-juice-jacking\">https://www.axios.com/2023/04/10/fbi-warning-charging-stations-juice-jacking</a></p><p><a href=\"https://www.theguardian.com/technology/2023/apr/11/public-charging-stations-malware-phones-fbi\">https://www.theguardian.com/technology/2023/apr/11/public-charging-stations-malware-phones-fbi</a></p><p><br /></p>",
				"type": "blogPost",
				"channel": {
					"id": "6413534d88c13c181c3e2809",
					"creator": "59f94c0bdd241b70349eb72b",
					"title": "TechLinked",
					"urlname": "techlinked",
					"about": "News about tech + gaming culture, delivered thrice weekly.\n\nWe're also doing long-form video essays now, apparently. \n\nThe TalkLinked talk show/podcast will probably come back at some point, too!\n\nWriters: Riley Murdock, Jon Martin, James Strieb",
					"order": 2,
					"cover": null,
					"card": null,
					"icon": {
						"width": 88,
						"height": 88,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/6413534d88c13c181c3e2809/955526950207988_1678988110287.jpeg",
						"childImages": []
					}
				},
				"tags": [],
				"attachmentOrder": [
					"WnmVJX0XXn"
				],
				"releaseDate": "2023-04-13T01:11:00.061Z",
				"likes": 373,
				"dislikes": 3,
				"score": 370,
				"comments": 46,
				"creator": {
					"id": "59f94c0bdd241b70349eb72b",
					"owner": {
						"id": "59f94c0bdd241b70349eb723",
						"username": "Linus"
					},
					"title": "LinusTechTips",
					"urlname": "linustechtips",
					"description": "We make entertaining videos about technology, including tech reviews, showcases and other content.",
					"about": "# We're LinusTechTips\nWe make videos and stuff, cool eh?",
					"category": {
						"id": "59f94c0bdd241b70349eb727",
						"title": "Technology"
					},
					"cover": {
						"width": 1990,
						"height": 519,
						"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867.jpeg",
						"childImages": [
							{
								"width": 1245,
								"height": 325,
								"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867_1245x325.jpeg"
							}
						]
					},
					"icon": {
						"width": 600,
						"height": 600,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205.jpeg",
						"childImages": [
							{
								"width": 250,
								"height": 250,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_250x250.jpeg"
							},
							{
								"width": 100,
								"height": 100,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_100x100.jpeg"
							}
						]
					},
					"liveStream": {
						"id": "5c13f3c006f1be15e08e05c0",
						"title": "I Give Up - WAN Show April 14, 2023",
						"description": "<p>JumpCloud offers an Open Directory Platform that makes it possible to unify your technology stack across identity, access, and device management. Learn more here: <a href=\"https://lmg.gg/JumpCloud\" rel=\"noopener noreferrer\" target=\"_blank\">https://lmg.gg/JumpCloud</a></p><p>Check out Goliath today and save 20% at <a href=\"https://lmg.gg/Goliath-Technologies\" rel=\"noopener noreferrer\" target=\"_blank\">https://lmg.gg/Goliath-Technologies</a></p><p>Buy a Seasonic Prime TX 1000W PSU:<a href=\"https://geni.us/aryiquT\" rel=\"noopener noreferrer\" target=\"_blank\"> https://geni.us/aryiquT</a></p><p><br></p><p>Purchases made through some store links may provide some compensation to Linus Media Group.</p><p><br></p><p>Podcast Download: TBD</p>",
						"thumbnail": {
							"width": 1920,
							"height": 1080,
							"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325.jpeg",
							"childImages": [
								{
									"width": 400,
									"height": 225,
									"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325_400x225.jpeg"
								},
								{
									"width": 1200,
									"height": 675,
									"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325_1200x675.jpeg"
								}
							]
						},
						"owner": "59f94c0bdd241b70349eb72b",
						"channel": "63fe42c309e691e4e36de93d",
						"streamPath": "/api/video/v1/us-east-1.758417551536.channel.yKkxur4ukc0B.m3u8",
						"offline": {
							"title": "Offline",
							"description": "We're offline for now – please check back later!",
							"thumbnail": {
								"width": 1920,
								"height": 1080,
								"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026.jpeg",
								"childImages": [
									{
										"width": 400,
										"height": 225,
										"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_400x225.jpeg"
									},
									{
										"width": 1200,
										"height": 675,
										"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_1200x675.jpeg"
									}
								]
							}
						}
					},
					"subscriptionPlans": [
						{
							"id": "5d48d0306825b5780db93d07",
							"title": "LTT Supporter",
							"description": "- 2 Exclusives Per Week (Meet the Team, Extras, Behind the Scenes) \n- Exclusive livestreams\n- Save $10 by purchasing an annual subscription\n- Our gratitude for your support",
							"price": "5.00",
							"priceYearly": "50.00",
							"currency": "usd",
							"logo": null,
							"interval": "month",
							"featured": true,
							"allowGrandfatheredAccess": false,
							"discordServers": [],
							"discordRoles": []
						},
						{
							"id": "5e0ba6ac14e2590f760a0f0f",
							"title": "LTT Supporter Plus",
							"description": "- 4K Bitrate Streaming\n- 2 Exclusives Per Week (Meet the Team, Extras, Behind the Scenes) \n- Exclusive livestreams\n- Save $20 by purchasing an annual subscription\n- Our gratitude for your support",
							"price": "10.00",
							"priceYearly": "100.00",
							"currency": "usd",
							"logo": null,
							"interval": "month",
							"featured": true,
							"allowGrandfatheredAccess": false,
							"discordServers": [],
							"discordRoles": []
						}
					],
					"discoverable": true,
					"subscriberCountDisplay": "total",
					"incomeDisplay": false,
					"defaultChannel": "63fe42c309e691e4e36de93d",
					"channels": [
						"63fe42c309e691e4e36de93d",
						"6413534d88c13c181c3e2809",
						"64135da7ce81077a8480c679",
						"64135e27c773b27ff22c97eb",
						"64135e901ebaee42e258eb0b",
						"64135ed078d6262f717341b7",
						"64135f82fc76ab7f9fbdc876",
						"6413623f5b12cca228a28e78"
					],
					"card": {
						"width": 375,
						"height": 500,
						"path": "https://pbs.floatplane.com/creator_card/59f94c0bdd241b70349eb72b/281467946609369_1551250329871.jpeg",
						"childImages": [
							{
								"width": 300,
								"height": 400,
								"path": "https://pbs.floatplane.com/creator_card/59f94c0bdd241b70349eb72b/281467946609369_1551250329871_300x400.jpeg"
							}
						]
					}
				},
				"wasReleasedSilently": false,
				"metadata": {
					"hasVideo": true,
					"videoCount": 1,
					"videoDuration": 418,
					"hasAudio": false,
					"audioCount": 0,
					"audioDuration": 0,
					"hasPicture": false,
					"pictureCount": 0,
					"isFeatured": false,
					"hasGallery": false,
					"galleryCount": 0
				},
				"galleryAttachments": [],
				"thumbnail": {
					"width": 1920,
					"height": 1080,
					"path": "https://pbs.floatplane.com/blogPost_thumbnails/IQb3sQkDaw/172962994698770_1681347611341.jpeg",
					"childImages": [
						{
							"width": 400,
							"height": 225,
							"path": "https://pbs.floatplane.com/blogPost_thumbnails/IQb3sQkDaw/172962994698770_1681347611341_400x225.jpeg"
						},
						{
							"width": 1200,
							"height": 675,
							"path": "https://pbs.floatplane.com/blogPost_thumbnails/IQb3sQkDaw/172962994698770_1681347611341_1200x675.jpeg"
						}
					]
				},
				"isAccessible": true,
				"videoAttachments": [
					"WnmVJX0XXn"
				],
				"audioAttachments": [],
				"pictureAttachments": []
			},
			{
				"id": "oDOEnx1aWA",
				"guid": "oDOEnx1aWA",
				"title": "SC: Should you buy a Walkman in 2023? - Sony NW-A300 & NW-ZX700",
				"text": "<p>The Walkman brand has been around since the 80s and they used to dominate the market. After a long time in hibernation, Sony has brought them back with the new ZX-707 and NW-A306 units that boast some high quality claims. Will Jake and Dan be impressed or should you stick to using your phone?</p><p><br /></p><p>Buy a Sony ZX-707 Walkman: <a href=\"https://lmg.gg/sKa9A\">https://lmg.gg/sKa9A</a></p><p>Buy a Sony NW-A306 Walkman: <a href=\"https://lmg.gg/oE8uU\">https://lmg.gg/oE8uU</a></p><p><br /></p><p>Purchases made through some store links may provide some compensation to Linus Media Group.</p><p><br /></p><p>Want us to unbox something? Make a suggestion at <a href=\"https://lmg.gg/7s34e\">https://lmg.gg/7s34e</a></p>",
				"type": "blogPost",
				"channel": {
					"id": "64135da7ce81077a8480c679",
					"creator": "59f94c0bdd241b70349eb72b",
					"title": "ShortCircuit",
					"urlname": "shortcircuit",
					"about": "What's in the box? Let's find out!\n\nOfficial channel under Linus Media Group.",
					"order": 3,
					"cover": null,
					"card": null,
					"icon": {
						"width": 88,
						"height": 88,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/64135da7ce81077a8480c679/470304051261927_1678990806883.jpeg",
						"childImages": []
					}
				},
				"tags": [
					"ShortCircuit"
				],
				"attachmentOrder": [
					"uUfxztSX6A"
				],
				"releaseDate": "2023-04-12T19:09:00.024Z",
				"likes": 539,
				"dislikes": 3,
				"score": 536,
				"comments": 175,
				"creator": {
					"id": "59f94c0bdd241b70349eb72b",
					"owner": {
						"id": "59f94c0bdd241b70349eb723",
						"username": "Linus"
					},
					"title": "LinusTechTips",
					"urlname": "linustechtips",
					"description": "We make entertaining videos about technology, including tech reviews, showcases and other content.",
					"about": "# We're LinusTechTips\nWe make videos and stuff, cool eh?",
					"category": {
						"id": "59f94c0bdd241b70349eb727",
						"title": "Technology"
					},
					"cover": {
						"width": 1990,
						"height": 519,
						"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867.jpeg",
						"childImages": [
							{
								"width": 1245,
								"height": 325,
								"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867_1245x325.jpeg"
							}
						]
					},
					"icon": {
						"width": 600,
						"height": 600,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205.jpeg",
						"childImages": [
							{
								"width": 250,
								"height": 250,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_250x250.jpeg"
							},
							{
								"width": 100,
								"height": 100,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_100x100.jpeg"
							}
						]
					},
					"liveStream": {
						"id": "5c13f3c006f1be15e08e05c0",
						"title": "I Give Up - WAN Show April 14, 2023",
						"description": "<p>JumpCloud offers an Open Directory Platform that makes it possible to unify your technology stack across identity, access, and device management. Learn more here: <a href=\"https://lmg.gg/JumpCloud\" rel=\"noopener noreferrer\" target=\"_blank\">https://lmg.gg/JumpCloud</a></p><p>Check out Goliath today and save 20% at <a href=\"https://lmg.gg/Goliath-Technologies\" rel=\"noopener noreferrer\" target=\"_blank\">https://lmg.gg/Goliath-Technologies</a></p><p>Buy a Seasonic Prime TX 1000W PSU:<a href=\"https://geni.us/aryiquT\" rel=\"noopener noreferrer\" target=\"_blank\"> https://geni.us/aryiquT</a></p><p><br></p><p>Purchases made through some store links may provide some compensation to Linus Media Group.</p><p><br></p><p>Podcast Download: TBD</p>",
						"thumbnail": {
							"width": 1920,
							"height": 1080,
							"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325.jpeg",
							"childImages": [
								{
									"width": 400,
									"height": 225,
									"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325_400x225.jpeg"
								},
								{
									"width": 1200,
									"height": 675,
									"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325_1200x675.jpeg"
								}
							]
						},
						"owner": "59f94c0bdd241b70349eb72b",
						"channel": "63fe42c309e691e4e36de93d",
						"streamPath": "/api/video/v1/us-east-1.758417551536.channel.yKkxur4ukc0B.m3u8",
						"offline": {
							"title": "Offline",
							"description": "We're offline for now – please check back later!",
							"thumbnail": {
								"width": 1920,
								"height": 1080,
								"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026.jpeg",
								"childImages": [
									{
										"width": 400,
										"height": 225,
										"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_400x225.jpeg"
									},
									{
										"width": 1200,
										"height": 675,
										"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_1200x675.jpeg"
									}
								]
							}
						}
					},
					"subscriptionPlans": [
						{
							"id": "5d48d0306825b5780db93d07",
							"title": "LTT Supporter",
							"description": "- 2 Exclusives Per Week (Meet the Team, Extras, Behind the Scenes) \n- Exclusive livestreams\n- Save $10 by purchasing an annual subscription\n- Our gratitude for your support",
							"price": "5.00",
							"priceYearly": "50.00",
							"currency": "usd",
							"logo": null,
							"interval": "month",
							"featured": true,
							"allowGrandfatheredAccess": false,
							"discordServers": [],
							"discordRoles": []
						},
						{
							"id": "5e0ba6ac14e2590f760a0f0f",
							"title": "LTT Supporter Plus",
							"description": "- 4K Bitrate Streaming\n- 2 Exclusives Per Week (Meet the Team, Extras, Behind the Scenes) \n- Exclusive livestreams\n- Save $20 by purchasing an annual subscription\n- Our gratitude for your support",
							"price": "10.00",
							"priceYearly": "100.00",
							"currency": "usd",
							"logo": null,
							"interval": "month",
							"featured": true,
							"allowGrandfatheredAccess": false,
							"discordServers": [],
							"discordRoles": []
						}
					],
					"discoverable": true,
					"subscriberCountDisplay": "total",
					"incomeDisplay": false,
					"defaultChannel": "63fe42c309e691e4e36de93d",
					"channels": [
						"63fe42c309e691e4e36de93d",
						"6413534d88c13c181c3e2809",
						"64135da7ce81077a8480c679",
						"64135e27c773b27ff22c97eb",
						"64135e901ebaee42e258eb0b",
						"64135ed078d6262f717341b7",
						"64135f82fc76ab7f9fbdc876",
						"6413623f5b12cca228a28e78"
					],
					"card": {
						"width": 375,
						"height": 500,
						"path": "https://pbs.floatplane.com/creator_card/59f94c0bdd241b70349eb72b/281467946609369_1551250329871.jpeg",
						"childImages": [
							{
								"width": 300,
								"height": 400,
								"path": "https://pbs.floatplane.com/creator_card/59f94c0bdd241b70349eb72b/281467946609369_1551250329871_300x400.jpeg"
							}
						]
					}
				},
				"wasReleasedSilently": false,
				"metadata": {
					"hasVideo": true,
					"videoCount": 1,
					"videoDuration": 1024,
					"hasAudio": false,
					"audioCount": 0,
					"audioDuration": 0,
					"hasPicture": false,
					"pictureCount": 0,
					"isFeatured": false,
					"hasGallery": false,
					"galleryCount": 0
				},
				"galleryAttachments": [],
				"thumbnail": {
					"width": 1920,
					"height": 1080,
					"path": "https://pbs.floatplane.com/blogPost_thumbnails/oDOEnx1aWA/933964381318613_1681258925167.jpeg",
					"childImages": [
						{
							"width": 400,
							"height": 225,
							"path": "https://pbs.floatplane.com/blogPost_thumbnails/oDOEnx1aWA/933964381318613_1681258925167_400x225.jpeg"
						},
						{
							"width": 1200,
							"height": 675,
							"path": "https://pbs.floatplane.com/blogPost_thumbnails/oDOEnx1aWA/933964381318613_1681258925167_1200x675.jpeg"
						}
					]
				},
				"isAccessible": true,
				"videoAttachments": [
					"uUfxztSX6A"
				],
				"audioAttachments": [],
				"pictureAttachments": []
			},
			{
				"id": "0cRrjWGEi0",
				"guid": "0cRrjWGEi0",
				"title": "I’m Dreading this Review – RTX 4070",
				"text": "<p>Nvidia's RTX 4070 is a complicated card.. on one hand it is the best value we've seen in years, but on the other everyone is still mad.</p>",
				"type": "blogPost",
				"channel": {
					"id": "63fe42c309e691e4e36de93d",
					"creator": "59f94c0bdd241b70349eb72b",
					"title": "Linus Tech Tips",
					"urlname": "main",
					"about": "# We're LinusTechTips\nWe make videos and stuff, cool eh?",
					"order": 0,
					"cover": null,
					"card": null,
					"icon": {
						"width": 600,
						"height": 600,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205.jpeg",
						"childImages": [
							{
								"width": 250,
								"height": 250,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_250x250.jpeg"
							},
							{
								"width": 100,
								"height": 100,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_100x100.jpeg"
							}
						]
					}
				},
				"tags": [],
				"attachmentOrder": [
					"LbI6cAVs4X"
				],
				"releaseDate": "2023-04-12T13:00:00.052Z",
				"likes": 644,
				"dislikes": 8,
				"score": 636,
				"comments": 154,
				"creator": {
					"id": "59f94c0bdd241b70349eb72b",
					"owner": {
						"id": "59f94c0bdd241b70349eb723",
						"username": "Linus"
					},
					"title": "LinusTechTips",
					"urlname": "linustechtips",
					"description": "We make entertaining videos about technology, including tech reviews, showcases and other content.",
					"about": "# We're LinusTechTips\nWe make videos and stuff, cool eh?",
					"category": {
						"id": "59f94c0bdd241b70349eb727",
						"title": "Technology"
					},
					"cover": {
						"width": 1990,
						"height": 519,
						"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867.jpeg",
						"childImages": [
							{
								"width": 1245,
								"height": 325,
								"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867_1245x325.jpeg"
							}
						]
					},
					"icon": {
						"width": 600,
						"height": 600,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205.jpeg",
						"childImages": [
							{
								"width": 250,
								"height": 250,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_250x250.jpeg"
							},
							{
								"width": 100,
								"height": 100,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_100x100.jpeg"
							}
						]
					},
					"liveStream": {
						"id": "5c13f3c006f1be15e08e05c0",
						"title": "I Give Up - WAN Show April 14, 2023",
						"description": "<p>JumpCloud offers an Open Directory Platform that makes it possible to unify your technology stack across identity, access, and device management. Learn more here: <a href=\"https://lmg.gg/JumpCloud\" rel=\"noopener noreferrer\" target=\"_blank\">https://lmg.gg/JumpCloud</a></p><p>Check out Goliath today and save 20% at <a href=\"https://lmg.gg/Goliath-Technologies\" rel=\"noopener noreferrer\" target=\"_blank\">https://lmg.gg/Goliath-Technologies</a></p><p>Buy a Seasonic Prime TX 1000W PSU:<a href=\"https://geni.us/aryiquT\" rel=\"noopener noreferrer\" target=\"_blank\"> https://geni.us/aryiquT</a></p><p><br></p><p>Purchases made through some store links may provide some compensation to Linus Media Group.</p><p><br></p><p>Podcast Download: TBD</p>",
						"thumbnail": {
							"width": 1920,
							"height": 1080,
							"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325.jpeg",
							"childImages": [
								{
									"width": 400,
									"height": 225,
									"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325_400x225.jpeg"
								},
								{
									"width": 1200,
									"height": 675,
									"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325_1200x675.jpeg"
								}
							]
						},
						"owner": "59f94c0bdd241b70349eb72b",
						"channel": "63fe42c309e691e4e36de93d",
						"streamPath": "/api/video/v1/us-east-1.758417551536.channel.yKkxur4ukc0B.m3u8",
						"offline": {
							"title": "Offline",
							"description": "We're offline for now – please check back later!",
							"thumbnail": {
								"width": 1920,
								"height": 1080,
								"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026.jpeg",
								"childImages": [
									{
										"width": 400,
										"height": 225,
										"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_400x225.jpeg"
									},
									{
										"width": 1200,
										"height": 675,
										"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_1200x675.jpeg"
									}
								]
							}
						}
					},
					"subscriptionPlans": [
						{
							"id": "5d48d0306825b5780db93d07",
							"title": "LTT Supporter",
							"description": "- 2 Exclusives Per Week (Meet the Team, Extras, Behind the Scenes) \n- Exclusive livestreams\n- Save $10 by purchasing an annual subscription\n- Our gratitude for your support",
							"price": "5.00",
							"priceYearly": "50.00",
							"currency": "usd",
							"logo": null,
							"interval": "month",
							"featured": true,
							"allowGrandfatheredAccess": false,
							"discordServers": [],
							"discordRoles": []
						},
						{
							"id": "5e0ba6ac14e2590f760a0f0f",
							"title": "LTT Supporter Plus",
							"description": "- 4K Bitrate Streaming\n- 2 Exclusives Per Week (Meet the Team, Extras, Behind the Scenes) \n- Exclusive livestreams\n- Save $20 by purchasing an annual subscription\n- Our gratitude for your support",
							"price": "10.00",
							"priceYearly": "100.00",
							"currency": "usd",
							"logo": null,
							"interval": "month",
							"featured": true,
							"allowGrandfatheredAccess": false,
							"discordServers": [],
							"discordRoles": []
						}
					],
					"discoverable": true,
					"subscriberCountDisplay": "total",
					"incomeDisplay": false,
					"defaultChannel": "63fe42c309e691e4e36de93d",
					"channels": [
						"63fe42c309e691e4e36de93d",
						"6413534d88c13c181c3e2809",
						"64135da7ce81077a8480c679",
						"64135e27c773b27ff22c97eb",
						"64135e901ebaee42e258eb0b",
						"64135ed078d6262f717341b7",
						"64135f82fc76ab7f9fbdc876",
						"6413623f5b12cca228a28e78"
					],
					"card": {
						"width": 375,
						"height": 500,
						"path": "https://pbs.floatplane.com/creator_card/59f94c0bdd241b70349eb72b/281467946609369_1551250329871.jpeg",
						"childImages": [
							{
								"width": 300,
								"height": 400,
								"path": "https://pbs.floatplane.com/creator_card/59f94c0bdd241b70349eb72b/281467946609369_1551250329871_300x400.jpeg"
							}
						]
					}
				},
				"wasReleasedSilently": false,
				"metadata": {
					"hasVideo": true,
					"videoCount": 1,
					"videoDuration": 644,
					"hasAudio": false,
					"audioCount": 0,
					"audioDuration": 0,
					"hasPicture": false,
					"pictureCount": 0,
					"isFeatured": false,
					"hasGallery": false,
					"galleryCount": 0
				},
				"galleryAttachments": [],
				"thumbnail": {
					"width": 1920,
					"height": 1080,
					"path": "https://pbs.floatplane.com/blogPost_thumbnails/0cRrjWGEi0/015351613571339_1681263716878.jpeg",
					"childImages": [
						{
							"width": 400,
							"height": 225,
							"path": "https://pbs.floatplane.com/blogPost_thumbnails/0cRrjWGEi0/015351613571339_1681263716878_400x225.jpeg"
						},
						{
							"width": 1200,
							"height": 675,
							"path": "https://pbs.floatplane.com/blogPost_thumbnails/0cRrjWGEi0/015351613571339_1681263716878_1200x675.jpeg"
						}
					]
				},
				"isAccessible": true,
				"videoAttachments": [
					"LbI6cAVs4X"
				],
				"audioAttachments": [],
				"pictureAttachments": []
			},
			{
				"id": "OFHLAvgQmZ",
				"guid": "OFHLAvgQmZ",
				"title": "FP Exclusive: We Got a Metal 3D Printer!",
				"text": "<p>Come join Tynan as he unwraps a new toy for the company! Just a quick lil' unboxing vlog for y'all.</p>",
				"type": "blogPost",
				"channel": {
					"id": "6413623f5b12cca228a28e78",
					"creator": "59f94c0bdd241b70349eb72b",
					"title": "FP Exclusive",
					"urlname": "fpexclusive",
					"about": "wow... so empty",
					"order": 1,
					"cover": null,
					"card": null,
					"icon": {
						"width": 720,
						"height": 720,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/6413623f5b12cca228a28e78/069457536750544_1678991936484.jpeg",
						"childImages": [
							{
								"width": 100,
								"height": 100,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/6413623f5b12cca228a28e78/069457536750544_1678991936484_100x100.jpeg"
							},
							{
								"width": 250,
								"height": 250,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/6413623f5b12cca228a28e78/069457536750544_1678991936484_250x250.jpeg"
							}
						]
					}
				},
				"tags": [],
				"attachmentOrder": [
					"QxDkqPTKJ9",
					"8oaa1K3I5p"
				],
				"releaseDate": "2023-04-12T04:53:00.055Z",
				"likes": 831,
				"dislikes": 5,
				"score": 826,
				"comments": 165,
				"creator": {
					"id": "59f94c0bdd241b70349eb72b",
					"owner": {
						"id": "59f94c0bdd241b70349eb723",
						"username": "Linus"
					},
					"title": "LinusTechTips",
					"urlname": "linustechtips",
					"description": "We make entertaining videos about technology, including tech reviews, showcases and other content.",
					"about": "# We're LinusTechTips\nWe make videos and stuff, cool eh?",
					"category": {
						"id": "59f94c0bdd241b70349eb727",
						"title": "Technology"
					},
					"cover": {
						"width": 1990,
						"height": 519,
						"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867.jpeg",
						"childImages": [
							{
								"width": 1245,
								"height": 325,
								"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867_1245x325.jpeg"
							}
						]
					},
					"icon": {
						"width": 600,
						"height": 600,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205.jpeg",
						"childImages": [
							{
								"width": 250,
								"height": 250,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_250x250.jpeg"
							},
							{
								"width": 100,
								"height": 100,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_100x100.jpeg"
							}
						]
					},
					"liveStream": {
						"id": "5c13f3c006f1be15e08e05c0",
						"title": "I Give Up - WAN Show April 14, 2023",
						"description": "<p>JumpCloud offers an Open Directory Platform that makes it possible to unify your technology stack across identity, access, and device management. Learn more here: <a href=\"https://lmg.gg/JumpCloud\" rel=\"noopener noreferrer\" target=\"_blank\">https://lmg.gg/JumpCloud</a></p><p>Check out Goliath today and save 20% at <a href=\"https://lmg.gg/Goliath-Technologies\" rel=\"noopener noreferrer\" target=\"_blank\">https://lmg.gg/Goliath-Technologies</a></p><p>Buy a Seasonic Prime TX 1000W PSU:<a href=\"https://geni.us/aryiquT\" rel=\"noopener noreferrer\" target=\"_blank\"> https://geni.us/aryiquT</a></p><p><br></p><p>Purchases made through some store links may provide some compensation to Linus Media Group.</p><p><br></p><p>Podcast Download: TBD</p>",
						"thumbnail": {
							"width": 1920,
							"height": 1080,
							"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325.jpeg",
							"childImages": [
								{
									"width": 400,
									"height": 225,
									"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325_400x225.jpeg"
								},
								{
									"width": 1200,
									"height": 675,
									"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325_1200x675.jpeg"
								}
							]
						},
						"owner": "59f94c0bdd241b70349eb72b",
						"channel": "63fe42c309e691e4e36de93d",
						"streamPath": "/api/video/v1/us-east-1.758417551536.channel.yKkxur4ukc0B.m3u8",
						"offline": {
							"title": "Offline",
							"description": "We're offline for now – please check back later!",
							"thumbnail": {
								"width": 1920,
								"height": 1080,
								"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026.jpeg",
								"childImages": [
									{
										"width": 400,
										"height": 225,
										"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_400x225.jpeg"
									},
									{
										"width": 1200,
										"height": 675,
										"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_1200x675.jpeg"
									}
								]
							}
						}
					},
					"subscriptionPlans": [
						{
							"id": "5d48d0306825b5780db93d07",
							"title": "LTT Supporter",
							"description": "- 2 Exclusives Per Week (Meet the Team, Extras, Behind the Scenes) \n- Exclusive livestreams\n- Save $10 by purchasing an annual subscription\n- Our gratitude for your support",
							"price": "5.00",
							"priceYearly": "50.00",
							"currency": "usd",
							"logo": null,
							"interval": "month",
							"featured": true,
							"allowGrandfatheredAccess": false,
							"discordServers": [],
							"discordRoles": []
						},
						{
							"id": "5e0ba6ac14e2590f760a0f0f",
							"title": "LTT Supporter Plus",
							"description": "- 4K Bitrate Streaming\n- 2 Exclusives Per Week (Meet the Team, Extras, Behind the Scenes) \n- Exclusive livestreams\n- Save $20 by purchasing an annual subscription\n- Our gratitude for your support",
							"price": "10.00",
							"priceYearly": "100.00",
							"currency": "usd",
							"logo": null,
							"interval": "month",
							"featured": true,
							"allowGrandfatheredAccess": false,
							"discordServers": [],
							"discordRoles": []
						}
					],
					"discoverable": true,
					"subscriberCountDisplay": "total",
					"incomeDisplay": false,
					"defaultChannel": "63fe42c309e691e4e36de93d",
					"channels": [
						"63fe42c309e691e4e36de93d",
						"6413534d88c13c181c3e2809",
						"64135da7ce81077a8480c679",
						"64135e27c773b27ff22c97eb",
						"64135e901ebaee42e258eb0b",
						"64135ed078d6262f717341b7",
						"64135f82fc76ab7f9fbdc876",
						"6413623f5b12cca228a28e78"
					],
					"card": {
						"width": 375,
						"height": 500,
						"path": "https://pbs.floatplane.com/creator_card/59f94c0bdd241b70349eb72b/281467946609369_1551250329871.jpeg",
						"childImages": [
							{
								"width": 300,
								"height": 400,
								"path": "https://pbs.floatplane.com/creator_card/59f94c0bdd241b70349eb72b/281467946609369_1551250329871_300x400.jpeg"
							}
						]
					}
				},
				"wasReleasedSilently": false,
				"metadata": {
					"hasVideo": true,
					"videoCount": 2,
					"videoDuration": 1120,
					"hasAudio": false,
					"audioCount": 0,
					"audioDuration": 0,
					"hasPicture": false,
					"pictureCount": 0,
					"isFeatured": false,
					"hasGallery": false,
					"galleryCount": 0
				},
				"galleryAttachments": [],
				"thumbnail": {
					"width": 1920,
					"height": 1080,
					"path": "https://pbs.floatplane.com/blogPost_thumbnails/OFHLAvgQmZ/166276703050354_1681258482173.jpeg",
					"childImages": [
						{
							"width": 400,
							"height": 225,
							"path": "https://pbs.floatplane.com/blogPost_thumbnails/OFHLAvgQmZ/166276703050354_1681258482173_400x225.jpeg"
						},
						{
							"width": 1200,
							"height": 675,
							"path": "https://pbs.floatplane.com/blogPost_thumbnails/OFHLAvgQmZ/166276703050354_1681258482173_1200x675.jpeg"
						}
					]
				},
				"isAccessible": true,
				"videoAttachments": [
					"8oaa1K3I5p",
					"QxDkqPTKJ9"
				],
				"audioAttachments": [],
				"pictureAttachments": []
			},
			{
				"id": "Fe5KUiR8dn",
				"guid": "Fe5KUiR8dn",
				"title": "SC: I regret my purchase... - MSI MEG 342C",
				"text": "<p>Plouffe loves his Alienware AW3423DW monitor. It's got a high refresh rate, QD-OLED panel, nicely curved screen, and a great design... but now there's competition! MSI's new MEG 342C has a tasteful black and gold colour scheme, a nice touch of RGB, and a high-powered USB-C port while still maintaining the excellent QD-OLED panel the Alienware does. Is Plouffe's favourite monitor about to change?</p><p><br /></p><p>Buy a MSI 34\" 175Hz MEG 342C Curved Gaming Monitor: <a href=\"https://geni.us/kAIIxs\">https://geni.us/kAIIxs</a></p><p>Buy an Alienware 34\" 175Hz AW3423DW Curved Gaming Monitor: <a href=\"https://geni.us/qpmkqcv\">https://geni.us/qpmkqcv</a></p><p><br /></p><p>Purchases made through some store links may provide some compensation to Linus Media Group.</p><p><br /></p><p>Want us to unbox something? Make a suggestion at <a href=\"https://lmg.gg/7s34e\">https://lmg.gg/7s34e</a></p>",
				"type": "blogPost",
				"channel": {
					"id": "64135da7ce81077a8480c679",
					"creator": "59f94c0bdd241b70349eb72b",
					"title": "ShortCircuit",
					"urlname": "shortcircuit",
					"about": "What's in the box? Let's find out!\n\nOfficial channel under Linus Media Group.",
					"order": 3,
					"cover": null,
					"card": null,
					"icon": {
						"width": 88,
						"height": 88,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/64135da7ce81077a8480c679/470304051261927_1678990806883.jpeg",
						"childImages": []
					}
				},
				"tags": [
					"ShortCircuit"
				],
				"attachmentOrder": [
					"XrigfqxRcY"
				],
				"releaseDate": "2023-04-11T20:00:00.090Z",
				"likes": 297,
				"dislikes": 9,
				"score": 288,
				"comments": 74,
				"creator": {
					"id": "59f94c0bdd241b70349eb72b",
					"owner": {
						"id": "59f94c0bdd241b70349eb723",
						"username": "Linus"
					},
					"title": "LinusTechTips",
					"urlname": "linustechtips",
					"description": "We make entertaining videos about technology, including tech reviews, showcases and other content.",
					"about": "# We're LinusTechTips\nWe make videos and stuff, cool eh?",
					"category": {
						"id": "59f94c0bdd241b70349eb727",
						"title": "Technology"
					},
					"cover": {
						"width": 1990,
						"height": 519,
						"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867.jpeg",
						"childImages": [
							{
								"width": 1245,
								"height": 325,
								"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867_1245x325.jpeg"
							}
						]
					},
					"icon": {
						"width": 600,
						"height": 600,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205.jpeg",
						"childImages": [
							{
								"width": 250,
								"height": 250,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_250x250.jpeg"
							},
							{
								"width": 100,
								"height": 100,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_100x100.jpeg"
							}
						]
					},
					"liveStream": {
						"id": "5c13f3c006f1be15e08e05c0",
						"title": "I Give Up - WAN Show April 14, 2023",
						"description": "<p>JumpCloud offers an Open Directory Platform that makes it possible to unify your technology stack across identity, access, and device management. Learn more here: <a href=\"https://lmg.gg/JumpCloud\" rel=\"noopener noreferrer\" target=\"_blank\">https://lmg.gg/JumpCloud</a></p><p>Check out Goliath today and save 20% at <a href=\"https://lmg.gg/Goliath-Technologies\" rel=\"noopener noreferrer\" target=\"_blank\">https://lmg.gg/Goliath-Technologies</a></p><p>Buy a Seasonic Prime TX 1000W PSU:<a href=\"https://geni.us/aryiquT\" rel=\"noopener noreferrer\" target=\"_blank\"> https://geni.us/aryiquT</a></p><p><br></p><p>Purchases made through some store links may provide some compensation to Linus Media Group.</p><p><br></p><p>Podcast Download: TBD</p>",
						"thumbnail": {
							"width": 1920,
							"height": 1080,
							"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325.jpeg",
							"childImages": [
								{
									"width": 400,
									"height": 225,
									"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325_400x225.jpeg"
								},
								{
									"width": 1200,
									"height": 675,
									"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325_1200x675.jpeg"
								}
							]
						},
						"owner": "59f94c0bdd241b70349eb72b",
						"channel": "63fe42c309e691e4e36de93d",
						"streamPath": "/api/video/v1/us-east-1.758417551536.channel.yKkxur4ukc0B.m3u8",
						"offline": {
							"title": "Offline",
							"description": "We're offline for now – please check back later!",
							"thumbnail": {
								"width": 1920,
								"height": 1080,
								"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026.jpeg",
								"childImages": [
									{
										"width": 400,
										"height": 225,
										"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_400x225.jpeg"
									},
									{
										"width": 1200,
										"height": 675,
										"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_1200x675.jpeg"
									}
								]
							}
						}
					},
					"subscriptionPlans": [
						{
							"id": "5d48d0306825b5780db93d07",
							"title": "LTT Supporter",
							"description": "- 2 Exclusives Per Week (Meet the Team, Extras, Behind the Scenes) \n- Exclusive livestreams\n- Save $10 by purchasing an annual subscription\n- Our gratitude for your support",
							"price": "5.00",
							"priceYearly": "50.00",
							"currency": "usd",
							"logo": null,
							"interval": "month",
							"featured": true,
							"allowGrandfatheredAccess": false,
							"discordServers": [],
							"discordRoles": []
						},
						{
							"id": "5e0ba6ac14e2590f760a0f0f",
							"title": "LTT Supporter Plus",
							"description": "- 4K Bitrate Streaming\n- 2 Exclusives Per Week (Meet the Team, Extras, Behind the Scenes) \n- Exclusive livestreams\n- Save $20 by purchasing an annual subscription\n- Our gratitude for your support",
							"price": "10.00",
							"priceYearly": "100.00",
							"currency": "usd",
							"logo": null,
							"interval": "month",
							"featured": true,
							"allowGrandfatheredAccess": false,
							"discordServers": [],
							"discordRoles": []
						}
					],
					"discoverable": true,
					"subscriberCountDisplay": "total",
					"incomeDisplay": false,
					"defaultChannel": "63fe42c309e691e4e36de93d",
					"channels": [
						"63fe42c309e691e4e36de93d",
						"6413534d88c13c181c3e2809",
						"64135da7ce81077a8480c679",
						"64135e27c773b27ff22c97eb",
						"64135e901ebaee42e258eb0b",
						"64135ed078d6262f717341b7",
						"64135f82fc76ab7f9fbdc876",
						"6413623f5b12cca228a28e78"
					],
					"card": {
						"width": 375,
						"height": 500,
						"path": "https://pbs.floatplane.com/creator_card/59f94c0bdd241b70349eb72b/281467946609369_1551250329871.jpeg",
						"childImages": [
							{
								"width": 300,
								"height": 400,
								"path": "https://pbs.floatplane.com/creator_card/59f94c0bdd241b70349eb72b/281467946609369_1551250329871_300x400.jpeg"
							}
						]
					}
				},
				"wasReleasedSilently": false,
				"metadata": {
					"hasVideo": true,
					"videoCount": 1,
					"videoDuration": 1069,
					"hasAudio": false,
					"audioCount": 0,
					"audioDuration": 0,
					"hasPicture": false,
					"pictureCount": 0,
					"isFeatured": false,
					"hasGallery": false,
					"galleryCount": 0
				},
				"galleryAttachments": [],
				"thumbnail": {
					"width": 1920,
					"height": 1080,
					"path": "https://pbs.floatplane.com/blogPost_thumbnails/Fe5KUiR8dn/756033475272329_1680739743101.jpeg",
					"childImages": [
						{
							"width": 400,
							"height": 225,
							"path": "https://pbs.floatplane.com/blogPost_thumbnails/Fe5KUiR8dn/756033475272329_1680739743101_400x225.jpeg"
						},
						{
							"width": 1200,
							"height": 675,
							"path": "https://pbs.floatplane.com/blogPost_thumbnails/Fe5KUiR8dn/756033475272329_1680739743101_1200x675.jpeg"
						}
					]
				},
				"isAccessible": true,
				"videoAttachments": [
					"XrigfqxRcY"
				],
				"audioAttachments": [],
				"pictureAttachments": []
			},
			{
				"id": "SD7R4RJ9rq",
				"guid": "SD7R4RJ9rq",
				"title": "TQ: The Computers That Heat Homes",
				"text": "<p><br /></p>",
				"type": "blogPost",
				"channel": {
					"id": "64135e27c773b27ff22c97eb",
					"creator": "59f94c0bdd241b70349eb72b",
					"title": "Techquickie",
					"urlname": "techquickie",
					"about": "Ever wanted to learn more about your favorite gadgets or a trending topic in tech? \n\nWith a mix of humor, cynicism, and insight, Techquickie brings you the answers to all your tech questions every Tuesday and Friday.",
					"order": 5,
					"cover": null,
					"card": null,
					"icon": {
						"width": 88,
						"height": 88,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/64135e27c773b27ff22c97eb/666841640245092_1678990909616.jpeg",
						"childImages": []
					}
				},
				"tags": [],
				"attachmentOrder": [
					"VfFTXLfDfH"
				],
				"releaseDate": "2023-04-11T19:06:00.022Z",
				"likes": 367,
				"dislikes": 4,
				"score": 363,
				"comments": 47,
				"creator": {
					"id": "59f94c0bdd241b70349eb72b",
					"owner": {
						"id": "59f94c0bdd241b70349eb723",
						"username": "Linus"
					},
					"title": "LinusTechTips",
					"urlname": "linustechtips",
					"description": "We make entertaining videos about technology, including tech reviews, showcases and other content.",
					"about": "# We're LinusTechTips\nWe make videos and stuff, cool eh?",
					"category": {
						"id": "59f94c0bdd241b70349eb727",
						"title": "Technology"
					},
					"cover": {
						"width": 1990,
						"height": 519,
						"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867.jpeg",
						"childImages": [
							{
								"width": 1245,
								"height": 325,
								"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867_1245x325.jpeg"
							}
						]
					},
					"icon": {
						"width": 600,
						"height": 600,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205.jpeg",
						"childImages": [
							{
								"width": 250,
								"height": 250,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_250x250.jpeg"
							},
							{
								"width": 100,
								"height": 100,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_100x100.jpeg"
							}
						]
					},
					"liveStream": {
						"id": "5c13f3c006f1be15e08e05c0",
						"title": "I Give Up - WAN Show April 14, 2023",
						"description": "<p>JumpCloud offers an Open Directory Platform that makes it possible to unify your technology stack across identity, access, and device management. Learn more here: <a href=\"https://lmg.gg/JumpCloud\" rel=\"noopener noreferrer\" target=\"_blank\">https://lmg.gg/JumpCloud</a></p><p>Check out Goliath today and save 20% at <a href=\"https://lmg.gg/Goliath-Technologies\" rel=\"noopener noreferrer\" target=\"_blank\">https://lmg.gg/Goliath-Technologies</a></p><p>Buy a Seasonic Prime TX 1000W PSU:<a href=\"https://geni.us/aryiquT\" rel=\"noopener noreferrer\" target=\"_blank\"> https://geni.us/aryiquT</a></p><p><br></p><p>Purchases made through some store links may provide some compensation to Linus Media Group.</p><p><br></p><p>Podcast Download: TBD</p>",
						"thumbnail": {
							"width": 1920,
							"height": 1080,
							"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325.jpeg",
							"childImages": [
								{
									"width": 400,
									"height": 225,
									"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325_400x225.jpeg"
								},
								{
									"width": 1200,
									"height": 675,
									"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325_1200x675.jpeg"
								}
							]
						},
						"owner": "59f94c0bdd241b70349eb72b",
						"channel": "63fe42c309e691e4e36de93d",
						"streamPath": "/api/video/v1/us-east-1.758417551536.channel.yKkxur4ukc0B.m3u8",
						"offline": {
							"title": "Offline",
							"description": "We're offline for now – please check back later!",
							"thumbnail": {
								"width": 1920,
								"height": 1080,
								"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026.jpeg",
								"childImages": [
									{
										"width": 400,
										"height": 225,
										"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_400x225.jpeg"
									},
									{
										"width": 1200,
										"height": 675,
										"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_1200x675.jpeg"
									}
								]
							}
						}
					},
					"subscriptionPlans": [
						{
							"id": "5d48d0306825b5780db93d07",
							"title": "LTT Supporter",
							"description": "- 2 Exclusives Per Week (Meet the Team, Extras, Behind the Scenes) \n- Exclusive livestreams\n- Save $10 by purchasing an annual subscription\n- Our gratitude for your support",
							"price": "5.00",
							"priceYearly": "50.00",
							"currency": "usd",
							"logo": null,
							"interval": "month",
							"featured": true,
							"allowGrandfatheredAccess": false,
							"discordServers": [],
							"discordRoles": []
						},
						{
							"id": "5e0ba6ac14e2590f760a0f0f",
							"title": "LTT Supporter Plus",
							"description": "- 4K Bitrate Streaming\n- 2 Exclusives Per Week (Meet the Team, Extras, Behind the Scenes) \n- Exclusive livestreams\n- Save $20 by purchasing an annual subscription\n- Our gratitude for your support",
							"price": "10.00",
							"priceYearly": "100.00",
							"currency": "usd",
							"logo": null,
							"interval": "month",
							"featured": true,
							"allowGrandfatheredAccess": false,
							"discordServers": [],
							"discordRoles": []
						}
					],
					"discoverable": true,
					"subscriberCountDisplay": "total",
					"incomeDisplay": false,
					"defaultChannel": "63fe42c309e691e4e36de93d",
					"channels": [
						"63fe42c309e691e4e36de93d",
						"6413534d88c13c181c3e2809",
						"64135da7ce81077a8480c679",
						"64135e27c773b27ff22c97eb",
						"64135e901ebaee42e258eb0b",
						"64135ed078d6262f717341b7",
						"64135f82fc76ab7f9fbdc876",
						"6413623f5b12cca228a28e78"
					],
					"card": {
						"width": 375,
						"height": 500,
						"path": "https://pbs.floatplane.com/creator_card/59f94c0bdd241b70349eb72b/281467946609369_1551250329871.jpeg",
						"childImages": [
							{
								"width": 300,
								"height": 400,
								"path": "https://pbs.floatplane.com/creator_card/59f94c0bdd241b70349eb72b/281467946609369_1551250329871_300x400.jpeg"
							}
						]
					}
				},
				"wasReleasedSilently": false,
				"metadata": {
					"hasVideo": true,
					"videoCount": 1,
					"videoDuration": 217,
					"hasAudio": false,
					"audioCount": 0,
					"audioDuration": 0,
					"hasPicture": false,
					"pictureCount": 0,
					"isFeatured": false,
					"hasGallery": false,
					"galleryCount": 0
				},
				"galleryAttachments": [],
				"thumbnail": {
					"width": 1920,
					"height": 1080,
					"path": "https://pbs.floatplane.com/blogPost_thumbnails/SD7R4RJ9rq/197170506873856_1681231067470.jpeg",
					"childImages": [
						{
							"width": 400,
							"height": 225,
							"path": "https://pbs.floatplane.com/blogPost_thumbnails/SD7R4RJ9rq/197170506873856_1681231067470_400x225.jpeg"
						},
						{
							"width": 1200,
							"height": 675,
							"path": "https://pbs.floatplane.com/blogPost_thumbnails/SD7R4RJ9rq/197170506873856_1681231067470_1200x675.jpeg"
						}
					]
				},
				"isAccessible": true,
				"videoAttachments": [
					"VfFTXLfDfH"
				],
				"audioAttachments": [],
				"pictureAttachments": []
			},
			{
				"id": "iG6XihWXqS",
				"guid": "iG6XihWXqS",
				"title": "The Amazon Basics CPU Cooler",
				"text": "<p>If you need something quickly and at an affordable price, there’s a good chance that Amazons in-house “Basics” brand has it. They’ve got all the essential items you need in your day-to-day life… and now they have a CPU cooler? Uh oh. Time for Labs to investigate.</p><p><br /></p><p>Check out the CPU Coolers we tested in this video:</p><p>Amazon Basics: <a href=\"https://lmg.gg/vnLsi\">https://lmg.gg/vnLsi</a></p><p>Cooler Master H412R: <a href=\"https://lmg.gg/SP1t1\">https://lmg.gg/SP1t1</a></p><p>be quiet! Pure Rock 2: <a href=\"https://lmg.gg/Oj7or\">https://lmg.gg/Oj7or</a></p><p>Noctua Redux NH-U12S: <a href=\"https://lmg.gg/eVy4q\">https://lmg.gg/eVy4q</a></p><p>Cooler Master Hyper 212: <a href=\"https://lmg.gg/DDGQC\">https://lmg.gg/DDGQC</a></p><p>ID-COOLING SE-214-XT: <a href=\"https://lmg.gg/87vdM\">https://lmg.gg/87vdM</a></p><p>Vetroo V5: <a href=\"https://lmg.gg/wjpyS\">https://lmg.gg/wjpyS</a></p><p>Jonsbo CR1400: <a href=\"https://lmg.gg/hV2cu\">https://lmg.gg/hV2cu</a></p><p>Buy an Intel Core i5 13600K CPU: <a href=\"https://geni.us/MAN5J\">https://geni.us/MAN5J</a></p><p>Buy a ZOTAC GeForce RTX 3090 Ti GPU: <a href=\"https://geni.us/4nfbWI\">https://geni.us/4nfbWI</a></p><p>Buy a Gigabyte Aorus Master Z690 Motherboard: <a href=\"https://geni.us/J9bX3\">https://geni.us/J9bX3</a></p><p>Buy G.Skill Trident Z5 6800MT/s CL34 2x16Gb RAM: <a href=\"https://geni.us/oaYlT\">https://geni.us/oaYlT</a></p><p>Purchases made through some store links may provide some compensation to Linus Media Group.</p>",
				"type": "blogPost",
				"channel": {
					"id": "63fe42c309e691e4e36de93d",
					"creator": "59f94c0bdd241b70349eb72b",
					"title": "Linus Tech Tips",
					"urlname": "main",
					"about": "# We're LinusTechTips\nWe make videos and stuff, cool eh?",
					"order": 0,
					"cover": null,
					"card": null,
					"icon": {
						"width": 600,
						"height": 600,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205.jpeg",
						"childImages": [
							{
								"width": 250,
								"height": 250,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_250x250.jpeg"
							},
							{
								"width": 100,
								"height": 100,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_100x100.jpeg"
							}
						]
					}
				},
				"tags": [],
				"attachmentOrder": [
					"Cd60UMOyc3"
				],
				"releaseDate": "2023-04-11T16:31:00.036Z",
				"likes": 623,
				"dislikes": 5,
				"score": 618,
				"comments": 66,
				"creator": {
					"id": "59f94c0bdd241b70349eb72b",
					"owner": {
						"id": "59f94c0bdd241b70349eb723",
						"username": "Linus"
					},
					"title": "LinusTechTips",
					"urlname": "linustechtips",
					"description": "We make entertaining videos about technology, including tech reviews, showcases and other content.",
					"about": "# We're LinusTechTips\nWe make videos and stuff, cool eh?",
					"category": {
						"id": "59f94c0bdd241b70349eb727",
						"title": "Technology"
					},
					"cover": {
						"width": 1990,
						"height": 519,
						"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867.jpeg",
						"childImages": [
							{
								"width": 1245,
								"height": 325,
								"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867_1245x325.jpeg"
							}
						]
					},
					"icon": {
						"width": 600,
						"height": 600,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205.jpeg",
						"childImages": [
							{
								"width": 250,
								"height": 250,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_250x250.jpeg"
							},
							{
								"width": 100,
								"height": 100,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_100x100.jpeg"
							}
						]
					},
					"liveStream": {
						"id": "5c13f3c006f1be15e08e05c0",
						"title": "I Give Up - WAN Show April 14, 2023",
						"description": "<p>JumpCloud offers an Open Directory Platform that makes it possible to unify your technology stack across identity, access, and device management. Learn more here: <a href=\"https://lmg.gg/JumpCloud\" rel=\"noopener noreferrer\" target=\"_blank\">https://lmg.gg/JumpCloud</a></p><p>Check out Goliath today and save 20% at <a href=\"https://lmg.gg/Goliath-Technologies\" rel=\"noopener noreferrer\" target=\"_blank\">https://lmg.gg/Goliath-Technologies</a></p><p>Buy a Seasonic Prime TX 1000W PSU:<a href=\"https://geni.us/aryiquT\" rel=\"noopener noreferrer\" target=\"_blank\"> https://geni.us/aryiquT</a></p><p><br></p><p>Purchases made through some store links may provide some compensation to Linus Media Group.</p><p><br></p><p>Podcast Download: TBD</p>",
						"thumbnail": {
							"width": 1920,
							"height": 1080,
							"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325.jpeg",
							"childImages": [
								{
									"width": 400,
									"height": 225,
									"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325_400x225.jpeg"
								},
								{
									"width": 1200,
									"height": 675,
									"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325_1200x675.jpeg"
								}
							]
						},
						"owner": "59f94c0bdd241b70349eb72b",
						"channel": "63fe42c309e691e4e36de93d",
						"streamPath": "/api/video/v1/us-east-1.758417551536.channel.yKkxur4ukc0B.m3u8",
						"offline": {
							"title": "Offline",
							"description": "We're offline for now – please check back later!",
							"thumbnail": {
								"width": 1920,
								"height": 1080,
								"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026.jpeg",
								"childImages": [
									{
										"width": 400,
										"height": 225,
										"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_400x225.jpeg"
									},
									{
										"width": 1200,
										"height": 675,
										"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_1200x675.jpeg"
									}
								]
							}
						}
					},
					"subscriptionPlans": [
						{
							"id": "5d48d0306825b5780db93d07",
							"title": "LTT Supporter",
							"description": "- 2 Exclusives Per Week (Meet the Team, Extras, Behind the Scenes) \n- Exclusive livestreams\n- Save $10 by purchasing an annual subscription\n- Our gratitude for your support",
							"price": "5.00",
							"priceYearly": "50.00",
							"currency": "usd",
							"logo": null,
							"interval": "month",
							"featured": true,
							"allowGrandfatheredAccess": false,
							"discordServers": [],
							"discordRoles": []
						},
						{
							"id": "5e0ba6ac14e2590f760a0f0f",
							"title": "LTT Supporter Plus",
							"description": "- 4K Bitrate Streaming\n- 2 Exclusives Per Week (Meet the Team, Extras, Behind the Scenes) \n- Exclusive livestreams\n- Save $20 by purchasing an annual subscription\n- Our gratitude for your support",
							"price": "10.00",
							"priceYearly": "100.00",
							"currency": "usd",
							"logo": null,
							"interval": "month",
							"featured": true,
							"allowGrandfatheredAccess": false,
							"discordServers": [],
							"discordRoles": []
						}
					],
					"discoverable": true,
					"subscriberCountDisplay": "total",
					"incomeDisplay": false,
					"defaultChannel": "63fe42c309e691e4e36de93d",
					"channels": [
						"63fe42c309e691e4e36de93d",
						"6413534d88c13c181c3e2809",
						"64135da7ce81077a8480c679",
						"64135e27c773b27ff22c97eb",
						"64135e901ebaee42e258eb0b",
						"64135ed078d6262f717341b7",
						"64135f82fc76ab7f9fbdc876",
						"6413623f5b12cca228a28e78"
					],
					"card": {
						"width": 375,
						"height": 500,
						"path": "https://pbs.floatplane.com/creator_card/59f94c0bdd241b70349eb72b/281467946609369_1551250329871.jpeg",
						"childImages": [
							{
								"width": 300,
								"height": 400,
								"path": "https://pbs.floatplane.com/creator_card/59f94c0bdd241b70349eb72b/281467946609369_1551250329871_300x400.jpeg"
							}
						]
					}
				},
				"wasReleasedSilently": false,
				"metadata": {
					"hasVideo": true,
					"videoCount": 1,
					"videoDuration": 436,
					"hasAudio": false,
					"audioCount": 0,
					"audioDuration": 0,
					"hasPicture": false,
					"pictureCount": 0,
					"isFeatured": false,
					"hasGallery": false,
					"galleryCount": 0
				},
				"galleryAttachments": [],
				"thumbnail": {
					"width": 1920,
					"height": 1080,
					"path": "https://pbs.floatplane.com/blogPost_thumbnails/iG6XihWXqS/643285885004260_1680907938625.jpeg",
					"childImages": [
						{
							"width": 400,
							"height": 225,
							"path": "https://pbs.floatplane.com/blogPost_thumbnails/iG6XihWXqS/643285885004260_1680907938625_400x225.jpeg"
						},
						{
							"width": 1200,
							"height": 675,
							"path": "https://pbs.floatplane.com/blogPost_thumbnails/iG6XihWXqS/643285885004260_1680907938625_1200x675.jpeg"
						}
					]
				},
				"isAccessible": true,
				"videoAttachments": [
					"Cd60UMOyc3"
				],
				"audioAttachments": [],
				"pictureAttachments": []
			},
			{
				"id": "tKQiFAE09W",
				"guid": "tKQiFAE09W",
				"title": "TL: Mac shipments drop, YouTube Premium 1080p, MSI hack + more!",
				"text": "<p><strong>NEWS SOURCES:</strong></p><p><br /></p><p>HOT NEW THING: SHIP-DROPPING</p><p>Apple’s shipments drop is worse than rest of industry</p><p><a href=\"https://finance.yahoo.com/news/apple-40-plunge-pc-shipments-043700361.html\">https://finance.yahoo.com/news/apple-40-plunge-pc-shipments-043700361.html</a></p><p><a href=\"https://www.idc.com/getdoc.jsp?containerId=prUS50565723#:~:text=4.%20Apple,%2D40.5%25\">https://www.idc.com/getdoc.jsp?containerId=prUS50565723#:~:text=4.%20Apple,%2D40.5%25</a></p><p>Windows 11 on Arm is ok?? <a href=\"https://www.reddit.com/r/hardware/comments/12ft5xb/comment/jfinl15/?utm_source=reddit&amp;utm_medium=web2x&amp;context=3\">https://www.reddit.com/r/hardware/comments/12ft5xb/comment/jfinl15/?utm_source=reddit&amp;utm_medium=web2x&amp;context=3</a></p><p>Haven’t paid attention since 2021 when SQ2 sucked <a href=\"https://youtu.be/OhESSZIXvCA?t=441\">https://youtu.be/OhESSZIXvCA?t=441</a></p><p>Ampere 128-Core Arm workstation runs Windows <a href=\"https://www.tomshardware.com/news/ampere-64-core-arm-workstation-runs-windows\">https://www.tomshardware.com/news/ampere-64-core-arm-workstation-runs-windows</a></p><p><a href=\"https://cdn.mos.cms.futurecdn.net/MzBPUPwUuMzf7dozGLLCxR-970-80.jpeg.webp\">https://cdn.mos.cms.futurecdn.net/MzBPUPwUuMzf7dozGLLCxR-970-80.jpeg.webp</a></p><p><a href=\"https://www.ipi.wiki/products/com-hpc-ampere-altra\">https://www.ipi.wiki/products/com-hpc-ampere-altra</a></p><p><br /></p><p>ZOOM IN. PAY FEE. NOW, ENHANCE</p><p>YouTube Premium users on iOS getting enhanced 1080p</p><p><a href=\"https://blog.youtube/news-and-events/5-premium-features-to-up-your-youtube-game/#:~:text=5.%20Enhance%20your%20video%20quality%20on%20iOS\">https://blog.youtube/news-and-events/5-premium-features-to-up-your-youtube-game/#:~:text=5.%20Enhance%20your%20video%20quality%20on%20iOS</a></p><p><a href=\"https://www.theverge.com/2023/4/10/23677141/youtube-premium-subscribers-higher-quality-video-1080p\">https://www.theverge.com/2023/4/10/23677141/youtube-premium-subscribers-higher-quality-video-1080p</a></p><p><a href=\"https://9to5google.com/2023/04/10/youtube-premium-shareplay/\">https://9to5google.com/2023/04/10/youtube-premium-shareplay/</a></p><p><a href=\"https://www.xda-developers.com/youtube-premium-playback-sync-shareplay-and-more/\">https://www.xda-developers.com/youtube-premium-playback-sync-shareplay-and-more/</a></p><p>not reducing bitrate for non-Premium users WE THINK <a href=\"https://www.androidpolice.com/youtube-1080p-premium-bitrate/\">https://www.androidpolice.com/youtube-1080p-premium-bitrate/</a></p><p><br /></p><p>HOW? ASK YA MOTHERBOARD</p><p>MSI hacked, source code + BIOS firmware stolen</p><p><a href=\"https://www.bleepingcomputer.com/news/security/money-message-ransomware-gang-claims-msi-breach-demands-4-million/\">https://www.bleepingcomputer.com/news/security/money-message-ransomware-gang-claims-msi-breach-demands-4-million/</a></p><p><a href=\"https://linustechtips.com/topic/1499834-msi-confirms-security-breach-4m-ransom-demand/\">https://linustechtips.com/topic/1499834-msi-confirms-security-breach-4m-ransom-demand/</a></p><p><a href=\"https://www.msi.com/news/detail/MSI-Statement-141688\">https://www.msi.com/news/detail/MSI-Statement-141688</a></p><p>Hopefully they didn’t plug their phones into an airport USB port <a href=\"https://www.macrumors.com/2023/04/10/fbi-malware-public-usb-port-warning/\">https://www.macrumors.com/2023/04/10/fbi-malware-public-usb-port-warning/</a></p><p><a href=\"https://twitter.com/FBIDenver/status/1643947117650538498\">https://twitter.com/FBIDenver/status/1643947117650538498</a></p><p><br /></p><p>QUICK BITS</p><p><br /></p><p>PRICE-TO-SORRY-COME-AGAIN?</p><p>Leaked RTX 4070 images <a href=\"https://videocardz.com/newz/nvidia-geforce-rtx-4070-founders-edition-gpu-has-been-pictured\">https://videocardz.com/newz/nvidia-geforce-rtx-4070-founders-edition-gpu-has-been-pictured</a></p><p>RTX 4070 April 13th for $599 <a href=\"https://videocardz.com/newz/nvidia-claims-geforce-rtx-4070-and-rtx-3080-offer-equal-dlss-performance-without-frame-generation\">https://videocardz.com/newz/nvidia-claims-geforce-rtx-4070-and-rtx-3080-offer-equal-dlss-performance-without-frame-generation</a></p><p>Thank you? <a href=\"https://www.reddit.com/r/hardware/comments/12hh4v9/comment/jfpudly/?utm_source=reddit&amp;utm_medium=web2x&amp;context=3\">https://www.reddit.com/r/hardware/comments/12hh4v9/comment/jfpudly/?utm_source=reddit&amp;utm_medium=web2x&amp;context=3</a></p><p>CP2077 Overdrive Ray Tracing Tech Preview <a href=\"https://www.youtube.com/watch?v=I-ORt8313Og\">https://www.youtube.com/watch?v=I-ORt8313Og</a></p><p><br /></p><p>THE VIDEOS ARE REALLY FUNNY THO</p><p>Tesla video-sharing story triggers class action suit</p><p><a href=\"https://arstechnica.com/tech-policy/2023/04/tesla-sued-after-report-that-workers-shared-invasive-images-from-car-cameras/\">https://arstechnica.com/tech-policy/2023/04/tesla-sued-after-report-that-workers-shared-invasive-images-from-car-cameras/</a></p><p><a href=\"https://jalopnik.com/tesla-class-action-lawsuit-for-sharing-private-videos-1850318367\">https://jalopnik.com/tesla-class-action-lawsuit-for-sharing-private-videos-1850318367</a></p><p><a href=\"https://www.reuters.com/technology/tesla-workers-shared-sensitive-images-recorded-by-customer-cars-2023-04-06/\">https://www.reuters.com/technology/tesla-workers-shared-sensitive-images-recorded-by-customer-cars-2023-04-06/</a></p><p><br /></p><p>TOTAL GANON BEHAVIOR</p><p>Nintendo subpoenas Discord for Zelda art book leaker</p><p><a href=\"https://www.gamesradar.com/nintendo-subpoenas-discord-in-pursuit-of-zelda-tears-of-the-kingdom-leaker/\">https://www.gamesradar.com/nintendo-subpoenas-discord-in-pursuit-of-zelda-tears-of-the-kingdom-leaker/</a></p><p><a href=\"https://www.nintendolife.com/news/2023/04/nintendo-wants-discord-to-reveal-zelda-tears-of-the-kingdom-art-book-leaker\">https://www.nintendolife.com/news/2023/04/nintendo-wants-discord-to-reveal-zelda-tears-of-the-kingdom-art-book-leaker</a></p><p><a href=\"https://www.dexerto.com/legend-of-zelda/zelda-tears-kingdoms-discord-leaker-nintendo-dmca-2109632/\">https://www.dexerto.com/legend-of-zelda/zelda-tears-kingdoms-discord-leaker-nintendo-dmca-2109632/</a></p><p>after nuking PointCrow’s videos about cool stuff like a BOTW multiplayer mod <a href=\"https://www.pcgamer.com/in-2021-a-youtuber-offered-dollar10k-to-whoever-could-make-a-breath-of-the-wild-multiplayer-mod-and-now-you-can-play-it/\">https://www.pcgamer.com/in-2021-a-youtuber-offered-dollar10k-to-whoever-could-make-a-breath-of-the-wild-multiplayer-mod-and-now-you-can-play-it/</a></p><p><br /></p><p>FLIPPED OFF</p><p>Amazon bans Flipper Zero</p><p><a href=\"https://gizmodo.com/amazon-bans-flipper-zero-card-skimming-on-tiktok-1850313284\">https://gizmodo.com/amazon-bans-flipper-zero-card-skimming-on-tiktok-1850313284</a></p><p><a href=\"https://www.techspot.com/news/98248-hacking-multi-tool-flipper-zero-gets-banned-amazon.html\">https://www.techspot.com/news/98248-hacking-multi-tool-flipper-zero-gets-banned-amazon.html</a></p><p><br /></p><p>THE ART OF DISCORD</p><p>NATO documents were originally leaked in Minecraft server</p><p><a href=\"https://www.pcgamer.com/i-cant-believe-this-keeps-happening-leaked-ukraine-war-plans-spread-in-part-through-a-minecraft-discord-server/\">https://www.pcgamer.com/i-cant-believe-this-keeps-happening-leaked-ukraine-war-plans-spread-in-part-through-a-minecraft-discord-server/</a></p><p><a href=\"https://www.vice.com/en/article/pkadnb/pentagons-ukraine-war-plans-leaked-on-minecraft-discord-before-telegram-and-twitter\">https://www.vice.com/en/article/pkadnb/pentagons-ukraine-war-plans-leaked-on-minecraft-discord-before-telegram-and-twitter</a></p>",
				"type": "blogPost",
				"channel": {
					"id": "6413534d88c13c181c3e2809",
					"creator": "59f94c0bdd241b70349eb72b",
					"title": "TechLinked",
					"urlname": "techlinked",
					"about": "News about tech + gaming culture, delivered thrice weekly.\n\nWe're also doing long-form video essays now, apparently. \n\nThe TalkLinked talk show/podcast will probably come back at some point, too!\n\nWriters: Riley Murdock, Jon Martin, James Strieb",
					"order": 2,
					"cover": null,
					"card": null,
					"icon": {
						"width": 88,
						"height": 88,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/6413534d88c13c181c3e2809/955526950207988_1678988110287.jpeg",
						"childImages": []
					}
				},
				"tags": [],
				"attachmentOrder": [
					"gwqTbMqeui"
				],
				"releaseDate": "2023-04-11T01:42:00.041Z",
				"likes": 446,
				"dislikes": 2,
				"score": 444,
				"comments": 54,
				"creator": {
					"id": "59f94c0bdd241b70349eb72b",
					"owner": {
						"id": "59f94c0bdd241b70349eb723",
						"username": "Linus"
					},
					"title": "LinusTechTips",
					"urlname": "linustechtips",
					"description": "We make entertaining videos about technology, including tech reviews, showcases and other content.",
					"about": "# We're LinusTechTips\nWe make videos and stuff, cool eh?",
					"category": {
						"id": "59f94c0bdd241b70349eb727",
						"title": "Technology"
					},
					"cover": {
						"width": 1990,
						"height": 519,
						"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867.jpeg",
						"childImages": [
							{
								"width": 1245,
								"height": 325,
								"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867_1245x325.jpeg"
							}
						]
					},
					"icon": {
						"width": 600,
						"height": 600,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205.jpeg",
						"childImages": [
							{
								"width": 250,
								"height": 250,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_250x250.jpeg"
							},
							{
								"width": 100,
								"height": 100,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_100x100.jpeg"
							}
						]
					},
					"liveStream": {
						"id": "5c13f3c006f1be15e08e05c0",
						"title": "I Give Up - WAN Show April 14, 2023",
						"description": "<p>JumpCloud offers an Open Directory Platform that makes it possible to unify your technology stack across identity, access, and device management. Learn more here: <a href=\"https://lmg.gg/JumpCloud\" rel=\"noopener noreferrer\" target=\"_blank\">https://lmg.gg/JumpCloud</a></p><p>Check out Goliath today and save 20% at <a href=\"https://lmg.gg/Goliath-Technologies\" rel=\"noopener noreferrer\" target=\"_blank\">https://lmg.gg/Goliath-Technologies</a></p><p>Buy a Seasonic Prime TX 1000W PSU:<a href=\"https://geni.us/aryiquT\" rel=\"noopener noreferrer\" target=\"_blank\"> https://geni.us/aryiquT</a></p><p><br></p><p>Purchases made through some store links may provide some compensation to Linus Media Group.</p><p><br></p><p>Podcast Download: TBD</p>",
						"thumbnail": {
							"width": 1920,
							"height": 1080,
							"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325.jpeg",
							"childImages": [
								{
									"width": 400,
									"height": 225,
									"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325_400x225.jpeg"
								},
								{
									"width": 1200,
									"height": 675,
									"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325_1200x675.jpeg"
								}
							]
						},
						"owner": "59f94c0bdd241b70349eb72b",
						"channel": "63fe42c309e691e4e36de93d",
						"streamPath": "/api/video/v1/us-east-1.758417551536.channel.yKkxur4ukc0B.m3u8",
						"offline": {
							"title": "Offline",
							"description": "We're offline for now – please check back later!",
							"thumbnail": {
								"width": 1920,
								"height": 1080,
								"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026.jpeg",
								"childImages": [
									{
										"width": 400,
										"height": 225,
										"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_400x225.jpeg"
									},
									{
										"width": 1200,
										"height": 675,
										"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_1200x675.jpeg"
									}
								]
							}
						}
					},
					"subscriptionPlans": [
						{
							"id": "5d48d0306825b5780db93d07",
							"title": "LTT Supporter",
							"description": "- 2 Exclusives Per Week (Meet the Team, Extras, Behind the Scenes) \n- Exclusive livestreams\n- Save $10 by purchasing an annual subscription\n- Our gratitude for your support",
							"price": "5.00",
							"priceYearly": "50.00",
							"currency": "usd",
							"logo": null,
							"interval": "month",
							"featured": true,
							"allowGrandfatheredAccess": false,
							"discordServers": [],
							"discordRoles": []
						},
						{
							"id": "5e0ba6ac14e2590f760a0f0f",
							"title": "LTT Supporter Plus",
							"description": "- 4K Bitrate Streaming\n- 2 Exclusives Per Week (Meet the Team, Extras, Behind the Scenes) \n- Exclusive livestreams\n- Save $20 by purchasing an annual subscription\n- Our gratitude for your support",
							"price": "10.00",
							"priceYearly": "100.00",
							"currency": "usd",
							"logo": null,
							"interval": "month",
							"featured": true,
							"allowGrandfatheredAccess": false,
							"discordServers": [],
							"discordRoles": []
						}
					],
					"discoverable": true,
					"subscriberCountDisplay": "total",
					"incomeDisplay": false,
					"defaultChannel": "63fe42c309e691e4e36de93d",
					"channels": [
						"63fe42c309e691e4e36de93d",
						"6413534d88c13c181c3e2809",
						"64135da7ce81077a8480c679",
						"64135e27c773b27ff22c97eb",
						"64135e901ebaee42e258eb0b",
						"64135ed078d6262f717341b7",
						"64135f82fc76ab7f9fbdc876",
						"6413623f5b12cca228a28e78"
					],
					"card": {
						"width": 375,
						"height": 500,
						"path": "https://pbs.floatplane.com/creator_card/59f94c0bdd241b70349eb72b/281467946609369_1551250329871.jpeg",
						"childImages": [
							{
								"width": 300,
								"height": 400,
								"path": "https://pbs.floatplane.com/creator_card/59f94c0bdd241b70349eb72b/281467946609369_1551250329871_300x400.jpeg"
							}
						]
					}
				},
				"wasReleasedSilently": false,
				"metadata": {
					"hasVideo": true,
					"videoCount": 1,
					"videoDuration": 425,
					"hasAudio": false,
					"audioCount": 0,
					"audioDuration": 0,
					"hasPicture": false,
					"pictureCount": 0,
					"isFeatured": false,
					"hasGallery": false,
					"galleryCount": 0
				},
				"galleryAttachments": [],
				"thumbnail": {
					"width": 1920,
					"height": 1080,
					"path": "https://pbs.floatplane.com/blogPost_thumbnails/tKQiFAE09W/453031588786630_1681177287707.jpeg",
					"childImages": [
						{
							"width": 400,
							"height": 225,
							"path": "https://pbs.floatplane.com/blogPost_thumbnails/tKQiFAE09W/453031588786630_1681177287707_400x225.jpeg"
						},
						{
							"width": 1200,
							"height": 675,
							"path": "https://pbs.floatplane.com/blogPost_thumbnails/tKQiFAE09W/453031588786630_1681177287707_1200x675.jpeg"
						}
					]
				},
				"isAccessible": true,
				"videoAttachments": [
					"gwqTbMqeui"
				],
				"audioAttachments": [],
				"pictureAttachments": []
			},
			{
				"id": "sGIDDRIVRE",
				"guid": "sGIDDRIVRE",
				"title": "If you can fix this PC, it’s yours! (SPONSORED)",
				"text": "<p>Thanks to OriginPC for sponsoring today's video! Win your very own ChronosV3 Desktop PC challenge-free at <a href=\"https://www.originpc.com/landing/2023/linus-chronos-giveaway/\">https://www.originpc.com/landing/2023/linus-chronos-giveaway/</a> (Link will be live soon!)</p><p><br /></p><p>Origin PC sent us a white Chronos V3 gaming pc complete with an Intel i9-13900K process and an RTX 4080 GPU, but they told us we weren’t allowed to keep it. Of course, we don’t plan to give it back to them either, so we broke it good and invited our subscriber Calvin down to try to fix it. We told him he’d get to keep this beautiful, compact gaming rig IF he could get it in working order in under 2 hours. Will he succeed, or will we have to find someone else to take this compact ivory obelisk off our hands?</p><p><br /></p><p>Intel Core i9-13900K Processor: <a href=\"https://geni.us/Pr7AyZz\">https://geni.us/Pr7AyZz</a></p><p>NVIDIA GeForce RTX 4080 16GB GPU: <a href=\"https://geni.us/Lp07wc\">https://geni.us/Lp07wc</a></p><p>Corsair Vengeance DDR5 32GB (2x16GB) 5600MHz C36 RAM: <a href=\"https://geni.us/Ya6hr2\">https://geni.us/Ya6hr2</a></p><p>ASUS ROG STRIX X670E-I Motherboard: <a href=\"https://geni.us/yw1AIMb\">https://geni.us/yw1AIMb</a></p><p>Corsair iCue H150i RGB Elite Liquid CPU Cooler: <a href=\"https://geni.us/KBk4Up\">https://geni.us/KBk4Up</a></p><p>Corsair SF Series PSU: <a href=\"https://geni.us/BiE72\">https://geni.us/BiE72</a></p><p><br /></p><p>Purchases made through some store links may provide some compensation to Linus Media Group.</p>",
				"type": "blogPost",
				"channel": {
					"id": "63fe42c309e691e4e36de93d",
					"creator": "59f94c0bdd241b70349eb72b",
					"title": "Linus Tech Tips",
					"urlname": "main",
					"about": "# We're LinusTechTips\nWe make videos and stuff, cool eh?",
					"order": 0,
					"cover": null,
					"card": null,
					"icon": {
						"width": 600,
						"height": 600,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205.jpeg",
						"childImages": [
							{
								"width": 250,
								"height": 250,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_250x250.jpeg"
							},
							{
								"width": 100,
								"height": 100,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_100x100.jpeg"
							}
						]
					}
				},
				"tags": [],
				"attachmentOrder": [
					"cy5VMcyHNp"
				],
				"releaseDate": "2023-04-10T16:16:00.031Z",
				"likes": 765,
				"dislikes": 88,
				"score": 677,
				"comments": 237,
				"creator": {
					"id": "59f94c0bdd241b70349eb72b",
					"owner": {
						"id": "59f94c0bdd241b70349eb723",
						"username": "Linus"
					},
					"title": "LinusTechTips",
					"urlname": "linustechtips",
					"description": "We make entertaining videos about technology, including tech reviews, showcases and other content.",
					"about": "# We're LinusTechTips\nWe make videos and stuff, cool eh?",
					"category": {
						"id": "59f94c0bdd241b70349eb727",
						"title": "Technology"
					},
					"cover": {
						"width": 1990,
						"height": 519,
						"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867.jpeg",
						"childImages": [
							{
								"width": 1245,
								"height": 325,
								"path": "https://pbs.floatplane.com/cover_images/59f94c0bdd241b70349eb72b/696951209272749_1521668313867_1245x325.jpeg"
							}
						]
					},
					"icon": {
						"width": 600,
						"height": 600,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205.jpeg",
						"childImages": [
							{
								"width": 250,
								"height": 250,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_250x250.jpeg"
							},
							{
								"width": 100,
								"height": 100,
								"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_100x100.jpeg"
							}
						]
					},
					"liveStream": {
						"id": "5c13f3c006f1be15e08e05c0",
						"title": "I Give Up - WAN Show April 14, 2023",
						"description": "<p>JumpCloud offers an Open Directory Platform that makes it possible to unify your technology stack across identity, access, and device management. Learn more here: <a href=\"https://lmg.gg/JumpCloud\" rel=\"noopener noreferrer\" target=\"_blank\">https://lmg.gg/JumpCloud</a></p><p>Check out Goliath today and save 20% at <a href=\"https://lmg.gg/Goliath-Technologies\" rel=\"noopener noreferrer\" target=\"_blank\">https://lmg.gg/Goliath-Technologies</a></p><p>Buy a Seasonic Prime TX 1000W PSU:<a href=\"https://geni.us/aryiquT\" rel=\"noopener noreferrer\" target=\"_blank\"> https://geni.us/aryiquT</a></p><p><br></p><p>Purchases made through some store links may provide some compensation to Linus Media Group.</p><p><br></p><p>Podcast Download: TBD</p>",
						"thumbnail": {
							"width": 1920,
							"height": 1080,
							"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325.jpeg",
							"childImages": [
								{
									"width": 400,
									"height": 225,
									"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325_400x225.jpeg"
								},
								{
									"width": 1200,
									"height": 675,
									"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/086292391511337_1681524589325_1200x675.jpeg"
								}
							]
						},
						"owner": "59f94c0bdd241b70349eb72b",
						"channel": "63fe42c309e691e4e36de93d",
						"streamPath": "/api/video/v1/us-east-1.758417551536.channel.yKkxur4ukc0B.m3u8",
						"offline": {
							"title": "Offline",
							"description": "We're offline for now – please check back later!",
							"thumbnail": {
								"width": 1920,
								"height": 1080,
								"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026.jpeg",
								"childImages": [
									{
										"width": 400,
										"height": 225,
										"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_400x225.jpeg"
									},
									{
										"width": 1200,
										"height": 675,
										"path": "https://pbs.floatplane.com/stream_thumbnails/5c13f3c006f1be15e08e05c0/894654974252956_1549059179026_1200x675.jpeg"
									}
								]
							}
						}
					},
					"subscriptionPlans": [
						{
							"id": "5d48d0306825b5780db93d07",
							"title": "LTT Supporter",
							"description": "- 2 Exclusives Per Week (Meet the Team, Extras, Behind the Scenes) \n- Exclusive livestreams\n- Save $10 by purchasing an annual subscription\n- Our gratitude for your support",
							"price": "5.00",
							"priceYearly": "50.00",
							"currency": "usd",
							"logo": null,
							"interval": "month",
							"featured": true,
							"allowGrandfatheredAccess": false,
							"discordServers": [],
							"discordRoles": []
						},
						{
							"id": "5e0ba6ac14e2590f760a0f0f",
							"title": "LTT Supporter Plus",
							"description": "- 4K Bitrate Streaming\n- 2 Exclusives Per Week (Meet the Team, Extras, Behind the Scenes) \n- Exclusive livestreams\n- Save $20 by purchasing an annual subscription\n- Our gratitude for your support",
							"price": "10.00",
							"priceYearly": "100.00",
							"currency": "usd",
							"logo": null,
							"interval": "month",
							"featured": true,
							"allowGrandfatheredAccess": false,
							"discordServers": [],
							"discordRoles": []
						}
					],
					"discoverable": true,
					"subscriberCountDisplay": "total",
					"incomeDisplay": false,
					"defaultChannel": "63fe42c309e691e4e36de93d",
					"channels": [
						"63fe42c309e691e4e36de93d",
						"6413534d88c13c181c3e2809",
						"64135da7ce81077a8480c679",
						"64135e27c773b27ff22c97eb",
						"64135e901ebaee42e258eb0b",
						"64135ed078d6262f717341b7",
						"64135f82fc76ab7f9fbdc876",
						"6413623f5b12cca228a28e78"
					],
					"card": {
						"width": 375,
						"height": 500,
						"path": "https://pbs.floatplane.com/creator_card/59f94c0bdd241b70349eb72b/281467946609369_1551250329871.jpeg",
						"childImages": [
							{
								"width": 300,
								"height": 400,
								"path": "https://pbs.floatplane.com/creator_card/59f94c0bdd241b70349eb72b/281467946609369_1551250329871_300x400.jpeg"
							}
						]
					}
				},
				"wasReleasedSilently": false,
				"metadata": {
					"hasVideo": true,
					"videoCount": 1,
					"videoDuration": 1324,
					"hasAudio": false,
					"audioCount": 0,
					"audioDuration": 0,
					"hasPicture": false,
					"pictureCount": 0,
					"isFeatured": false,
					"hasGallery": false,
					"galleryCount": 0
				},
				"galleryAttachments": [],
				"thumbnail": {
					"width": 1920,
					"height": 1080,
					"path": "https://pbs.floatplane.com/blogPost_thumbnails/sGIDDRIVRE/018231042564838_1680825884648.jpeg",
					"childImages": [
						{
							"width": 400,
							"height": 225,
							"path": "https://pbs.floatplane.com/blogPost_thumbnails/sGIDDRIVRE/018231042564838_1680825884648_400x225.jpeg"
						},
						{
							"width": 1200,
							"height": 675,
							"path": "https://pbs.floatplane.com/blogPost_thumbnails/sGIDDRIVRE/018231042564838_1680825884648_1200x675.jpeg"
						}
					]
				},
				"isAccessible": true,
				"videoAttachments": [
					"cy5VMcyHNp"
				],
				"audioAttachments": [],
				"pictureAttachments": []
			}
		],
		"lastElements": [
			{
				"creatorId": "59f94c0bdd241b70349eb72b",
				"blogPostId": "sGIDDRIVRE",
				"moreFetchable": true
			}
		]
	}
	"""#
	
	static let getBlogPost = #"""
	{
		"id": "iKl5zXTlaP",
		"guid": "iKl5zXTlaP",
		"title": "TL: AutoGPT, Windows handheld mode, WD hack + more!",
		"text": "<p><strong>NEWS SOURCES:</strong></p><p><br /></p><p>PROMPT INCEPTION</p><p>AutoGPT</p><p><a href=\"https://www.digitaltrends.com/computing/what-is-auto-gpt/\">https://www.digitaltrends.com/computing/what-is-auto-gpt/</a></p><p><a href=\"https://github.com/Torantulino/Auto-GPT\">https://github.com/Torantulino/Auto-GPT</a></p><p><a href=\"https://www.lesswrong.com/posts/566kBoPi76t8KAkoD/on-autogpt#:~:text=The%20concept%20works%20like%20this%3A\">https://www.lesswrong.com/posts/566kBoPi76t8KAkoD/on-autogpt#:~:text=The%20concept%20works%20like%20this%3A</a></p><p><a href=\"https://github.com/trending\">https://github.com/trending</a></p><p>Microsoft Jarvis <a href=\"https://github.com/microsoft/JARVIS\">https://github.com/microsoft/JARVIS</a></p><p>Sim study <a href=\"https://arxiv.org/abs/2304.03442\">https://arxiv.org/abs/2304.03442</a></p><p><a href=\"https://arxiv.org/pdf/2304.03442.pdf\">https://arxiv.org/pdf/2304.03442.pdf</a></p><p>party <a href=\"https://lmg.gg/bmG9w\">https://lmg.gg/bmG9w</a></p><p>Voice cloning scams are effing sh** up</p><p><a href=\"https://www.wkyt.com/2023/04/10/ive-got-your-daughter-mom-warns-terrifying-ai-voice-cloning-scam-that-faked-kidnapping\">https://www.wkyt.com/2023/04/10/ive-got-your-daughter-mom-warns-terrifying-ai-voice-cloning-scam-that-faked-kidnapping</a></p><p><a href=\"https://www.tiktok.com/@bethroyce/video/7207863411902778666\">https://www.tiktok.com/@bethroyce/video/7207863411902778666</a></p><p>some banks use voices to log in <a href=\"https://www.vice.com/en/article/dy7axa/how-i-broke-into-a-bank-account-with-an-ai-generated-voice\">https://www.vice.com/en/article/dy7axa/how-i-broke-into-a-bank-account-with-an-ai-generated-voice</a> </p><p>Dolly 2.0 will make AI tech more accessible <a href=\"https://arstechnica.com/information-technology/2023/04/a-really-big-deal-dolly-is-a-free-open-source-chatgpt-style-ai-model/\">https://arstechnica.com/information-technology/2023/04/a-really-big-deal-dolly-is-a-free-open-source-chatgpt-style-ai-model/</a></p><p>US Commerce Dept working on AI safety rules <a href=\"https://www.axios.com/2023/04/11/ai-safety-rules-commerce-department-artificial-intelligence\">https://www.axios.com/2023/04/11/ai-safety-rules-commerce-department-artificial-intelligence</a></p><p>NTIA accepting comments <a href=\"https://ntia.gov/issues/artificial-intelligence/request-for-comments\">https://ntia.gov/issues/artificial-intelligence/request-for-comments</a></p><p><br /></p><p>HAND-SIZED WINDOW</p><p>Microsoft experimenting with a Steam Deck-friendly “handheld mode” for Windows</p><p><a href=\"https://twitter.com/_h0x0d_/status/1646339289230483458\">https://twitter.com/_h0x0d_/status/1646339289230483458</a></p><p><a href=\"https://www.theverge.com/2023/4/13/23681492/microsoft-windows-handheld-mode-gaming-xbox-steam-deck\">https://www.theverge.com/2023/4/13/23681492/microsoft-windows-handheld-mode-gaming-xbox-steam-deck</a></p><p>or is it for Steam Deck rivals?</p><p><a href=\"https://www.pcworld.com/article/1785380/of-course-microsoft-is-working-on-windows-handheld-mode-for-steam-deck-rivals.html\">https://www.pcworld.com/article/1785380/of-course-microsoft-is-working-on-windows-handheld-mode-for-steam-deck-rivals.html</a></p><p>Windows 11 is getting a new “Presence Mode”</p><p><a href=\"https://www.thurrott.com/windows/281855/microsoft-starts-testing-presence-sensing-privacy-settings-on-windows-11\">https://www.thurrott.com/windows/281855/microsoft-starts-testing-presence-sensing-privacy-settings-on-windows-11</a></p><p>Will allow you to choose whether applications can detect if you are interacting with your device</p><p><a href=\"https://www.xda-developers.com/windows-11-beta-apps-track-presense-privacy-page/\">https://www.xda-developers.com/windows-11-beta-apps-track-presense-privacy-page/</a></p><p><a href=\"https://www.windowscentral.com/software-apps/windows-11/windows-11-apps-will-soon-be-able-to-detect-when-you-are-present-in-front-of-your-pc\">https://www.windowscentral.com/software-apps/windows-11/windows-11-apps-will-soon-be-able-to-detect-when-you-are-present-in-front-of-your-pc</a></p><p><br /></p><p>WESTERN PITIFUL</p><p>Hackers reportedly holding Western Digital data hostage</p><p><a href=\"https://techcrunch.com/2023/04/13/hackers-claim-vast-access-to-western-digital-systems/\">https://techcrunch.com/2023/04/13/hackers-claim-vast-access-to-western-digital-systems/</a></p><p>original statement <a href=\"https://www.businesswire.com/news/home/20230402005076/en/Western-Digital-Provides-Information-on-Network-Security-Incident\">https://www.businesswire.com/news/home/20230402005076/en/Western-Digital-Provides-Information-on-Network-Security-Incident</a></p><p><a href=\"https://www.pcmag.com/news/after-10-days-western-digitals-my-cloud-finally-restored-following-hack\">https://www.pcmag.com/news/after-10-days-western-digitals-my-cloud-finally-restored-following-hack</a></p><p>if WD doesn’t pay, hackers will publish data on website of “professional” hacking group <a href=\"https://lmg.gg/HR4lt\">https://lmg.gg/HR4lt</a></p><p><br /></p><p>QUICK BITS</p><p><br /></p><p>SOWING DISCORD</p><p>National Guard member allegedly leaked classified documents on Discord</p><p><a href=\"https://www.nbcnews.com/politics/national-security/us-officials-identify-leaked-classified-documents-suspect-21-year-old-rcna79577?cid=ed_npd_bn_tw_bn\">https://www.nbcnews.com/politics/national-security/us-officials-identify-leaked-classified-documents-suspect-21-year-old-rcna79577?cid=ed_npd_bn_tw_bn</a></p><p><a href=\"https://www.youtube.com/watch?v=Dc8wbH6juG8\">https://www.youtube.com/watch?v=Dc8wbH6juG8</a></p><p><a href=\"https://www.washingtonpost.com/national-security/2023/04/12/discord-leaked-documents/\">https://www.washingtonpost.com/national-security/2023/04/12/discord-leaked-documents/</a></p><p><br /></p><p>IT TURNS RAY TRACING ON, OR ELSE…</p><p>Nvidia: 83% of RTX 40-series gamers enable ray tracing, but… what does that mean?</p><p><a href=\"https://www.pcgamer.com/nvidia-says-83-of-rtx-40-series-gamers-enable-ray-tracing/\">https://www.pcgamer.com/nvidia-says-83-of-rtx-40-series-gamers-enable-ray-tracing/</a></p><p><a href=\"https://arstechnica.com/gadgets/2023/04/nvidia-proud-that-83-of-people-with-1200-ray-tracing-gpus-actually-use-rtx/\">https://arstechnica.com/gadgets/2023/04/nvidia-proud-that-83-of-people-with-1200-ray-tracing-gpus-actually-use-rtx/</a></p><p><a href=\"https://www.reddit.com/r/hardware/comments/12ldh21/comment/jg6u2wg/?utm_source=reddit&amp;utm_medium=web2x&amp;context=3\">https://www.reddit.com/r/hardware/comments/12ldh21/comment/jg6u2wg/?utm_source=reddit&amp;utm_medium=web2x&amp;context=3</a></p><p><br /></p><p>THE SAG AWARDS</p><p>SURPRISE! GPU sag can kill your graphics card</p><p><a href=\"https://www.tomshardware.com/news/rtx-2080-ti-dying-from-gpu-sag\">https://www.tomshardware.com/news/rtx-2080-ti-dying-from-gpu-sag</a></p><p>German repair ubermensch KrisFix claims that 2080 Ti’s commonly die late in life due to being so thick</p><p><a href=\"https://youtu.be/m3oM3huKl8c\">https://youtu.be/m3oM3huKl8c</a></p><p>I CAN’T BELIEVE that Nvidia engineers didn’t fucking study how torque works</p><p><a href=\"https://www.pcgamer.com/dont-let-your-chonk-graphics-card-sag-or-it-might-actually-die/\">https://www.pcgamer.com/dont-let-your-chonk-graphics-card-sag-or-it-might-actually-die/</a></p><p><br /></p><p>UH OH, HOW MONEY WORK?</p><p>Twitter Subscriptions</p><p><a href=\"https://www.engadget.com/twitter-replaces-super-follows-with-subscriptions-203711756.html\">https://www.engadget.com/twitter-replaces-super-follows-with-subscriptions-203711756.html</a></p><p><a href=\"https://twitter.com/elonmusk/status/1646560815003373568\">https://twitter.com/elonmusk/status/1646560815003373568</a></p><p><br /></p><p>FLY ME TO THEM MOONS</p><p>Europe’s ESA launches rocket to Jupiter</p><p><a href=\"https://news.sky.com/story/european-space-agencys-juice-mission-launches-to-search-for-life-on-jupiters-moons-12855869\">https://news.sky.com/story/european-space-agencys-juice-mission-launches-to-search-for-life-on-jupiters-moons-12855869</a></p><p>postponed <a href=\"https://www.telegraph.co.uk/world-news/2023/04/13/juice-rocket-launch-jupiter-european-space-agency-watch/\">https://www.telegraph.co.uk/world-news/2023/04/13/juice-rocket-launch-jupiter-european-space-agency-watch/</a></p><p><a href=\"https://www.esa.int/Science_Exploration/Space_Science/Juice/ESA_s_Juice_lifts_off_on_quest_to_discover_secrets_of_Jupiter_s_icy_moons\">https://www.esa.int/Science_Exploration/Space_Science/Juice/ESA_s_Juice_lifts_off_on_quest_to_discover_secrets_of_Jupiter_s_icy_moons</a></p>",
		"type": "blogPost",
		"channel": {
			"id": "6413534d88c13c181c3e2809",
			"creator": "59f94c0bdd241b70349eb72b",
			"title": "TechLinked",
			"urlname": "techlinked",
			"about": "News about tech + gaming culture, delivered thrice weekly.\n\nWe're also doing long-form video essays now, apparently. \n\nThe TalkLinked talk show/podcast will probably come back at some point, too!\n\nWriters: Riley Murdock, Jon Martin, James Strieb",
			"order": 2,
			"cover": null,
			"card": null,
			"icon": {
				"width": 88,
				"height": 88,
				"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/6413534d88c13c181c3e2809/955526950207988_1678988110287.jpeg",
				"childImages": []
			}
		},
		"tags": ["server", "apple"],
		"attachmentOrder": [
			"kx3hhG4yjR"
		],
		"releaseDate": "2023-04-15T06:41:00.041Z",
		"likes": 194,
		"dislikes": 0,
		"score": 194,
		"comments": 20,
		"creator": {
			"id": "59f94c0bdd241b70349eb72b",
			"owner": "59f94c0bdd241b70349eb723",
			"title": "LinusTechTips",
			"urlname": "linustechtips",
			"description": "We make entertaining videos about technology, including tech reviews, showcases and other content.",
			"about": "# We're LinusTechTips\nWe make videos and stuff, cool eh?",
			"category": "59f94c0bdd241b70349eb727",
			"cover": null,
			"icon": {
				"width": 600,
				"height": 600,
				"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205.jpeg",
				"childImages": [
					{
						"width": 250,
						"height": 250,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_250x250.jpeg"
					},
					{
						"width": 100,
						"height": 100,
						"path": "https://pbs.floatplane.com/creator_icons/59f94c0bdd241b70349eb72b/770551996990709_1551249357205_100x100.jpeg"
					}
				]
			},
			"liveStream": null,
			"subscriptionPlans": null,
			"discoverable": true,
			"subscriberCountDisplay": "total",
			"incomeDisplay": false,
			"defaultChannel": "63fe42c309e691e4e36de93d"
		},
		"wasReleasedSilently": false,
		"metadata": {
			"hasVideo": true,
			"videoCount": 1,
			"videoDuration": 482,
			"hasAudio": false,
			"audioCount": 0,
			"audioDuration": 0,
			"hasPicture": false,
			"pictureCount": 0,
			"isFeatured": false,
			"hasGallery": false,
			"galleryCount": 0
		},
		"galleryAttachments": [],
		"thumbnail": {
			"width": 1920,
			"height": 1080,
			"path": "https://pbs.floatplane.com/blogPost_thumbnails/iKl5zXTlaP/096118745514196_1681526329366.jpeg",
			"childImages": [
				{
					"width": 400,
					"height": 225,
					"path": "https://pbs.floatplane.com/blogPost_thumbnails/iKl5zXTlaP/096118745514196_1681526329366_400x225.jpeg"
				},
				{
					"width": 1200,
					"height": 675,
					"path": "https://pbs.floatplane.com/blogPost_thumbnails/iKl5zXTlaP/096118745514196_1681526329366_1200x675.jpeg"
				}
			]
		},
		"isAccessible": true,
		"userInteraction": [],
		"videoAttachments": [
			{
				"id": "kx3hhG4yjR",
				"guid": "kx3hhG4yjR",
				"title": "TL: AutoGPT, Windows handheld mode, WD hack + more!",
				"type": "video",
				"description": "",
				"releaseDate": null,
				"duration": 482,
				"creator": "59f94c0bdd241b70349eb72b",
				"likes": 0,
				"dislikes": 0,
				"score": 0,
				"isProcessing": false,
				"primaryBlogPost": "iKl5zXTlaP",
				"thumbnail": {
					"width": 1920,
					"height": 1080,
					"path": "https://pbs.floatplane.com/content_thumbnails/kx3hhG4yjR/805065786365119_1681523334582.jpeg",
					"childImages": []
				},
				"isAccessible": true
			}
		],
		"audioAttachments": [],
		"pictureAttachments": []
	}
	"""#
	
	static let getVideoContent = #"""
	{
		"id": "TViGzkuIic",
		"guid": "TViGzkuIic",
		"title": "October 9, 2021 @ 07:18 – First Linux Stream",
		"type": "video",
		"description": "",
		"releaseDate": null,
		"duration": 5689,
		"creator": "59f94c0bdd241b70349eb72b",
		"likes": 0,
		"dislikes": 0,
		"score": 0,
		"isProcessing": false,
		"primaryBlogPost": "Dw2ms0AgL8",
		"thumbnail": {
			"width": 1920,
			"height": 1080,
			"path": "https://pbs.floatplane.com/content_thumbnails/TViGzkuIic/324783659287024_1633769709593.jpeg",
			"childImages": []
		},
		"isAccessible": true,
		"blogPosts": [
			"Dw2ms0AgL8"
		],
		"timelineSprite": {
			"width": 4960,
			"height": 2610,
			"path": "https://pbs.floatplane.com/timeline_sprite/TViGzkuIic/142493855372807_1633769996492.jpeg",
			"childImages": []
		},
		"userInteraction": [],
		"levels": [
			{
				"name": "360",
				"width": 640,
				"height": 360,
				"label": "360p",
				"order": 0
			},
			{
				"name": "480",
				"width": 854,
				"height": 480,
				"label": "480p",
				"order": 1
			},
			{
				"name": "720",
				"width": 1280,
				"height": 720,
				"label": "720p",
				"order": 2
			}
		]
	}
	"""#
	
	static let getCdn: String = #"""
	{
		"cdn": "https://cdn-vod-drm2.floatplane.com",
		"strategy": "cdn",
		"resource": {
			"uri": "/Videos/TViGzkuIic/{qualityLevels}.mp4/chunk.m3u8?token={qualityLevelParams.token}",
			"data": {
				"qualityLevels": [
					{
						"name": "360",
						"width": 640,
						"height": 360,
						"label": "360p",
						"order": 0
					},
					{
						"name": "480",
						"width": 854,
						"height": 480,
						"label": "480p",
						"order": 1
					},
					{
						"name": "720",
						"width": 1280,
						"height": 720,
						"label": "720p",
						"order": 2
					},
					{
						"name": "1080",
						"width": 2160,
						"height": 1080,
						"label": "1080p",
						"order": 4
					}
				],
				"qualityLevelParams": {
					"360": {
						"token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyZXNzb3VyY2VQYXRoIjoiL1ZpZGVvcy9UVmlHemt1SWljLzM2MC5tcDQvY2h1bmsubTN1OCIsInVzZXJJZCI6IjAxMjM0NTY3ODlhYmNkZWYwMTIzNDU2NyIsImlhdCI6MTYzMzc5NzMxMSwiZXhwIjoxNjMzODE4OTExfQ.uaLzZ4wSc0jrYbjkdhuF4_UY92iWQsq2efrWUutYUvQ"
					},
					"480": {
						"token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyZXNzb3VyY2VQYXRoIjoiL1ZpZGVvcy9UVmlHemt1SWljLzQ4MC5tcDQvY2h1bmsubTN1OCIsInVzZXJJZCI6IjAxMjM0NTY3ODlhYmNkZWYwMTIzNDU2NyIsImlhdCI6MTYzMzc5NzMxMSwiZXhwIjoxNjMzODE4OTExfQ.O6PHCJKcLW7ohuKj6UcMa8QGoN-vZr6xTtfXsUMRki0"
					},
					"720": {
						"token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyZXNzb3VyY2VQYXRoIjoiL1ZpZGVvcy9UVmlHemt1SWljLzcyMC5tcDQvY2h1bmsubTN1OCIsInVzZXJJZCI6IjAxMjM0NTY3ODlhYmNkZWYwMTIzNDU2NyIsImlhdCI6MTYzMzc5NzMxMSwiZXhwIjoxNjMzODE4OTExfQ.lbOTTBXBjA-i9gBzm8ydFQ8fa8q07Z2vaLsYMKUp4Ik"
					},
					"1080": {
						"token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyZXNzb3VyY2VQYXRoIjoiL1ZpZGVvcy9UVmlHemt1SWljLzEwODAubXA0L2NodW5rLm0zdTgiLCJ1c2VySWQiOiIwMTIzNDU2Nzg5YWJjZGVmMDEyMzQ1NjciLCJpYXQiOjE2MzM3OTczMTEsImV4cCI6MTYzMzgxODkxMX0.E-bw_gnUzKUpYeL2l-kTmj5CbwmDb519ohjf5LlLyQg"
					}
				}
			}
		}
	}
	"""#
	
	static let getCdnLive: String = #"""
	{
		"cdn": "https://de488bcb61af.us-east-1.playback.live-video.net",
		"strategy": "cdn",
		"resource": {
			"uri": "/api/video/v1/us-east-1.758417551536.channel.yKkxur4ukc0B.m3u8?token={token}&allow_source=false",
			"data": {
				"token": "eyJhbGciOiJFUzM4NCIsInR5cCI6IkpXVCJ9.eyJhd3M6Y2hhbm5lbC1hcm4iOiJhcm46YXdzOml2czp1cy1lYXN0LTE6NzU4NDE3NTUxNTM2OmNoYW5uZWwveUtreHVyNHVrYzBCIiwiYXdzOmFjY2Vzcy1jb250cm9sLWFsbG93LW9yaWdpbiI6Imh0dHBzOi8vd3d3LmZsb2F0cGxhbmUuY29tIiwiaWF0IjoxNjYyOTM5NTcwLCJleHAiOjE2NjMwMjU5NzB9.Zu1UavMfLOmAQ6m-hX1h5dkNdqGgRpRe-hGwhEs57tu8aMg0Ey_Oi-z2hdV3sHiUNFygmNHhqKj_JYDjRHWJtc0O1wxIzSYI_soQm4ldOspJGIzZEjBNNgxg9ljOqUil"
			}
		}
	}
	"""#
	
	static let getDeliveryOnDemand: String = #"""
	{
		"groups": [
			{
				"origins": [
					{
						"url": "https://cdn-vod-drm2.floatplane.com"
					}
				],
				"variants": [
					{
						"name": "360-avc1",
						"label": "360p",
						"url": "/Videos/Lug14XXgLx/360.mp4/chunk.m3u8?token=<token>",
						"mimeType": "application/x-mpegURL",
						"order": 11016384,
						"hidden": false,
						"enabled": true,
						"meta": {
							"video": {
								"codec": "avc1.64001e",
								"codecSimple": "avc1",
								"bitrate": {
									"average": 255886
								},
								"width": 640,
								"height": 320,
								"isHdr": false,
								"fps": 29.97,
								"mimeType": "video/MP2T"
							},
							"audio": {
								"codec": "mp4a.40.2",
								"bitrate": {
									"average": 93340,
									"maximum": 93340
								},
								"channelCount": 2,
								"samplerate": 48000,
								"mimeType": "video/MP2T"
							}
						}
					},
					{
						"name": "480-avc1",
						"label": "480p",
						"url": "/Videos/Lug14XXgLx/480.mp4/chunk.m3u8?token=<token>",
						"mimeType": "application/x-mpegURL",
						"order": 19339456,
						"hidden": false,
						"enabled": true,
						"meta": {
							"video": {
								"codec": "avc1.64001f",
								"codecSimple": "avc1",
								"bitrate": {
									"average": 395615
								},
								"width": 848,
								"height": 424,
								"isHdr": false,
								"fps": 29.97,
								"mimeType": "video/MP2T"
							},
							"audio": {
								"codec": "mp4a.40.2",
								"bitrate": {
									"average": 93340,
									"maximum": 93340
								},
								"channelCount": 2,
								"samplerate": 48000,
								"mimeType": "video/MP2T"
							}
						}
					},
					{
						"name": "720-avc1",
						"label": "720p",
						"url": "/Videos/Lug14XXgLx/720.mp4/chunk.m3u8?token=<token>",
						"mimeType": "application/x-mpegURL",
						"order": 44112064,
						"hidden": false,
						"enabled": true,
						"meta": {
							"video": {
								"codec": "avc1.640020",
								"codecSimple": "avc1",
								"bitrate": {
									"average": 736634
								},
								"width": 1280,
								"height": 640,
								"isHdr": false,
								"fps": 29.97,
								"mimeType": "video/MP2T"
							},
							"audio": {
								"codec": "mp4a.40.2",
								"bitrate": {
									"average": 93340,
									"maximum": 93340
								},
								"channelCount": 2,
								"samplerate": 48000,
								"mimeType": "video/MP2T"
							}
						}
					},
					{
						"name": "1080-avc1",
						"label": "1080p",
						"url": "/Videos/Lug14XXgLx/1080.mp4/chunk.m3u8?token=<token>",
						"mimeType": "application/x-mpegURL",
						"order": 99293376,
						"hidden": false,
						"enabled": true,
						"meta": {
							"video": {
								"codec": "avc1.64002a",
								"codecSimple": "avc1",
								"bitrate": {
									"average": 1448573
								},
								"width": 1920,
								"height": 960,
								"isHdr": false,
								"fps": 29.97,
								"mimeType": "video/MP2T"
							},
							"audio": {
								"codec": "mp4a.40.2",
								"bitrate": {
									"average": 93340,
									"maximum": 93340
								},
								"channelCount": 2,
								"samplerate": 48000,
								"mimeType": "video/MP2T"
							}
						}
					},
					{
						"name": "2160-avc1",
						"label": "4K",
						"url": "/Videos/Lug14XXgLx/2160.mp4/chunk.m3u8?token=<token>",
						"mimeType": "application/x-mpegURL",
						"order": 397351104,
						"hidden": false,
						"enabled": true,
						"meta": {
							"video": {
								"codec": "avc1.640034",
								"codecSimple": "avc1",
								"bitrate": {
									"average": 5904212
								},
								"width": 3840,
								"height": 1920,
								"isHdr": false,
								"fps": 29.97,
								"mimeType": "video/MP2T"
							},
							"audio": {
								"codec": "mp4a.40.2",
								"bitrate": {
									"average": 93340,
									"maximum": 93340
								},
								"channelCount": 2,
								"samplerate": 48000,
								"mimeType": "video/MP2T"
							}
						}
					}
				]
			}
		]
	}
	"""#
	
	static let getDeliveryLive: String = #"""
	{
		"groups": [
			{
				"origins": [
					{
						"url": "https://de488bcb61af.us-east-1.playback.live-video.net"
					}
				],
				"variants": [
					{
						"name": "live-abr",
						"label": "Auto",
						"url": "/api/video/v1/us-east-1.758417551536.channel.yKkxur4ukc0B.m3u8?allow_source=false&token=<token>",
						"mimeType": "application/x-mpegURL",
						"hidden": false,
						"enabled": true,
						"meta": {
							"live": {
								"lowLatencyExtension": "ivshls"
							}
						}
					}
				]
			}
		]
	}
	"""#
	
	static let getDeliveryDownload: String = #"""
	{
		"groups": [
			{
				"origins": [
					{
						"url": "https://edge01-na.floatplane.com",
						"queryUrl": "https://edge01-na-query.floatplane.com",
						"datacenter": {
							"latitude": 45.3168,
							"longitude": -73.8659,
							"countryCode": "CA",
							"regionCode": "QC"
						}
					},
					{
						"url": "https://edge02-na.floatplane.com",
						"queryUrl": "https://edge02-na-query.floatplane.com",
						"datacenter": {
							"latitude": 45.3168,
							"longitude": -73.8659,
							"countryCode": "CA",
							"regionCode": "QC"
						}
					}
				],
				"variants": [
					{
						"name": "360-avc1",
						"label": "360p",
						"url": "/Videos/Lug14XXgLx/360.mp4?token=<token>",
						"mimeType": "video/mp4",
						"order": 11016384,
						"hidden": false,
						"enabled": true,
						"meta": {
							"video": {
								"codec": "avc1.64001e",
								"codecSimple": "avc1",
								"bitrate": {
									"average": 255886
								},
								"width": 640,
								"height": 320,
								"isHdr": false,
								"fps": 29.97
							},
							"audio": {
								"codec": "mp4a.40.2",
								"bitrate": {
									"average": 93340,
									"maximum": 93340
								},
								"channelCount": 2,
								"samplerate": 48000
							}
						}
					},
					{
						"name": "480-avc1",
						"label": "480p",
						"url": "/Videos/Lug14XXgLx/480.mp4?token=<token>",
						"mimeType": "video/mp4",
						"order": 19339456,
						"hidden": false,
						"enabled": true,
						"meta": {
							"video": {
								"codec": "avc1.64001f",
								"codecSimple": "avc1",
								"bitrate": {
									"average": 395615
								},
								"width": 848,
								"height": 424,
								"isHdr": false,
								"fps": 29.97
							},
							"audio": {
								"codec": "mp4a.40.2",
								"bitrate": {
									"average": 93340,
									"maximum": 93340
								},
								"channelCount": 2,
								"samplerate": 48000
							}
						}
					},
					{
						"name": "720-avc1",
						"label": "720p",
						"url": "/Videos/Lug14XXgLx/720.mp4?token=<token>",
						"mimeType": "video/mp4",
						"order": 44112064,
						"hidden": false,
						"enabled": true,
						"meta": {
							"video": {
								"codec": "avc1.640020",
								"codecSimple": "avc1",
								"bitrate": {
									"average": 736634
								},
								"width": 1280,
								"height": 640,
								"isHdr": false,
								"fps": 29.97
							},
							"audio": {
								"codec": "mp4a.40.2",
								"bitrate": {
									"average": 93340,
									"maximum": 93340
								},
								"channelCount": 2,
								"samplerate": 48000
							}
						}
					},
					{
						"name": "1080-avc1",
						"label": "1080p",
						"url": "/Videos/Lug14XXgLx/1080.mp4?token=<token>",
						"mimeType": "video/mp4",
						"order": 99293376,
						"hidden": false,
						"enabled": true,
						"meta": {
							"video": {
								"codec": "avc1.64002a",
								"codecSimple": "avc1",
								"bitrate": {
									"average": 1448573
								},
								"width": 1920,
								"height": 960,
								"isHdr": false,
								"fps": 29.97
							},
							"audio": {
								"codec": "mp4a.40.2",
								"bitrate": {
									"average": 93340,
									"maximum": 93340
								},
								"channelCount": 2,
								"samplerate": 48000
							}
						}
					},
					{
						"name": "2160-avc1",
						"label": "4K",
						"url": "/Videos/Lug14XXgLx/2160.mp4?token=<token>",
						"mimeType": "video/mp4",
						"order": 397351104,
						"hidden": false,
						"enabled": true,
						"meta": {
							"video": {
								"codec": "avc1.640034",
								"codecSimple": "avc1",
								"bitrate": {
									"average": 5904212
								},
								"width": 3840,
								"height": 1920,
								"isHdr": false,
								"fps": 29.97
							},
							"audio": {
								"codec": "mp4a.40.2",
								"bitrate": {
									"average": 93340,
									"maximum": 93340
								},
								"channelCount": 2,
								"samplerate": 48000
							}
						}
					}
				]
			}
		]
	}
	"""#
	
	static let getPictureContent: String = #"""
	{"id":"ZWKdCy8TMN","guid":"ZWKdCy8TMN","title":"\"I hate costumes\" Jonathan","type":"picture","description":"","likes":1,"dislikes":0,"score":1,"isProcessing":false,"creator":"59f94c0bdd241b70349eb72b","primaryBlogPost":"PGZBzzRWpD","userInteraction":[],"thumbnail":{"width":1200,"height":675,"path":"https://pbs.floatplane.com/picture_thumbnails/ZWKdCy8TMN/239212458322156_1634845035660.jpeg","childImages":[]},"isAccessible":true,"imageFiles":[{"path":"https://pbs.floatplane.com/content_images/59f94c0bdd241b70349eb72b/465975275316873_1634845031494_1164x675.jpeg?AWSAccessKeyId=EG5Q4HESM1NW88XSD867&Expires=1641160871&Signature=Qn8hXrBOS%2Fee18aqjHqD8uFAfjw%3D","width":1164,"height":675,"size":165390}]}
	"""#
}
