import Foundation
import SwiftUI
import FloatplaneAPIClient

class AuthViewModel: BaseViewModel, ObservableObject {
	
	@Published var isLoadingAuthStatus = true
	@Published var isLoggedIn = false
	@Published var userInfo = UserInfo()
	@Published var authenticationCheckError: Error? = nil
	@Published var showAuthenticationErrorAlert = false
	@Published var showNoSubscriptionsAlert = false
	
	@Published var isAttemptingLogin = false
	@Published var showIncorrectLoginAlert = false
	@Published var loginError: Error? = nil
	@Published var isAttemptingSecondFactor = false
	@Published var showIncorrectSecondFactorAlert = false
	@Published var secondFactorError: Error? = nil
	
	private let fpApiService: FPAPIService
	
	init(fpApiService: FPAPIService) {
		self.fpApiService = fpApiService
	}
	
	func determineAuthenticationStatus() {
		Task { @MainActor in
			isLoadingAuthStatus = true
			
			logger.info("Determining authentication status. Retrieving the self object and list of subscriptions.")
			
			// Get self and subscriptions
			let userSelfResponse: UserV3API.GetStatus
			do {
				let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "<unknown>"
				let bundleVersion = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "<unknown>"
				userSelfResponse = try await fpApiService.getUserStatus(platform: .web, version: "Wasserflug-tvOS-\(appVersion)-\(bundleVersion)")
			} catch {
				self.logger.error("Encountered an unexpected error while loading user self. Reporting the error to the user. Showing login screen. Error: \(String(reflecting: error))")
				self.isLoggedIn = false
				self.isLoadingAuthStatus = false
				self.authenticationCheckError = error
				self.showAuthenticationErrorAlert = true
				return
			}
			
			let userSelf: UserSelfV3Response
			switch userSelfResponse {
			case let .http200(value: value, raw: raw):
				guard let selfUser = value.selfUser else {
					self.logger.notice("Received invalid 200 response for user self and user subscriptions. Assuming user is not logged in. Showing login screen to user.")
					self.logger.debug("User self response: \(raw)")
					self.isLoggedIn = false
					self.isLoadingAuthStatus = false
					return
				}
				userSelf = selfUser
			case let .http403(value: error, raw: _):
				self.logger.notice("Received invalid 403 response for user self and user subscriptions. Assuming user is not logged in. Showing login screen to user.")
				self.logger.debug("User self response: \(error)")
				self.isLoggedIn = false
				self.isLoadingAuthStatus = false
				return
			case let .http400(value: error, raw: _),
				 let .http401(value: error, raw: _),
				 let .http404(value: error, raw: _),
				 let .http0(value: error, raw: _):
				self.logger.error("Encountered an unexpected response status code while loading user self. Reporting the error to the user. Showing login screen. Error: \(String(reflecting: error))")
				self.isLoggedIn = false
				self.isLoadingAuthStatus = false
				self.authenticationCheckError = error
				self.showAuthenticationErrorAlert = true
				return
			case .http429(raw: _):
				self.logger.warning("Received HTTP 429 Too Many Requests.")
				self.isLoggedIn = false
				self.isLoadingAuthStatus = false
				self.authenticationCheckError = WasserflugError.http429
				self.showAuthenticationErrorAlert = true
				return
			}
			
			let userSubscriptions: [UserSubscriptionModel]
			do {
				userSubscriptions = try await self.fpApiService.listUserSubscriptionsV3()
			} catch {
				self.logger.error("Encountered an unexpected error while loading user subscriptions. Reporting the error to the user. Showing login screen. Error: \(String(reflecting: error))")
				self.isLoggedIn = false
				self.isLoadingAuthStatus = false
				self.authenticationCheckError = error
				self.showAuthenticationErrorAlert = true
				return
			}
			
			self.logger.notice("Recieved successful user self and subscription responses.", metadata: [
				"userId": "\(userSelf.id)",
				"username": "\(userSelf.username)",
				"subIds": "\(userSubscriptions.map(\.creator))",
			])
			
			guard !userSubscriptions.isEmpty else {
				self.logger.warning("Login was successful but the user profile did not return any subscriptions. Aborting authentication process and informing user of inability to proceed.")
				self.isLoggedIn = false
				self.isLoadingAuthStatus = false
				self.showNoSubscriptionsAlert = true
				return
			}
			
			self.isLoggedIn = true
			self.userInfo.userSelf = userSelf
			self.userInfo.userSubscriptions = userSubscriptions
			
			// With the subscriptions, get the creators of the subscriptions.
			// Convert to Set to remove possible duplicates (which is possible).
			let creatorGuids = Set<String>(self.userInfo.userSubscriptions.map(\.creator))
			self.logger.info("Loading creator(s) information from subscriptions", metadata: [
				"creatorGuids": "\(creatorGuids)",
			])
			
			// Get the creators and their channels.
			// This used to use the V2 API because it allowed for pulling multiple creators in one request,
			// which saves on number of requests and latency and such. But now that we're supporting channels,
			// which are not included in detail in V2 responses, we need to get them one at a time. So, we
			// can switch to the V3 API to do one request per creator which included channels.
			var creatorInfos: [CreatorModelV3] = []
			do {
				for id in creatorGuids {
					try creatorInfos.append(await self.fpApiService.getCreator(id: id))
				}
			} catch {
				self.logger.error("Encountered an unexpected error while loading user subscriptions. Reporting the error to the user. Showing login screen. Error: \(String(reflecting: error))")
				self.isLoggedIn = false
				self.isLoadingAuthStatus = false
				self.authenticationCheckError = error
				self.showAuthenticationErrorAlert = true
				return
			}

			self.logger.notice("Retrieved \(creatorInfos.count) creator(s) information.")
			self.userInfo.creators = Dictionary(uniqueKeysWithValues: creatorInfos.map({ ($0.id, $0) }))
			
			// With the creators, get the creator owners
			let ownerIds = creatorInfos.map(\.owner.id)
			self.logger.info("Loading creator owner(s) information.", metadata: [
				"ownerIds": "\(ownerIds)",
			])
			
			let creatorOwners: UserInfoV2Response
			do {
				creatorOwners = try await self.fpApiService.getUsers(ids: ownerIds)
			} catch {
				self.logger.error("Encountered an unexpected error while loading user subscriptions. Reporting the error to the user. Showing login screen. Error: \(String(reflecting: error))")
				self.isLoggedIn = false
				self.isLoadingAuthStatus = false
				self.authenticationCheckError = error
				self.showAuthenticationErrorAlert = true
				return
			}

			self.logger.notice("Retrieved creator owner(s) information", metadata: [
				"names": "\(creatorOwners.users.map(\.user.userModelShared.username))",
			])
			self.userInfo.creatorOwners = Dictionary(uniqueKeysWithValues: creatorOwners.users.map({ ($0.user.userModelShared.id, $0.user.userModelShared) }))
			
			self.isLoadingAuthStatus = false
		}
	}
	
	func attemptLogin(username: String, password: String, isLoggedIn: @escaping () -> Void, needsSecondFactor: @escaping () -> Void) {
		isAttemptingLogin = true
		
		logger.info("Attempting login action.", metadata: [
			"username": "\(username)",
		])
		
		fpApiService.login(username: username, password: password, captchaToken: nil)
			.whenComplete { result in
				DispatchQueue.main.async {
					self.isAttemptingLogin = false
					
					switch result {
					case let .success(response):
						switch response {
						case let .http200(value: response, raw: clientResponse):
							self.logger.debug("Successful login raw response: \(clientResponse.plaintextDebugContent)")
							// Set global cookie
							FloatplaneAPIClientAPI.storeAuthentifcationCookies(from: clientResponse)
							
							if response.needs2FA {
								self.logger.notice("Successfully logged in as user '\(username)'. Requires second factor to continue authentication process.")
								needsSecondFactor()
							} else {
								self.logger.notice("Successfully logged in as user '\(username)'. No second factor required.", metadata: [
									"id": "\(response.user?.id ?? "<no user object found>")",
									"username": "\(response.user?.username ?? "<no user object found>")",
								])
								isLoggedIn()
							}
						case let .http401(value: response, raw: clientResponse):
							self.logger.debug("Unsuccessfull login raw response: \(clientResponse.plaintextDebugContent)")
							self.logger.notice("Login attempt failed, received unauthorized response. ErrorModel: \(String(describing: response))")
							self.showIncorrectLoginAlert = true
						case let .http0(value: errorModel, raw: clientResponse),
							 let .http400(value: errorModel, raw: clientResponse),
							 let .http403(value: errorModel, raw: clientResponse),
							 let .http404(value: errorModel, raw: clientResponse):
							self.logger.warning("Received an unexpected HTTP status (\(clientResponse.status.code)) while attempting login. Reporting the error to the user. Error Model: \(String(reflecting: errorModel)).")
							self.showIncorrectLoginAlert = true
							self.loginError = errorModel
						case .http429(raw: _):
							self.logger.warning("Received HTTP 429 Too Many Requests.")
							self.showIncorrectLoginAlert = true
							self.loginError = WasserflugError.http429
						}
					case let .failure(error):
						self.logger.error("Encountered an unexpected error while attempting login. Reporting the error to the user. Error: \(String(reflecting: error))")
						self.showIncorrectLoginAlert = true
						self.loginError = error
					}
				}
			}
	}
	
	func attemptSecondFactor(secondFactorCode: String, isLoggedIn: @escaping () -> Void) {
		isAttemptingSecondFactor = true
		logger.info("Attempting 2fa action for login process.")
		
		// Sanitize the code
		let secondFactorCode = secondFactorCode.filter(\.isNumber).stringValue
		
		fpApiService.secondFactor(token: secondFactorCode)
			.whenComplete { result in
				DispatchQueue.main.async {
					self.isAttemptingSecondFactor = false
					
					switch result {
					case let .success(response):
						switch response {
						case let .http200(value: response, raw: clientResponse):
							self.logger.debug("Successful 2fa raw response: \(clientResponse.plaintextDebugContent)")
							self.logger.notice("Successfully resolved second factor in login process.", metadata: [
								"id": "\(response.user?.id ?? "<no user object found>")",
								"username": "\(response.user?.username ?? "<no user object found>")",
							])
							// Set global cookie
							FloatplaneAPIClientAPI.storeAuthentifcationCookies(from: clientResponse)
							
							isLoggedIn()
						case let .http401(value: response, raw: clientResponse):
							self.logger.debug("Unsuccessfull 2fa raw response: \(clientResponse.plaintextDebugContent)")
							self.logger.notice("2fa attempt failed, received unauthorized response. ErrorModel: \(String(describing: response))")
							self.showIncorrectSecondFactorAlert = true
						case let .http0(value: errorModel, raw: clientResponse),
							 let .http400(value: errorModel, raw: clientResponse),
							 let .http403(value: errorModel, raw: clientResponse),
							 let .http404(value: errorModel, raw: clientResponse):
							self.logger.warning("Received an unexpected HTTP status (\(clientResponse.status.code)) while attempting 2fa. Reporting the error to the user. Error Model: \(String(reflecting: errorModel)).")
							self.showIncorrectSecondFactorAlert = true
							self.secondFactorError = errorModel
						case .http429(raw: _):
							self.logger.warning("Received HTTP 429 Too Many Requests.")
							self.showIncorrectSecondFactorAlert = true
							self.secondFactorError = WasserflugError.http429
						}
					case let .failure(error):
						self.logger.error("Encountered an unexpected error while attempting 2fa. Reporting the error to the user. Error: \(String(reflecting: error))")
						self.showIncorrectSecondFactorAlert = true
						self.secondFactorError = error
					}
				}
			}
	}
}

class UserInfo: ObservableObject {
	@Published var userSelf: UserSelfV3Response?
	@Published var userSubscriptions: [UserSubscriptionModel] = []
	@Published var creators: [String: CreatorModelV3] = [:]
	@Published var creatorOwners: [String: UserModelShared] = [:] {
		didSet {
			setCreatorsInOrder()
		}
	}

	@Published var creatorsInOrder: [(CreatorModelV3, UserModelShared)] = []
	
	private func setCreatorsInOrder() {
		for sub in userSubscriptions {
			if !creatorsInOrder.contains(where: { $0.0.id == sub.creator }) {
				if let creator = creators[sub.creator], let creatorOwner = creatorOwners[creator.owner.id] {
					creatorsInOrder.append((creator, creatorOwner))
				}
			}
		}
	}
}
