import Foundation
import SwiftUI
import AVKit
import Combine
import CoreData
import FloatplaneAPIClient
import Logging

struct VideoPlayerView: UIViewControllerRepresentable {
	@AppStorage("DesiredQuality") var desiredQuality: String = ""
	@Environment(\.managedObjectContext) var managedObjectContext
	@ObservedObject var viewModel: VideoViewModel
	let beginningWatchTime: Double
	
	let logger: Logger = {
		var logger = Wasserflug_tvOSApp.logger
		logger[metadataKey: "class"] = "\(Self.Type.self)"
		return logger
	}()
	
	func makeCoordinator() -> Coordinator {
		return Coordinator(self)
	}
	
	func makeUIViewController(context: Context) -> AVPlayerViewController {
		logger.debug("Creating AVPlayerViewController instance for playback.", metadata: [
			"videoId": "\(viewModel.videoAttachment.id)",
		])
		
		let vc = AVPlayerViewController()
		vc.delegate = context.coordinator
		vc.speeds = viewModel.supportedSpeeds
		vc.view.layoutIfNeeded() // This is needed or the OOTB speed controls don't display until you show the video for the second time
		vc.transportBarCustomMenuItems = [createQualityAction()]
		let playerItem = viewModel.createAVPlayerItem(desiredQuality: desiredQuality)
		
		if beginningWatchTime > 0.0 && beginningWatchTime < 1.0 {
			let totalSeconds = viewModel.videoAttachment.duration
			let percentageOfTotal = beginningWatchTime
			let seekToSeconds = totalSeconds * percentageOfTotal
			let newCMTime = CMTime(seconds: seekToSeconds, preferredTimescale: 1)
			playerItem.seek(to: newCMTime, completionHandler: nil)
		}
		
		vc.player = AVPlayer(playerItem: playerItem)
		vc.player?.play() // Needs to play when it first appears.
		return vc
	}

	func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
		
		updateAVPlayerItem(uiViewController: uiViewController)
		
		if let qualityMenu = uiViewController.transportBarCustomMenuItems.first(where: { $0.title == "Resolution" }) as? UIMenu {
			if let qualitySubMenu = qualityMenu.children.first(where: { $0.title == "Resolution" }) as? UIMenu {
				logger.debug("Resetting resolution picker to last user-selected resolution of \(self.desiredQuality).")
				for case let option as UIAction in qualitySubMenu.children {
					option.state = .off
					if option.identifier == UIAction.Identifier(desiredQuality) {
						option.state = .on
					}
				}
			}
		}
	}
	
	private func updateAVPlayerItem(uiViewController: AVPlayerViewController) {
		if let player = uiViewController.player {
			let newPlayerItem = viewModel.createAVPlayerItem(desiredQuality: desiredQuality)
			let lastPlayerItem = player.currentItem
			
			// Only perform an update to the player item if the URL changes. This
			// could cause a stutter in video playback as it needlessly loads something.
			guard (lastPlayerItem?.asset as? AVURLAsset)?.url != (newPlayerItem.asset as? AVURLAsset)?.url else {
				return
			}
			
			logger.notice("Updating the AVPlayerViewController's AVPlayerItem with the latest video URL and quality.")
			
			if let lastPlayerItem {
				let time = lastPlayerItem.currentTime()
				logger.notice("User was in the middle of the video before this update. Seeking to the previous timestamp of \(time.seconds).")
				newPlayerItem.seek(to: time, completionHandler: nil)
			}
			
			player.replaceCurrentItem(with: newPlayerItem)
			player.play()
		} else {
			logger.warning("While updating AVPlayerViewController, no AVPlayer was found. Skipping the update of the AVPlayerItem.")
		}
	}
	
	static func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator: Self.Coordinator) {
		Wasserflug_tvOSApp.logger.notice("Dismantling AVPlayerViewController.")
		if let player = uiViewController.player {
			Wasserflug_tvOSApp.logger.notice("Pausing AVPlayerViewController's AVPlayer before dismantling.")
			player.pause()
			uiViewController.delegate?.playerViewControllerDidEndDismissalTransition?(uiViewController)
		}
	}
	
	func createQualityAction() -> UIMenu {
		let sparkleTvImage = UIImage(systemName: "sparkles.tv")
		let resolutions: [UIAction] = viewModel.qualityLevels.values
			.sorted(by: { $0.1.order ?? 0 < $1.1.order ?? 0 })
			.reversed() // This keeps the higher quality on top of the menu
			.map({ qualityLevel -> UIAction in
				return UIAction(title: qualityLevel.1.label, identifier: UIAction.Identifier(qualityLevel.1.name), handler: { _ in
					UserDefaults.standard.set(qualityLevel.1.name, forKey: "DesiredQuality")
				})
			})
		let submenu = UIMenu(title: "Resolution", options: [.displayInline, .singleSelection], children: resolutions)
		let menu = UIMenu(title: "Resolution", image: sparkleTvImage, children: [submenu])
		return menu
	}
	
	class Coordinator: NSObject, AVPlayerViewControllerDelegate {
		let parent: VideoPlayerView
		
		init(_ parent: VideoPlayerView) {
			self.parent = parent
		}
		
		func playerViewControllerDidEndDismissalTransition(_ playerViewController: AVPlayerViewController) {
			let progressSeconds: Int
			if let player = playerViewController.player, let lastPlayerItem = player.currentItem {
				progressSeconds = Int(lastPlayerItem.currentTime().seconds)
			} else {
				progressSeconds = 0
			}
			
			parent.viewModel.updateProgress(progressSeconds: progressSeconds, managedObjectContext: parent.managedObjectContext)
		}
	}
}
