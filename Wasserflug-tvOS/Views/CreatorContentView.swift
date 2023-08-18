import SwiftUI
import FloatplaneAPIClient

struct CreatorContentView: View {
	@EnvironmentObject var userInfo: UserInfo
	@Environment(\.fpApiService) var fpApiService
	@Environment(\.colorScheme) var colorScheme
	@Environment(\.scenePhase) var scenePhase
	
	@StateObject var viewModel: CreatorContentViewModel
	
	@State var isShowingSearch = false
	@FocusState var blogPostFocus: String?
	
	let gridColumns: [GridItem] = [
		GridItem(.flexible(minimum: 0, maximum: .infinity), alignment: .top),
		GridItem(.flexible(minimum: 0, maximum: .infinity), alignment: .top),
		GridItem(.flexible(minimum: 0, maximum: .infinity), alignment: .top),
		GridItem(.flexible(minimum: 0, maximum: .infinity), alignment: .top),
	]
	
	var body: some View {
		VStack {
			switch viewModel.state {
			case .idle:
				ProgressView().onCombinedCustomAppear {
					viewModel.load()
				}
			case .loading:
				ProgressView()
			case let .failed(error):
				ErrorView(error: error, tryAgainText: "Refresh", tryAgainHandler: {
					viewModel.state = .idle
				})
			case let .loaded(content):
				GeometryReader { geometry in
					ScrollView {
						// Banner image
						AsyncImage(url: viewModel.coverImagePath, content: { image in
							ZStack {
								image
									.resizable()
									.scaledToFill()
									.overlay(LinearGradient(
										// Only have a shadow on the banner in dark mode. Otherwise, looks odd in light mode.
										colors: [.clear, colorScheme == .dark ? .black.opacity(0.6) : .clear],
										startPoint: .top,
										endPoint: .bottom)
									)
							}
						}, placeholder: {
							ProgressView()
								.frame(maxWidth: .infinity, maxHeight: .infinity)
								.aspectRatio(viewModel.creatorOrChannel.cover?.aspectRatio ?? 1.0, contentMode: .fit)
						})
						
						// Row for pfp, search, livestream, about
						HStack(alignment: .top) {
							
							// Creator profile picture, moved up into the above banner image and circled
							AsyncImage(url: viewModel.creatorProfileImagePath, content: { image in
								image
									.resizable()
									.frame(width: 150, height: 150)
									.clipShape(Circle())
							}, placeholder: {
								ProgressView()
									.frame(width: 150, height: 150)
							})
							.offset(x: 20, y: -115) // Half the height (150/2=75) + 40pts of padding = 115pt
							
							// Search button
							NavigationLink(value: WasserflugRoute.searchView(creatorOrChannel: AnyCreatorOrChannel(viewModel.creatorOrChannel), creatorOwner: AnyUserModelShared(viewModel.creatorOwner)), label: {
								Label("Search", systemImage: "magnifyingglass")
							})
							
							// Livestream button
							NavigationLink(value: WasserflugRoute.livestreamView(creatorId: self.viewModel.creatorOrChannel.creatorId, livestreamId: self.viewModel.creatorOrChannel.liveStream?.id ?? ""), label: {
								Label("Livestream", systemImage: "play.tv")
							})
							
							// Creator "about" information
							VStack {
								Text(viewModel.creatorAboutHeader)
									.fontWeight(.bold)
									.font(.system(.headline))
									.frame(maxWidth: .infinity, alignment: .leading)
								Text(viewModel.creatorAboutBody)
									.frame(maxWidth: .infinity, alignment: .leading)
							}
						}
						.padding(.top)
						.focusSection()
						
						LazyVGrid(columns: gridColumns, spacing: 60) {
							ForEach(content) { blogPost in
								BlogPostSelectionView(
									blogPost: blogPost,
									viewOrigin: .creator,
									watchProgresses: FetchRequest(entity: WatchProgress.entity(), sortDescriptors: [], predicate: NSPredicate(format: "blogPostId = %@", blogPost.id), animation: .default)
								)
//									.focused($blogPostFocus, equals: blogPost.id)
								.onAppear(perform: {
									viewModel.itemDidAppear(blogPost)
								})
							}
						}
						.padding(40)
					}
				}.onCombinedCustomDisappear {
					viewModel.creatorContentDidDisappear()
				}.onCombinedCustomAppear {
					blogPostFocus = content.first?.id
					// Load new content when the view re-appears, like when switching
					// tabs. There is no refresh button.
					viewModel.creatorContentDidAppearAgain()
				}.onChange(of: scenePhase, perform: { phase in
					switch phase {
					case .active:
						// Similarly, load new content if the app wakes up from
						// inactive/background activity.
						viewModel.creatorContentDidAppearAgain()
					case .inactive, .background:
						viewModel.creatorContentDidDisappear()
					@unknown default:
						break
					}
				})
			}
		}
	}
}

struct CreatorContentView_Previews: PreviewProvider {
	@State static var selection = RootTabView.Selection.creator(MockData.creatorV3.id)
	static var previews: some View {
		TabView(selection: $selection) {
			Text("test").tabItem {
				Text("Home")
			}
			CreatorContentView(viewModel: CreatorContentViewModel(
				fpApiService: MockFPAPIService(),
				managedObjectContext: PersistenceController.preview.container.viewContext,
				creatorOrChannel: MockData.creatorV3,
				creatorOwner: MockData.creatorOwners.users[0].user.userModelShared
			))
			.tag(RootTabView.Selection.creator(MockData.creatorV3.id))
			.tabItem {
				Text(MockData.creatorV3.title)
			}
			.environmentObject(MockData.userInfo)
			Text("test").tabItem {
				Text("Settings")
			}
		}
	}
}
