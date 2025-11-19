import Foundation
import CoreGraphics
import SwiftUI
import FloatplaneAPIClient

extension ErrorModel: LocalizedError {
	public var errorDescription: String? {
		let message = self.message ?? self.errors.first?.message ?? self.errors.first?.name ?? "Error message unretrievable."
		let separator: String
		if message.last != "." {
			separator = ". "
		} else {
			separator = " "
		}
		return message + separator + "Error ID: " + self.id
	}
	
	public var failureReason: String? {
		nil
	}

	public var recoverySuggestion: String? {
		nil
	}

	public var helpAnchor: String? {
		nil
	}
}

extension VideoAttachmentModel: Identifiable { }

extension PictureAttachmentModel: Identifiable { }

extension AudioAttachmentModel: Identifiable { }

extension BlogPostModelV3: Identifiable { }

extension UserSubscriptionModel: Identifiable {
	public var id: String {
		self.creator
	}
}

protocol ImageModelShared {
	var width: Int { get set }
	var height: Int { get set }
	var path: String { get set }
	var childImages: [ChildImageModel]? { get set }
}

extension ImageModelShared {
	var aspectRatio: CGFloat {
		return CGFloat(self.width) / CGFloat(self.height)
	}
	
	func bestImage(for geometrySize: CGSize?) -> URL? {
		guard let geometrySize else {
			return nil
		}
		
		let geometryMagnitude = Int(geometrySize.width * geometrySize.height)
		var difference = (self.width * self.height) - geometryMagnitude
		var path = self.path
		
		for childImage in self.childImages ?? [] {
			let childDifference = (childImage.width * childImage.height) - geometryMagnitude
			
			if childDifference >= 0 && childDifference < difference {
				difference = childDifference
				path = childImage.path
			}
		}
		
		return URL(string: path)
	}
}

extension ImageModel: ImageModelShared {
}

extension Optional where Wrapped == ImageModelShared {
	var pathUrlOrNil: URL? {
		if let thumbnail = self {
			return URL(string: thumbnail.path)
		} else {
			return nil
		}
	}
	
	func bestImage(for geometrySize: CGSize?) -> URL? {
		if let thumbnail = self {
			return thumbnail.bestImage(for: geometrySize)
		} else {
			return nil
		}
	}
}

extension BlogPostModelV3Channel {
	var asChannelModel: ChannelModel? {
		switch self {
		case let .typeChannelModel(channelModel):
			return channelModel
		default:
			return nil
		}
	}
}

extension BlogPostModelV3 {
	var firstVideoAttachmentId: String? {
		return self.attachmentOrder.filter({ self.videoAttachments?.contains($0) == true }).first
	}
}

extension ContentPostV3Response {
	var firstVideoAttachmentId: String? {
		return self.attachmentOrder.filter({ self.videoAttachments?.lazy.map(\.id).contains($0) == true }).first
	}

	var firstVideoAttachment: VideoAttachmentModel? {
		return self.videoAttachments?.first(where: { $0.id == firstVideoAttachmentId })
	}
}
