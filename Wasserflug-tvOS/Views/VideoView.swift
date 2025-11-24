import SwiftUI
import AVKit
import FloatplaneAPIClient

struct VideoView: View {
	
	@StateObject var viewModel: VideoViewModel
	let beginningWatchTime: Double
	
	var body: some View {
		switch viewModel.state {
		case .idle:
			ProgressView().onAppear(perform: {
				viewModel.load()
			})
		case .loading:
			ProgressView()
		case let .failed(error):
			ErrorView(error: error, tryAgainText: "Refresh", tryAgainHandler: {
				viewModel.state = .idle
			})
		case .loaded:
			VideoPlayerView(viewModel: viewModel, beginningWatchTime: beginningWatchTime)
				.edgesIgnoringSafeArea(.all)
		}
	}
}

struct VideoView_Previews: PreviewProvider {
	static var previews: some View {
		VideoView(viewModel: VideoViewModel(fpApiService: MockFPAPIService(), videoAttachment: MockData.getBlogPost.videoAttachments!.first!, contentPost: MockData.getBlogPost, description: "Test description", bearerToken: "foo"), beginningWatchTime: 0.75)
	}
}
