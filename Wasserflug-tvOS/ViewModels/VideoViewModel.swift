import Foundation
import CoreData
import Logging
import FloatplaneAPIClient
import NIO
import AVKit
import SwiftUI

class VideoViewModel: BaseViewModel, ObservableObject {
	
	enum VideoError: Error, CustomStringConvertible {
		case badResponse
		case noQualityLevelsFound
		
		var description: String {
			switch self {
			case .badResponse:
				return "There was an error retrieving the livestream information. Please try again."
			case .noQualityLevelsFound:
				return "Unable to find any playable content from this video for your device."
			}
		}
	}
	
	@Published var state: ViewModelState<(CdnDeliveryV3Response, ContentVideoV3Response)> = .idle
	
	private let fpApiService: FPAPIService
	let videoAttachment: VideoAttachmentModel
	let contentPost: ContentPostV3Response
	let description: AttributedString
	
	let supportedSpeeds = [AVPlaybackSpeed(rate: 0.5, localizedName: "x0.5"),
						   AVPlaybackSpeed(rate: 0.75, localizedName: "x0.75"),
						   AVPlaybackSpeed(rate: 1.0, localizedName: "x1.0"),
						   AVPlaybackSpeed(rate: 1.25, localizedName: "x1.25"),
						   AVPlaybackSpeed(rate: 1.5, localizedName: "x1.5"),
						   AVPlaybackSpeed(rate: 1.75, localizedName: "x1.75"),
						   AVPlaybackSpeed(rate: 2.0, localizedName: "x2.0")]
	
	private var resourceLoaderDelegate: HLSResourceLoaderDelegate?
	
	var avMetadataItems: [AVMetadataItem] {
		let desc = String(description.characters)
		
		var releaseDate = videoAttachment.releaseDate?.formatted(.dateTime) ?? ""
		if releaseDate == "" {
			releaseDate = contentPost.releaseDate.formatted(.dateTime)
		}
		
		return [
			metadataItem(identifier: .commonIdentifierTitle, value: videoAttachment.title),
			metadataItem(identifier: .commonIdentifierDescription, value: desc),
			metadataItem(identifier: .iTunesMetadataTrackSubTitle, value: releaseDate),
//			metadataItem(identifier: .commonIdentifierArtwork, value: videoAttachment.thumbnail.path),
		]
	}
	
	private(set) var qualityLevels: [String: (URL, CdnDeliveryV3Variant)] = [:]
	
	init(fpApiService: FPAPIService, videoAttachment: VideoAttachmentModel, contentPost: ContentPostV3Response, description: AttributedString, bearerToken: String) {
		self.fpApiService = fpApiService
		self.videoAttachment = videoAttachment
		self.contentPost = contentPost
		self.description = description
		
		super.init()
		self.resourceLoaderDelegate = HLSResourceLoaderDelegate(logger: self.logger, bearerToken: bearerToken)
	}
	
	func load() {
		Task { @MainActor in
			self.state = .loading
			
			let type: CDNV2API.ModelType_getDeliveryInfo = .vod
			self.logger.info("Loading video information.", metadata: [
				"type": "\(type)",
				"id": "\(videoAttachment.guid)",
			])
			
			let deliveryInfo: CdnDeliveryV3Response
			let videoContent: ContentVideoV3Response
			do {
				deliveryInfo = try await self.fpApiService.getDeliveryInfo(scenario: .ondemand, entityId: videoAttachment.guid, outputKind: nil)
				videoContent = try await self.fpApiService.getVideoContent(id: videoAttachment.id)
			} catch {
				self.state = .failed(error)
				return
			}
			
			self.logger.notice("Received video information.", metadata: [
				"origins": "\(deliveryInfo.groups.flatMap({ $0.origins ?? [] }).map(\.url).joined(separator: ", "))",
			])
			
			let screenNativeBounds = UIScreen.main.nativeBounds
			// Only use the first group, for now.
			let group = deliveryInfo.groups.first
			let variants = group?.variants
			let filteredVariants = variants?.filter({ variant in
				let enabled = variant.enabled ?? false
				let hidden = variant.hidden ?? false
				
				// Filter out resolutions larger than the device's screen resolution to save
				// on bandwidth and downscaling performance.
				// Use height for these comparisons. If using width, we run into funny issues with
				// LTT videos which use 2:1 aspect ratios (1080p is 2160x1080 instead of 1920x1080,
				// and 4K is 4320x2160 instead of 3480x2160) which makes screen size comparisons
				// difficult to do correctly.
				// Just in case some creators have funny heights, allow for a 15% tolerance.
				var videoSizeOkay: Bool = false
				if let video = variant.meta?.video {
					videoSizeOkay = CGFloat(video.height ?? 0) <= (screenNativeBounds.height * 1.15)
					if !videoSizeOkay {
						self.logger.warning("Ignoring quality level \(String(describing: variant.name)) (\(video.width ?? 0) x \(video.height ?? 0)) due to larger-than-screen height of \(screenNativeBounds.height).")
					}
				}
				return enabled && !hidden && videoSizeOkay
			})
			
			let qualityLevelsAndUrls = filteredVariants?.compactMap({ variant -> (String, (URL, CdnDeliveryV3Variant))? in
				// Map the quality level to the correct URL
				if let url = DeliveryHelper.getBestUrl(variant: variant, group: group) {
					return (variant.name, (url, variant))
				}
				return nil
			}) ?? []
			self.qualityLevels = Dictionary(uniqueKeysWithValues: qualityLevelsAndUrls)
			
			if self.qualityLevels.isEmpty {
				self.logger.warning("No quality levels were able to be parsed from the video response. Showing an error to the user.", metadata: [
					"id": "\(self.videoAttachment.guid)",
					"qualityLevelNames": "\(group?.variants.map(\.name).joined(separator: ", ") ?? "<nil>")",
				])
				self.state = .failed(VideoError.noQualityLevelsFound)
			}
			
			self.state = .loaded((deliveryInfo, videoContent))
		}
	}
	
	private func metadataItem(identifier: AVMetadataIdentifier, value: Any) -> AVMetadataItem {
		let item = AVMutableMetadataItem()
		item.value = value as? NSCopying & NSObjectProtocol
		item.identifier = identifier
		item.extendedLanguageTag = "und" // undefined (wildcard) language
		return item
	}
	
	func createAVPlayerItem(desiredQuality: String) -> AVPlayerItem {
		self.logger.notice("Creating new AVPlayerItem for video playback.", metadata: [
			"id": "\(videoAttachment.guid)",
			"desiredQuality": "\(desiredQuality)",
		])
		var url = qualityLevels[desiredQuality]?.0
		if url == nil {
			let sortedUrls = qualityLevels
				.sorted(by: { $0.value.1.meta?.video?.height ?? 0 < $1.value.1.meta?.video?.height ?? 0 })
			// Just get the highest available. It's difficult to be smart about next highest from the selection, because the label isn't
			// sortable, so let's just guess that if a desired quality isn't available, it's because it was too high and this video
			// doesn't have it, but the user wants higher quality. It's also an Apple TV instead of a mobiel device, so higher quality
			// is expected. The expected use case is 4K is desired, but only up to 1080p is available, so default to 1080p.
			url = sortedUrls
				.last?
				.value.0
		}
		guard let url else {
			self.logger.critical("No playable URL was found for the video. Invalid state. Closing the application.")
			fatalError()
		}
		self.logger.debug("Setting up AVPlayerItem with matched content url.", metadata: [
			"url": "\(url)",
		])
		
//		let testURL = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8")!
		let asset = AVURLAsset(url: url)
		let templateItem = AVPlayerItem(asset: asset)
		templateItem.externalMetadata = avMetadataItems
		
		let queue = DispatchQueue(label: "com.wasserflug.resourceloader")
		asset.resourceLoader.setDelegate(resourceLoaderDelegate, queue: queue)
		
		NotificationCenter.default.addObserver(
			forName: .AVPlayerItemFailedToPlayToEndTime,
			object: templateItem,
			queue: .main
		) { notification in
			self.logger.debug("Notification: \(notification)")
			if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
				self.logger.debug("Playback failed: \(error)")
				self.logger.debug("Error domain: \(error as NSError).domain")
				self.logger.debug("Error code: \(error as NSError).code")
				self.logger.debug("User info: \(error as NSError).userInfo")
			}
		}

		// Also observe status changes
		templateItem.observe(\.status) { item, _ in
			switch item.status {
			case .readyToPlay:
				self.logger.debug("Player ready")
			case .failed:
				self.logger.debug("Player failed: \(String(describing: item.error))")
			case .unknown:
				self.logger.debug("Player status unknown")
			@unknown default:
				break
			}
		}

		templateItem.observe(\.error) { item, _ in
			if let error = item.error {
				self.logger.debug("Player item error: \(error)")
			}
		}
		
		return templateItem
	}
	
	func updateProgress(progressSeconds: Int, managedObjectContext: NSManagedObjectContext) {
		Task {
			guard case let .loaded((_, videoModel)) = self.state else {
				return
			}
			
			logger.notice("Attempting to record watch progress for a video.", metadata: [
				"blogPostId": "\(videoModel.primaryBlogPost)",
				"videoId": "\(videoModel.id)",
				"progressSeconds": "\(progressSeconds)",
			])
			
			// First save to local storage
			Self.updateLocalProgress(logger: logger, blogPostId: contentPost.id, videoId: videoAttachment.id, videoDuration: videoAttachment.duration, progressSeconds: progressSeconds, managedObjectContext: managedObjectContext)
			
			// Next save to FP API
			do {
				try await self.fpApiService.updateProgress(id: videoModel.id, contentType: .video, progress: progressSeconds)
			} catch {
				logger.warning("Could not update progress. Not showing an error as this is not critical.", metadata: [
					"id": "\(videoModel.id)",
					"progress": "\(progressSeconds)",
				])
			}
		}
	}
	
	static func updateLocalProgress(logger: Logger, blogPostId: String, videoId: String, videoDuration: Double, progressSeconds: Int, managedObjectContext: NSManagedObjectContext) {
		let fetchRequest = WatchProgress.fetchRequest()
		let progress: Double = Double(progressSeconds) / videoDuration
		do {
			fetchRequest.predicate = NSPredicate(format: "blogPostId = %@ and videoId = %@", blogPostId, videoId)
			if let fetchResult = (try? managedObjectContext.fetch(fetchRequest))?.first {
				logger.info("Did find previous watchProgress. Will mutate with new progress.", metadata: [
					"previous": "\(String(reflecting: fetchResult))",
				])
				fetchResult.progress = progress
			} else {
				logger.info("No previous watchProgress found. Will create new WatchProgress entity.")
				let newWatchProgress = WatchProgress(context: managedObjectContext)
				newWatchProgress.blogPostId = blogPostId
				newWatchProgress.videoId = videoId
				newWatchProgress.progress = progress
			}
			try managedObjectContext.save()
			logger.info("Successfully saved watch progress for \(blogPostId) \(videoId)")
		} catch {
			logger.error("Error saving watch progress for for \(blogPostId) \(videoId): \(String(reflecting: error))")
			// Otherwise, this has minimal impact on the user of this application.
			// No need to further handle the error.
		}
	}
}

class HLSResourceLoaderDelegate: NSObject, AVAssetResourceLoaderDelegate {
	private let logger: Logger
	private let bearerToken: String
	
	init(logger: Logger, bearerToken: String) {
		self.logger = logger
		self.bearerToken = bearerToken
		super.init()
	}
	
	func resourceLoader(
		_ resourceLoader: AVAssetResourceLoader,
		shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
	) -> Bool {
		
		guard let url = loadingRequest.request.url else {
			loadingRequest.finishLoading(with: NSError(
				domain: "HLSResourceLoader",
				code: -1,
				userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]
			))
			return false
		}
		
		logger.debug("Intercepted request for: \(url)")
		
		// Handle the actual request
		Task {
			await handleLoadingRequest(loadingRequest, url: url)
		}
		
		return true
	}
	
	private func handleLoadingRequest(
		_ loadingRequest: AVAssetResourceLoadingRequest,
		url: URL
	) async {
		do {
			// Create request with bearer token
			var request = URLRequest(url: url)
			request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
			request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
			
			let (data, response) = try await URLSession.shared.data(for: request)
			
			guard let httpResponse = response as? HTTPURLResponse else {
				throw NSError(
					domain: "HLSResourceLoader",
					code: -2,
					userInfo: [NSLocalizedDescriptionKey: "Invalid response type"]
				)
			}
			
			logger.debug("Key request status: \(httpResponse.statusCode)")
			
			guard httpResponse.statusCode == 200 else {
				throw NSError(
					domain: "HLSResourceLoader",
					code: httpResponse.statusCode,
					userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"]
				)
			}
			
			// Provide the response
			if let contentType = httpResponse.mimeType {
				loadingRequest.contentInformationRequest?.contentType = contentType
			}
			loadingRequest.contentInformationRequest?.contentLength = Int64(data.count)
			loadingRequest.contentInformationRequest?.isByteRangeAccessSupported = false
			
			// Provide the data
			loadingRequest.dataRequest?.respond(with: data)
			
			// Finish loading
			loadingRequest.finishLoading()
			
		} catch {
			logger.debug("Key request failed: \(error)")
			loadingRequest.finishLoading(with: error)
		}
	}
}
