import SwiftUI

struct CreatorSearchView: View {
	
	@StateObject var viewModel: CreatorContentViewModel
	
	let creatorName: String
	
	private let gridColumns: [GridItem] = Array<GridItem>(
		repeating: GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 30, alignment: .top),
		count: 4
	)
	
	var body: some View {
		ScrollView {
			switch viewModel.state {
			case .idle:
				EmptyView()
			case .loading:
				ProgressView()
			case let .failed(error):
				ErrorView(error: error, tryAgainText: "Try Again", tryAgainHandler: {
					viewModel.state = .loading
					viewModel.load()
				})
			case let .loaded(content):
				LazyVGrid(columns: gridColumns, spacing: 20) {
					ForEach(content) { blogPost in
						BlogPostSelectionView(blogPost: blogPost)
							.onAppear(perform: {
								viewModel.itemDidAppear(blogPost)
							})
					}
				}
				.padding(40)
			}
		}
		.searchable(text: $viewModel.searchText, prompt: "Search \(self.creatorName)")
	}
}

struct CreatorSearchView_Previews: PreviewProvider {
	static var previews: some View {
		CreatorSearchView(viewModel: CreatorContentViewModel(fpApiService: MockFPAPIService(), managedObjectContext: PersistenceController.preview.container.viewContext, creatorOrChannel: MockData.creatorV3, livestream: nil), creatorName: "Linus Tech Tips")
	}
}
