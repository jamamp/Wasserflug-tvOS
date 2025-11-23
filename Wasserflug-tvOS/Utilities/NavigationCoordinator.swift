import Foundation
import SwiftUI
import FloatplaneAPIClient

enum WasserflugRoute: Hashable {
	// Flow: authentication
	case login
	case secondFactor
	
	// Flow: main content
	case blogPostView(blogPostId: String, autoPlay: Bool)
	case searchView(creatorOrChannel: AnyCreatorOrChannel)
	case livestreamView(creatorId: String, livestreamId: String)
	case videoView(videoAttachment: VideoAttachmentModel, content: ContentPostV3Response, description: AttributedString, beginningWatchTime: Double)
}

class NavigationCoordinator<Route>: ObservableObject where Route : Hashable {
	@Published var path = NavigationPath()

	func popToRoot() {
		path.removeLast(path.count)
	}
	
	func push(route: Route) {
		path.append(route)
	}
}
