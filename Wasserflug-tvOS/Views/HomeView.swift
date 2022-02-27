import SwiftUI
import FloatplaneAPIClient

struct HomeView: View {
	@StateObject var viewModel: HomeViewModel
	
	@EnvironmentObject var userInfo: UserInfo
	
	private let gridColumns: [GridItem] = [
		GridItem(.flexible(minimum: 0, maximum: .infinity), alignment: .top),
		GridItem(.flexible(minimum: 0, maximum: .infinity), alignment: .top),
		GridItem(.flexible(minimum: 0, maximum: .infinity), alignment: .top),
		GridItem(.flexible(minimum: 0, maximum: .infinity), alignment: .top),
	]
	
	var body: some View {
		switch viewModel.state {
		case .idle:
			Color.clear.onAppear(perform: {
				viewModel.load()
			})
		case .loading:
			ProgressView()
		case let .failed(error):
			ErrorView(error: error)
		case let .loaded(response):
			ScrollView {
				LazyVGrid(columns: gridColumns, spacing: 60) {
					ForEach(response.blogPosts) { blogPost in
						BlogPostSelectionView(blogPost: blogPost)
							.onAppear(perform: {
								viewModel.itemDidAppear(blogPost)
							})
					}
				}
				.padding()
			}.onDisappear {
				viewModel.homeDidDisappear()
			}.onAppear {
				viewModel.homeDidAppearAgain()
			}
		}
	}
}

struct HomeView_Previews: PreviewProvider {
	static var previews: some View {
		NavigationView {
			HomeView(viewModel: HomeViewModel(userInfo: MockData.userInfo, fpApiService: MockFPAPIService()))
				.environmentObject(MockData.userInfo)
		}
	}
}
