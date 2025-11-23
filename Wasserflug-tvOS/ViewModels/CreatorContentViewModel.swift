import SwiftUI
import Combine
import CoreData
import FloatplaneAPIClient

class CreatorContentViewModel: BaseViewModel, ObservableObject {
	
	enum LoadingMode {
		case append
		case prepend
	}
	
	@Published var state: ViewModelState<[BlogPostModelV3]> = .idle
	@Published var searchText: String = ""
	
	private var isVisible = true
	private let fpApiService: FPAPIService
	let managedObjectContext: NSManagedObjectContext
	let creatorOrChannel: CreatorOrChannel
	let livestream: LiveStreamModel?
	var searchDebounce: AnyCancellable? = nil
	
	var hasCover: Bool {
		creatorOrChannel.cover == nil
	}
	
	var coverImagePath: URL? {
		if let cover = creatorOrChannel.cover {
			return URL(string: cover.path)
		} else {
			return nil
		}
	}
	
	var creatorProfileImagePath: URL? {
		URL(string: creatorOrChannel.icon.path)
	}
	
	fileprivate var aboutFirstNewlineIndex: String.Index {
		if creatorOrChannel.about.first == "#" {
			return creatorOrChannel.aboutFixed.firstIndex(of: "\n") ?? creatorOrChannel.aboutFixed.startIndex
		} else {
			return creatorOrChannel.aboutFixed.startIndex
		}
	}

	lazy var creatorAboutHeader: AttributedString = (try? AttributedString(markdown: String(creatorOrChannel.aboutFixed[..<aboutFirstNewlineIndex]), options: .init(allowsExtendedAttributes: false, interpretedSyntax: .full, failurePolicy: .returnPartiallyParsedIfPossible, languageCode: nil))) ?? AttributedString("")
	lazy var creatorAboutBody: AttributedString = (try? AttributedString(markdown: String(creatorOrChannel.aboutFixed[aboutFirstNewlineIndex...]), options: .init(allowsExtendedAttributes: false, interpretedSyntax: .full, failurePolicy: .returnPartiallyParsedIfPossible, languageCode: nil))) ?? AttributedString("")
	
	init(fpApiService: FPAPIService, managedObjectContext: NSManagedObjectContext, creatorOrChannel: CreatorOrChannel, livestream: LiveStreamModel?) {
		self.fpApiService = fpApiService
		self.managedObjectContext = managedObjectContext
		self.creatorOrChannel = creatorOrChannel
		self.livestream = livestream
		super.init()
		
		searchDebounce = $searchText
			.debounce(for: 0.8, scheduler: DispatchQueue.main)
			.removeDuplicates()
			.dropFirst()
			.sink(receiveValue: { _ in
				self.state = .loading
				self.load()
			})
	}
	
	func createSubViewModel() -> CreatorContentViewModel {
		return CreatorContentViewModel(fpApiService: fpApiService,
									   managedObjectContext: managedObjectContext,
									   creatorOrChannel: creatorOrChannel,
									   livestream: livestream)
	}
	
	func load(loadingMode: LoadingMode = .append) {
		Task { @MainActor in
			if self.state.isIdle {
				state = .loading
			}
			
			var fetchAfter = 0
			switch (loadingMode, state) {
			case let (.append, .loaded(posts)):
				fetchAfter = posts.count
			default:
				break
			}
			
			let creatorId = creatorOrChannel.creatorId
			let channelId = creatorOrChannel.channelId
			let limit = 20
			logger.info("Loading creator content.", metadata: [
				"creatorId": "\(creatorId)",
				"channelId": "\(channelId ?? "")",
				"limit": "\(limit)",
				"fetchAfter": "\(fetchAfter)",
				"searchText": "\(self.searchText)",
			])
			
			let response: [BlogPostModelV3]
			do {
				response = try await fpApiService.getCreatorContent(id: creatorId, limit: limit, fetchAfter: fetchAfter, search: self.searchText, channelId: channelId)
			} catch {
				self.state = .failed(error)
				return
			}
			
			if !response.isEmpty {
				logger.info("Loading progress for creator content in background.")
				Task {
					do {
						let progresses = try await fpApiService.getProgress(ids: response.map(\.id))
						for progress in progresses {
							let blogPostId = progress.id
							if let blogPost = response.first(where: { $0.id == blogPostId }) {
								if let videoId = blogPost.firstVideoAttachmentId {
									VideoViewModel.updateLocalProgress(logger: logger, blogPostId: blogPostId, videoId: videoId, videoDuration: 100.0, progressSeconds: progress.progress, managedObjectContext: managedObjectContext)
								}
							}
						}
						self.logger.info("Done loading \(progresses.count) progresses for creator content.")
					} catch {
						self.logger.warning("Error retrieving watch progress: \(String(reflecting: error))")
						Toast.post(toast: .init(.failedToLoadProgress))
					}
				}
			}
			
			switch (loadingMode, self.state) {
			case let (.append, .loaded(posts)):
				self.logger.notice("Received creator content. Appending new items to list. Received \(response.count) items.")
				self.state = .loaded(posts + response)
			case let (.prepend, .loaded(prevResponse)):
				let prevResponseIds = Set(prevResponse.lazy.map(\.id))
				if let last = response.last, prevResponseIds.contains(last.id) {
					let newBlogPosts = response.filter({ !prevResponseIds.contains($0.id) })
					self.logger.notice("Received creator content. Received \(response.count) items. Prepending only new items to list. Prepending \(newBlogPosts.count) items.")
					if !newBlogPosts.isEmpty {
						self.state = .loaded(newBlogPosts + prevResponse)
					}
				} else {
					self.logger.notice("Received creator content. Encountered gap in new items and old items. Resetting list to only new items. Received \(response.count) items.")
					
					self.state = .loaded(response)
				}
			default:
				self.logger.notice("Received creator content. Received \(response.count) items.")
				self.state = .loaded(response)
			}
		}
	}
	
	func itemDidAppear(_ item: BlogPostModelV3) {
		switch state {
		case let .loaded(posts):
			if posts.lastIndex(of: item) == posts.endIndex.advanced(by: -1) {
				self.logger.info("Last item appeared on screen. Loading more creator content.")
				self.load()
			}
		default:
			break
		}
	}
	
	func creatorContentDidDisappear() {
		isVisible = false
	}
	
	func creatorContentDidAppearAgain() {
		if !isVisible {
			self.load(loadingMode: .prepend)
		}
	}
}

class MockCreatorContentViewModel: CreatorContentViewModel {
	init(state: ViewModelState<[BlogPostModelV3]>) {
		super.init(fpApiService: MockFPAPIService(), managedObjectContext: PersistenceController.preview.container.viewContext, creatorOrChannel: MockData.creatorV3, livestream: MockData.creatorV3.liveStream)
		self.state = state
	}
}
