import SwiftUI
import FloatplaneAPIClient
import OAuthKit
import EFQRCode

struct LoginView2: View {
	@ObservedObject var viewModel: AuthViewModel
	@EnvironmentObject var navigationCoordinator: NavigationCoordinator<WasserflugRoute>
	@Environment(OAuth.self) var oauth: OAuth
	
	@State private var deviceCodeQrCode: CGImage? = nil
	
	private enum Field: Hashable {
		case usernameField
		case passwordField
		case loginButton
	}

	@FocusState private var focusedField: Field?
	
	var body: some View {
		GeometryReader { geometry in
			ZStack {
				VStack {
					Text("Login to Floatplane")
						.bold()
					Spacer()
					
					switch oauth.state {
					case let .error(_, error):
						Text("Error: \(error)")
					case .requestingDeviceCode:
						Text("Loading login...")
						ProgressView()
					case let .receivedDeviceCode(_, deviceCode):
						HStack {
							VStack {
								Text("Visit \(deviceCode.verificationUri) and enter \(deviceCode.userCode)")
							}
							.frame(width: 400)
							if let deviceCodeQrCode {
								Divider()
								VStack {
									Text("Or scan this QR code with your smartphone")
									Image(decorative: deviceCodeQrCode, scale: 1.0, orientation: .up)
								}
								.frame(width: 400)
							}
						}
					case .requestingAccessToken:
						Text("Logging in...")
						ProgressView()
					case .authorizing:
						Text("Authorizing?")
					case .authorized:
						Text("Logged in!")
							.onAppear {
								navigationCoordinator.popToRoot()
							}
					case .empty:
						Text("Empty??")
					}
					
					Spacer()
				}
				.multilineTextAlignment(.center)
				.frame(maxWidth: geometry.size.width * 0.4)
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
		}
		.onAppear {
			switch oauth.state {
			case .empty, .error:
				if let provider = oauth.providers.first {
					oauth.authorize(provider: provider, grantType: .deviceCode)
				}
			default:
				break
			}
		}
		.onChange(of: oauth.state) { old, new in
			switch new {
			case let .receivedDeviceCode(_, deviceCode):
				if let completeUrl = deviceCode.verificationUriComplete {
					let generator = try? EFQRCode.Generator(completeUrl, style: .basic(params: .init()))
					if let image = try? generator?.toImage(width: 300).cgImage {
						deviceCodeQrCode = image
					} else {
						print("Create QRCode image failed!")
					}
				}
			default:
				break
			}
		}
		.alert("Login", isPresented: $viewModel.showIncorrectLoginAlert, actions: { }, message: {
			if let error = viewModel.loginError {
				Text("""
				There was an error while attempting to log in. Please submit a bug report with the app developer, *NOT* with Floatplane staff.

				\(error.localizedDescription)
				""")
			} else {
				Text("""
				Username or password is incorrect.
				If you have forgotten your password, please reset it via https://www.floatplane.com/reset-password
				""")
			}
		})
	}
}

struct LoginView2_Previews: PreviewProvider {
	static var oauth: OAuth = OAuth()
	static let provider = OAuth.Provider(
		id: "https://auth.floatplane.com/realms/floatplane-pp",
		authorizationURL: URL(string: "https://auth.floatplane.com/realms/floatplane-pp/protocol/openid-connect/auth")!,
		accessTokenURL: URL(string: "https://auth.floatplane.com/realms/floatplane-pp/protocol/openid-connect/token")!,
		deviceCodeURL: URL(string: "https://auth.floatplane.com/realms/floatplane-pp/protocol/openid-connect/auth/device")!,
		clientID: "hydravion",
		clientSecret: nil,
		encodeHttpBody: true,
		customUserAgent: "Wasserflug tvOS App version, Previews",
		debug: true,
	)

	static var previews: some View {
		Group {
			LoginView2(viewModel: AuthViewModel(fpApiService: MockFPAPIService()))
				.environment(oauth)
				.onAppear {
					oauth.state = .receivedDeviceCode(provider, .init(deviceCode: "{the device code}", userCode: "ABCD-EFGH", verificationUri: "https://example.com", verificationUriComplete: "https://example.com/ABCD-EFGH", expiresIn: 60, interval: 5))
				}
		}
	}
}
