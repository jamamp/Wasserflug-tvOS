import SwiftUI
import FloatplaneAPIClient
import OAuthKit

struct LoginView2: View {
	@ObservedObject var viewModel: AuthViewModel
	@EnvironmentObject var navigationCoordinator: NavigationCoordinator<WasserflugRoute>
	@Environment(OAuth.self) var oauth: OAuth
	
	@State var username: String = ""
	@State var password: String = ""
	
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
					case let .error(provider, error):
						Text("Error: \(error)")
					case .requestingDeviceCode:
						Text("Loading login...")
						ProgressView()
					case let .receivedDeviceCode(provider, deviceCode):
						Text("Visit \(deviceCode.verificationUri) and enter \(deviceCode.userCode)")
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
				}
				.multilineTextAlignment(.center)
				.frame(maxWidth: geometry.size.width * 0.4)
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
		}
		.onAppear {
			switch oauth.state {
			case .empty:
				oauth.authorize(provider: oauth.providers.first!, grantType: .deviceCode)
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
	static var previews: some View {
		Group {
			LoginView(viewModel: AuthViewModel(fpApiService: MockFPAPIService()))
		}
	}
}
