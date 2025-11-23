import SwiftUI
import CoreData
import Logging
import FloatplaneAPIClient
import OAuthKit

struct SettingsView: View {
	@Namespace var namespace
	@Environment(\.managedObjectContext) private var viewContext
	@EnvironmentObject var userInfo: UserInfo
	@Environment(OAuth.self) var oauth: OAuth
	
	@State var showResetViewHistoryConfirmation = false
	@State var showResetViewHistorySuccess = false
	@State var showResetViewHistoryFailure = false
	
	static let showNewSidebarKey = "ShowNewSidebar"
	@AppStorage(Self.showNewSidebarKey) var showNewSidebar: Bool = true
	
	let logger: Logger = {
		var logger = Wasserflug_tvOSApp.logger
		logger[metadataKey: "class"] = "\(Self.Type.self)"
		return logger
	}()
	
	var body: some View {
		VStack {
			if let userSelf = userInfo.userSelf, let imageUrl = URL(string: userSelf.profileImage.path) {
				HStack(spacing: 20) {
					Text(verbatim: "Logged in as \(userSelf.username)")
					let pfpSize: CGFloat = 75
					AsyncImage(url: imageUrl, content: { image in
						image
							.resizable()
							.frame(width: pfpSize, height: pfpSize)
					}, placeholder: {
						ProgressView()
							.frame(width: pfpSize, height: pfpSize)
					})
					.accessibilityLabel("Logged-in user profile picture")
				}
				.padding([.top])
			}
			
			Spacer()
			
			HStack {
				Button(action: {
					logger.notice("Logging user out")
//					FloatplaneAPIClientAPI.removeAuthenticationCookies()
					oauth.clear()
					
					NotificationCenter.default.post(name: .loggedOut, object: nil)
				}, label: {
					Text("Logout")
				})
				.prefersDefaultFocus(in: namespace)
			}
			
			HStack {
				Button(action: {
					showNewSidebar.toggle()
				}, label: {
					Text(showNewSidebar ? "Show old tab view" : "Show new sidebar")
				})
			}
			
			HStack {
				Button(action: {
					showResetViewHistoryConfirmation = true
				}, label: {
					Text("Reset Local View History")
				})
				.confirmationDialog("Reset Local View History", isPresented: $showResetViewHistoryConfirmation, actions: {
					Button("Reset", role: .destructive, action: {

						let fetchRequest: NSFetchRequest<NSFetchRequestResult> = WatchProgress.fetchRequest()
						let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
						do {
							try viewContext.execute(deleteRequest)
							showResetViewHistorySuccess = true
						} catch {
							logger.error("Error resetting view history: \(String(reflecting: error))")
							showResetViewHistoryFailure = true
						}

						showResetViewHistoryConfirmation = false
					})
				}, message: {
					Text("This will remove all view local history from this device. It may be restored from Floatplane view history. Are you sure you want to continue?")
				})
				.alert("Resetting View History Successful", isPresented: $showResetViewHistorySuccess, actions: {})
				.alert("Resetting View History Failed", isPresented: $showResetViewHistoryFailure, actions: {})
			}
//				.frame(maxWidth: .infinity)
//				.focusSection()
			
			Spacer()
		}
//			.frame(maxWidth: .infinity)
//			.focusScope(namespace)
	}
}

struct SettingsView_Previews: PreviewProvider {
	static var previews: some View {
		SettingsView()
			.environmentObject(MockData.userInfo)
	}
}
