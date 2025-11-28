import SwiftUI
import FloatplaneAPIClient
import Vapor
import os
import Logging
import OAuthKit

@main
struct Wasserflug_tvOSApp: App {
	static var logger: Logging.Logger {
		var logger = Logging.Logger(label: Bundle.main.bundleIdentifier!)
		#if DEBUG
			// For debugging, log at a lower level to get more information.
			logger.logLevel = .info
		#else
			// For release mode, only log important items.
			logger.logLevel = .notice
		#endif
		return logger
	}

	static var networkLogger: Logging.Logger {
		var logger = Logging.Logger(label: Bundle.main.bundleIdentifier!)
		logger.logLevel = .info
		logger[metadataKey: "category"] = "network"
		return logger
	}
	
	var oauth: OAuth = .init()
	let vaporApp = Vapor.Application(.production, .singleton)
	let fpApiService: FPAPIService = DefaultFPAPIService()
	let authViewModel: AuthViewModel
	let persistenceController = PersistenceController.shared
	
	init() {
		// Set custom user agent for network requests. This is particularly
		// required in order to pass the login phase with bypassing the captcha.
		let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "<unknown>"
		let bundleVersion = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "<unknown>"
		Wasserflug_tvOSApp.setHttp(header: "User-Agent", value: "Wasserflug tvOS App version \(appVersion)-\(bundleVersion), CFNetwork")
		
		oauth = .init(providers: [.init(
			id: "https://auth.floatplane.com/realms/floatplane",
			authorizationURL: URL(string: "https://auth.floatplane.com/realms/floatplane/protocol/openid-connect/auth")!,
			accessTokenURL: URL(string: "https://auth.floatplane.com/realms/floatplane/protocol/openid-connect/token")!,
			deviceCodeURL: URL(string: "https://auth.floatplane.com/realms/floatplane/protocol/openid-connect/auth/device")!,
			clientID: "wasserflug",
			clientSecret: nil,
			encodeHttpBody: true,
			customUserAgent: "Wasserflug tvOS App version \(appVersion)-\(bundleVersion), CFNetwork",
			debug: true,
		)], options: [
			.autoRefresh: true,
		])
		
		// Attempt to use any previous authentication cookies, so the user does
		// not need to login on every app start.
//		FloatplaneAPIClientAPI.loadAuthenticationCookiesFromStorage()
		FloatplaneAPIClientAPI.basePath = "https://www.floatplane.com"
		
		// Use FP's date format for JSON encoding/decoding.
		let fpDateFormatter = DateFormatter()
		fpDateFormatter.locale = Locale(identifier: "en_US_POSIX")
		fpDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
		Configuration.contentConfiguration.use(encoder: JSONEncoder.custom(dates: .formatted(fpDateFormatter)), for: .json)
		Configuration.contentConfiguration.use(decoder: JSONDecoder.custom(dates: .formatted(fpDateFormatter)), for: .json)
		
		// Bootstrap core logging.
		LoggingSystem.bootstrap({ label -> LogHandler in
			var loggingLogger = OSLoggingLogger(label: label, category: "Wasserflug")
			loggingLogger.logLevel = .debug
			return MultiplexLogHandler([
				loggingLogger,
			])
		})
		
		// Create and store in @State the main view model.
		authViewModel = AuthViewModel(fpApiService: fpApiService)
	}
	
	func setup() {
		// Bootstrap API/Network logging.
		Configuration.apiClient = vaporApp.client
			.logging(to: Wasserflug_tvOSApp.networkLogger)
		Configuration.apiWrapper = { clientRequest in
			switch oauth.state {
			case let .authorized(provider, auth):
				clientRequest.headers.bearerAuthorization = .init(token: auth.token.accessToken)
			default:
				break
			}
			Wasserflug_tvOSApp.networkLogger.info("Sending \(clientRequest.method) request to \(clientRequest.url)")
		}
	}
	
	var body: some Scene {
		WindowGroup {
			ContentView(viewModel: authViewModel)
				.environment(\.fpApiService, fpApiService)
				.environment(\.managedObjectContext, persistenceController.container.viewContext)
				.environment(oauth)
				.onAppear {
					setup()
				}
		}
	}
	
	private static func setHttp(header: String, value: String) {
		FloatplaneAPIClientAPI.customHeaders.replaceOrAdd(name: header, value: value)
		if var headers = URLSession.shared.configuration.httpAdditionalHeaders {
			headers[header] = value
			URLSession.shared.configuration.httpAdditionalHeaders = headers
		} else {
			URLSession.shared.configuration.httpAdditionalHeaders = [
				header: value,
			]
		}
	}
}
