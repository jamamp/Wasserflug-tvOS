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
	
	private let gridColumns: [GridItem] = Array<GridItem>(
		repeating: GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 30, alignment: .top),
		count: 4
	)
	
	var banner: some View {
		AsyncImage(url: viewModel.coverImagePath, content: { image in
			ZStack {
				image
					.resizable()
					.scaledToFill()
					.overlay(LinearGradient(
						colors: [.clear, .black.opacity(0.3)],
						startPoint: .top,
						endPoint: .bottom)
					)
			}
		}, placeholder: {
			ProgressView()
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				.aspectRatio(viewModel.creatorOrChannel.cover?.aspectRatio ?? 1.0, contentMode: .fit)
		})
	}
	
	var creatorAbout: some View {
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
			NavigationLink(value: WasserflugRoute.searchView(creatorOrChannel: AnyCreatorOrChannel(viewModel.creatorOrChannel)), label: {
				Label("Search", systemImage: "magnifyingglass")
			})
			
			// Livestream button
			if let livestream = self.viewModel.livestream {
				NavigationLink(value: WasserflugRoute.livestreamView(creatorId: self.viewModel.creatorOrChannel.creatorId,
																	 livestreamId: livestream.id), label: {
						Label("Livestream", systemImage: "play.tv")
					})
			}
			
			// Creator "about" information
			VStack {
				Text(viewModel.creatorAboutHeader)
					.fontWeight(.bold)
					.font(.system(.headline))
					.frame(maxWidth: .infinity, alignment: .leading)
				Text(viewModel.creatorAboutBody)
					.frame(maxWidth: .infinity, alignment: .leading)
			}
			.padding([.trailing])
		}
		.padding(.top)
		.focusSection()
	}
	
	func blogPosts(content: [BlogPostModelV3]) -> some View {
		LazyVGrid(columns: gridColumns, spacing: 20) {
			ForEach(content) { blogPost in
				BlogPostSelectionView(blogPost: blogPost)
					// .focused($blogPostFocus, equals: blogPost.id)
					.onAppear(perform: {
						viewModel.itemDidAppear(blogPost)
					})
			}
		}
		.padding([.leading, .trailing], 40)
	}
	
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
						banner
						
						// Row for pfp, search, livestream, about
						creatorAbout
						
						// Blog posts
						blogPosts(content: content)
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
		CreatorContentView(viewModel: MockCreatorContentViewModel(state: .loaded(MockData.blogPosts.blogPosts)))
			.environmentObject(MockData.userInfo)
			.ignoresSafeArea()
	}
}
