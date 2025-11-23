import SwiftUI
import CoreData
import GameController
import FloatplaneAPIClient
import DebouncedOnChange

struct RootTabView2: View {
	
	enum SideBarState: Equatable, CaseIterable {
		case collapsed
		case expanded
	}
	
	enum TabSelection: Hashable {
		case home
		case creator(String)
		case channel(String)
		case settings
		
		var isCreator: Bool {
			switch self {
			case .creator: return true
			default: return false
			}
		}
	}
	
	enum ScrollViewPosition: Hashable {
		case beginning
		case middle
		case end
	}
	
	@EnvironmentObject var userInfo: UserInfo
	@Environment(\.fpApiService) var fpApiService
	@Environment(\.managedObjectContext) var managedObjectContext
	@Environment(\.scenePhase) var scenePhase
	
	@State var fpFrontendSocket: FPFrontendSocket
	let fixedWidth: CGFloat = 150
	let maxExpandedButtonWidth: CGFloat = 400
	@State var tabSelection: TabSelection = .home
	@State var state: SideBarState = .expanded
	@State var scrollViewFrameHeight = 1000.0
	@State var scrollViewPosition = ScrollViewPosition.beginning
	
	@FocusState var menuIsFocused: Bool
	@FocusState var contentIsFocused: Bool
	@Namespace var menuFocusNamespace
	@Namespace var contentFocusNamespace
	@Namespace var menuButtonItemsNamespace
	@FocusState var focusedItem: TabSelection?
	
	var body: some View {
		HStack(spacing: 0) {
			sideBarView
				.accessibilityElement(children: .contain)
				.accessibilityLabel("Navigation sidebar")
			contentView
				.accessibilityElement(children: .contain)
				.accessibilityLabel("Main content")
				.overlay {
					if state == .expanded {
						Rectangle()
							.fill(Color.black.opacity(0.2))
					}
				}
		}
		.ignoresSafeArea()
		.onFirstAppear {
			menuIsFocused = true
		}
		.onChange(of: tabSelection) { tabSelection in
			switch tabSelection {
			case .home:
				UIAccessibility.post(notification: .announcement, argument: "Switched to home screen")
			case let .creator(creatorId):
				if let creator = self.userInfo.creators[creatorId] {
					UIAccessibility.post(notification: .announcement, argument: "Switched to creator \(creator.title)")
				}
			case let .channel(channelId):
				if let channel = self.userInfo.creators.values.flatMap(\.channels).first(where: { $0.id == channelId }) {
					UIAccessibility.post(notification: .announcement, argument: "Switched to channel \(channel.title)")
				}
			case .settings:
				UIAccessibility.post(notification: .announcement, argument: "Switched to settings screen")
			}
		}
		.fpSocketControlSocket(fpFrontendSocket, on: [.onAppear, .onSceneActive, .onSceneBackground])
	}
	
	var contentView: some View {
		contentBody
			.frame(maxWidth: .infinity)
			.focusSection()
			.focusScope(contentFocusNamespace)
			.focused($contentIsFocused)
			.onExitCommand(perform: {
				print("contentView onExitCommand")
				if state == .collapsed {
					print("contentView onExitCommand setMenuIsFocused = true")
					withAnimation(.interactiveSpring) {
						menuIsFocused = true
					}
				}
			})
	}
	
	var contentBody: some View {
		ZStack {
			HomeView(viewModel: HomeViewModel(userInfo: userInfo, fpApiService: fpApiService, managedObjectContext: managedObjectContext))
				.customAppear(tabSelection == .home ? .appear : .disappear)
				.opacity(tabSelection == .home ? 1 : 0)
				.accessibilityHidden(tabSelection == .home ? false : true)
				.disabled(tabSelection == .home ? false : true)

			ForEach(userInfo.creatorsInOrder, id: \.id) { creator in
				CreatorContentView(viewModel: CreatorContentViewModel(fpApiService: fpApiService,
																	  managedObjectContext: managedObjectContext,
																	  creatorOrChannel: creator,
																	  livestream: creator.liveStream))
					.customAppear(tabSelection == .creator(creator.id) ? .appear : .disappear)
					.opacity(tabSelection == .creator(creator.id) ? 1 : 0)
					.accessibilityHidden(tabSelection == .creator(creator.id) ? false : true)
					.disabled(tabSelection == .creator(creator.id) ? false : true)
				
				ForEach(creator.channels, id: \.id) { channel in
					CreatorContentView(viewModel: CreatorContentViewModel(fpApiService: fpApiService,
																		  managedObjectContext: managedObjectContext,
																		  creatorOrChannel: channel,
																		  livestream: creator.liveStream))
						.customAppear(tabSelection == .channel(channel.id) ? .appear : .disappear)
						.opacity(tabSelection == .channel(channel.id) ? 1 : 0)
						.accessibilityHidden(tabSelection == .channel(channel.id) ? false : true)
						.disabled(tabSelection == .channel(channel.id) ? false : true)
				}
			}

			SettingsView()
				.customAppear(tabSelection == .settings ? .appear : .disappear)
				.opacity(tabSelection == .settings ? 1 : 0)
				.accessibilityHidden(tabSelection == .settings ? false : true)
				.disabled(tabSelection == .settings ? false : true)
		}
	}
	
	var sideBarView: some View {
		sideBar
			// These deal with focus management and focus transitions
			.focusSection()
			.focusScope(menuFocusNamespace)
			.focused($menuIsFocused)
			.onChange(of: menuIsFocused, perform: { menuIsFocused in
				if menuIsFocused {
					withAnimation(.interactiveSpring) {
						state = .expanded
					}
					withAnimation(nil) {
						focusedItem = tabSelection
					}
				} else {
					withAnimation(.interactiveSpring) {
						state = .collapsed
					}
				}
			})
	}
	
	var sideBar: some View {
		let showMenu = state == .expanded
		return VStack(spacing: 0) {
			VStack {
				Button(action: {
					withAnimation(.interactiveSpring) {
						tabSelection = .home
					}
				}, label: {
					HStack(spacing: 0) {
						if showMenu {
							Spacer(minLength: 0)
						}
						Image("wasserflug-logo")
							.resizable()
							.renderingMode(.template)
							.scaledToFit()
							.frame(width: 120)
						if showMenu {
							Text("Home")
								.font(Font.headline)
								.lineLimit(1)
								.fixedSize()
								.padding([.leading])
							Spacer(minLength: 0)
						}
					}
					.padding()
				})
				.buttonStyle(MatchedButtonStyle(namespace: menuButtonItemsNamespace))
				.frame(maxWidth: showMenu ? maxExpandedButtonWidth : nil)
				.focused($focusedItem, equals: TabSelection.home)
				.prefersDefaultFocus(in: menuFocusNamespace)
				.accessibilityLabel("Home view")
				.accessibilityHint("Go to the home screen to view all subscription content")
			}
			.padding(.vertical, 30)
			.padding(.horizontal, showMenu ? 50 : 0)
			
			ScrollViewReader { proxy in
				ScrollView {
					VStack {
						ForEach(userInfo.creatorsInOrder, id: \.id) { creator in
							button(forCreator: creator)
								.id(TabSelection.creator(creator.id))
								.focused($focusedItem, equals: TabSelection.creator(creator.id))
								.onChange(of: focusedItem, debounceTime: .seconds(0.5), perform: { focusedItem in
									if focusedItem == .creator(creator.id) {
										proxy.scrollTo(focusedItem)
									}
								})
							
							ForEach(creator.channels, id: \.id) { channel in
								button(forChannel: channel, creator: creator)
									.id(TabSelection.channel(channel.id))
									.focused($focusedItem, equals: TabSelection.channel(channel.id))
									.onChange(of: focusedItem, debounceTime: .seconds(0.5), perform: { focusedItem in
										if focusedItem == .channel(channel.id) {
											proxy.scrollTo(focusedItem)
										}
									})
							}
						}
					}
					.background(GeometryReader {
						let scrollDistance = -$0.frame(in: .named("scroll")).origin.y
						let scrollContentHeight = $0.frame(in: .named("scroll")).size.height
						let position: ScrollViewPosition = scrollDistance <= 0.0 ? .beginning : scrollDistance >= scrollContentHeight - scrollViewFrameHeight ? .end : .middle
						if position != self.scrollViewPosition {
							let _ = Task { @MainActor in
								self.scrollViewPosition = position
							}
						}
					})
					.padding(.vertical, 30)
					.padding(.horizontal, showMenu ? 50 : 15)
				}
				.coordinateSpace(name: "scroll")
				.background(GeometryReader { geoProxy in
					let scrollViewFrameHeight = geoProxy.size.height
					if self.scrollViewFrameHeight != scrollViewFrameHeight {
						let _ = Task { @MainActor in
							self.scrollViewFrameHeight = scrollViewFrameHeight
						}
					}
					EmptyView()
				})
				.innerShadow(color: .black, radius: 30, edges: !showMenu ? [] : scrollViewPosition == .beginning ? .bottom : scrollViewPosition == .end ? .top : [.top, .bottom])
			}
			
			VStack {
				Button(action: {
					withAnimation(.interactiveSpring) {
						tabSelection = .settings
					}
				}, label: {
					HStack(spacing: 0) {
						if showMenu {
							Spacer(minLength: 0)
						}
						Image(systemName: "gear")
						if showMenu {
							Text("Settings")
								.lineLimit(1)
								.fixedSize()
								.padding([.leading])
							Spacer(minLength: 0)
						}
					}
					.padding()
				})
				.buttonStyle(MatchedButtonStyle(namespace: menuButtonItemsNamespace))
				.frame(maxWidth: showMenu ? maxExpandedButtonWidth : nil)
				.animation(.interactiveSpring, value: showMenu)
				.focused($focusedItem, equals: TabSelection.settings)
				.padding([.bottom], 20)
				.accessibilityLabel("Wasserflug Settings")
				.accessibilityHint("Go to the settings page")
			}
			.padding(.vertical, 30)
			.padding(.horizontal, showMenu ? 50 : 0)
		}
//		.frame(maxWidth: showMenu ? maxExpandedButtonWidth : nil)
		.background(FPColors.sidebarBlue)
		.environment(\.colorScheme, .dark)
	}
	
	func button(forCreator creator: CreatorModelV3) -> some View {
		let showMenu = state == .expanded
		let imageSize: CGFloat = 75
		let indent: CGFloat = 0
		let isSelected = tabSelection == .creator(creator.id)
		return Button(action: {
			withAnimation(.interactiveSpring) {
				tabSelection = .creator(creator.id)
			}
		}, label: {
			HStack(spacing: 0) {
				AsyncImage(url: (creator.icon as ImageModelShared?).bestImage(for: CGSize(width: imageSize, height: imageSize))) { image in
					image.resizable()
				} placeholder: {
					ProgressView()
				}
				.frame(width: imageSize, height: imageSize)
				.cornerRadius(imageSize)
				.padding([.leading], indent)
				if showMenu {
					Text(creator.title)
						.lineLimit(1)
						.fixedSize()
						.padding([.leading])
					Spacer(minLength: 0)
					if !creator.channels.isEmpty {
						Image(systemName: "chevron.down")
					}
				}
			}
			.padding(15)
			.background(isSelected ? VisualEffectView(effect: UIBlurEffect(style: .light)).cornerRadius(12) : nil)
			.animation(.interactiveSpring, value: showMenu)
			.accessibilityElement(children: .ignore)
			.accessibilityLabel("Creator \(creator.title)")
		})
		.buttonStyle(MatchedButtonStyle(namespace: menuButtonItemsNamespace))
		.frame(maxWidth: showMenu ? maxExpandedButtonWidth : nil)
	}
	
	func button(forChannel channel: ChannelModel, creator: CreatorModelV3) -> some View {
		let showMenu = state == .expanded
		let imageSize: CGFloat = 50
		let indent: CGFloat = showMenu ? 40 : 0
		let isSelected = tabSelection == .channel(channel.id)
		return Button(action: {
			withAnimation(.interactiveSpring) {
				tabSelection = .channel(channel.id)
			}
		}, label: {
			HStack(spacing: 0) {
				AsyncImage(url: (channel.icon as ImageModelShared?).bestImage(for: CGSize(width: imageSize, height: imageSize))) { image in
					image.resizable()
				} placeholder: {
					ProgressView()
				}
				.frame(width: imageSize, height: imageSize)
				.cornerRadius(imageSize)
				.padding([.leading], indent)
				if showMenu {
					Text(channel.title)
						.lineLimit(1)
						.fixedSize()
						.padding([.leading])
					Spacer(minLength: 0)
				}
			}
			.padding(15)
			.background(isSelected ? VisualEffectView(effect: UIBlurEffect(style: .light)).cornerRadius(12) : nil)
			.animation(.interactiveSpring, value: showMenu)
			.accessibilityElement(children: .ignore)
			.accessibilityLabel("Channel \(channel.title)")
		})
		.buttonStyle(MatchedButtonStyle(namespace: menuButtonItemsNamespace))
		.frame(maxWidth: showMenu ? maxExpandedButtonWidth : nil)
	}
}

struct RootTabView2_Previews: PreviewProvider {
	static var previews: some View {
		RootTabView2(fpFrontendSocket: MockFPFrontendSocket(sailsSid: ""), state: .expanded)
			.environmentObject(MockData.userInfo)
			.environment(\.fpApiService, MockFPAPIService())
			.previewDisplayName("Expanded")
		
		RootTabView2(fpFrontendSocket: MockFPFrontendSocket(sailsSid: ""), tabSelection: .channel(MockData.creatorV3.id), state: .collapsed)
			.environmentObject(MockData.userInfo)
			.environment(\.fpApiService, MockFPAPIService())
			.previewDisplayName("Collapsed")
	}
}

struct MatchedButtonStyle: ButtonStyle {
	
	private static let matchedId = "MatchedButtonStyle"
	
	let namespace: Namespace.ID
	@Environment(\.isFocused) private var isFocused: Bool
	@Environment(\.colorScheme) private var colorScheme: ColorScheme
	
	@ViewBuilder func makeBody(configuration: Self.Configuration) -> some View {
		configuration.label
			.foregroundStyle(isFocused ? .black : colorScheme == .dark ? .white : .black)
//			.padding(.horizontal, 40)
//			.padding(.vertical, 12)
			.scaleEffect(isFocused && !configuration.isPressed ? 1.15 : 1.0)
			.background(content: {
				if isFocused {
					RoundedRectangle(cornerRadius: 12)
						.fill(.white)
						.shadow(radius: configuration.isPressed ? 10 : 15, y: configuration.isPressed ? 10 : 25)
						.scaleEffect(configuration.isPressed ? 1.0 : 1.15)
						.matchedGeometryEffect(id: Self.matchedId, in: namespace)
				}
			})
			.animation(.interactiveSpring.speed(0.5), value: isFocused)
			.animation(.interactiveSpring, value: configuration.isPressed)
	}
}
