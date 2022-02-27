import SwiftUI
import FloatplaneAPIClient
import CachedAsyncImage

struct PlayMediaView<Content>: View where Content: View {
	
	let thumbnail: ImageModel
	let showPlayButton: Bool
	let width: CGFloat?
	let playButtonSize: PlayButton.Size
	let playContent: () -> Content
	
	@State var isShowingMedia = false
	
	var body: some View {
		ZStack {
			if showPlayButton {
				image
					.frame(width: width)
			} else {
				Button(action: {
					isShowingMedia = true
				}, label: {
					image
						.frame(width: width)
				})
					.buttonStyle(.card)
					.padding()
			}
		}
	}
	
	var image: some View {
		CachedAsyncImage(url: URL(string: thumbnail.path), content: { image in
			ZStack {
				image
					.resizable()
					.scaledToFit()
//					.frame(maxWidth: geometry.size.width * 0.5)
					.cornerRadius(10.0)
				if showPlayButton {
					PlayButton(size: playButtonSize, action: {
						isShowingMedia = true
					})
//						.prefersDefaultFocus(in: screenNamespace)
						.sheet(isPresented: $isShowingMedia, onDismiss: {
							isShowingMedia = false
						}, content: {
							playContent()
						})
				}
			}
		}, placeholder: {
			ZStack {
				ProgressView()
				Rectangle()
					.fill(.clear)
//					.frame(width: geometry.size.width * 0.5)
//					.frame(width: 200)
					.aspectRatio(thumbnail.aspectRatio, contentMode: .fit)
			}
		})
	}
}

struct PlayMediaView_Previews: PreviewProvider {
	static var previews: some View {
		VStack {
			PlayMediaView(
				thumbnail: MockData.blogPosts.blogPosts.first!.thumbnail,
				showPlayButton: true,
				width: 200,
				playButtonSize: .small,
				playContent: { EmptyView() })
			PlayMediaView(
				thumbnail: MockData.blogPosts.blogPosts.first!.thumbnail,
				showPlayButton: false,
				width: 500,
				playButtonSize: .default,
				playContent: { EmptyView() })
		}
	}
}
