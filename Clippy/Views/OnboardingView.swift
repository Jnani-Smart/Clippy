import SwiftUI
import AppKit

// MARK: - Data Models

struct OnboardingPage: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let features: [OnboardingFeature]
}

struct OnboardingFeature: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    @State private var contentVisible = false
    @State private var pageDirection: Int = 1
    @State private var transitioning = false
    @State private var logoScale: CGFloat = 0.6
    @State private var logoOpacity: Double = 0
    
    @Environment(\.colorScheme) private var colorScheme
    
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "",
            title: "Welcome to Clippy",
            subtitle: "Copy once, access anywhere.\nYour clipboard just got a whole lot smarter.",
            features: []
        ),
        OnboardingPage(
            icon: "doc.on.doc",
            title: "Smart Clipboard",
            subtitle: "Every text, image, and link — saved and searchable.",
            features: [
                OnboardingFeature(
                    icon: "magnifyingglass",
                    title: "Instant Search",
                    description: "Quickly find any clip by content or type"
                ),
                OnboardingFeature(
                    icon: "lock.shield",
                    title: "Private & Encrypted",
                    description: "Everything stays local on your Mac"
                ),
                OnboardingFeature(
                    icon: "photo.on.rectangle",
                    title: "Images & Code",
                    description: "Auto-detects 15+ languages and image formats"
                ),
            ]
        ),
        OnboardingPage(
            icon: "command",
            title: "Built for Speed",
            subtitle: "The right clip, exactly when you need it.",
            features: [
                OnboardingFeature(
                    icon: "pin",
                    title: "Pin Favorites",
                    description: "Star your most-used clips for one-click access"
                ),
                OnboardingFeature(
                    icon: "list.clipboard",
                    title: "Paste Queue",
                    description: "Line up multiple clips, paste them in order"
                ),
                OnboardingFeature(
                    icon: "keyboard",
                    title: "Global Shortcut",
                    description: "Press ⌘⇧V to summon Clippy from anywhere"
                ),
            ]
        ),
        OnboardingPage(
            icon: "checkmark",
            title: "You're All Set",
            subtitle: "Clippy lives in your menu bar.\nCopy something to see it in action.",
            features: []
        ),
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Content area
            ZStack {
                pageView(for: pages[currentPage])
                    .id(currentPage)
                    .transition(
                        .asymmetric(
                            insertion: .offset(x: pageDirection > 0 ? 60 : -60).combined(with: .opacity),
                            removal: .offset(x: pageDirection > 0 ? -60 : 60).combined(with: .opacity)
                        )
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            
            // Bottom bar (hidden on welcome page)
            if currentPage > 0 {
                bottomBar
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
            }
        }
        .frame(width: 420, height: 460)
        .background(backgroundView)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeOut(duration: 0.4)) {
                    contentVisible = true
                }
            }
        }
    }
    
    // MARK: - Background
    
    private var backgroundView: some View {
        ZStack {
            if #available(macOS 26.0, *) {
                Color.clear
                    .background(.ultraThinMaterial)
            } else {
                VisualEffectBackground(material: .popover, blendingMode: .behindWindow)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - Page Views
    
    @ViewBuilder
    private func pageView(for page: OnboardingPage) -> some View {
        if currentPage == 0 {
            welcomePageView(page)
        } else if currentPage == pages.count - 1 {
            finalPageView(page)
        } else {
            featurePageView(page)
        }
    }
    
    // App version string
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    // MARK: Welcome Page
    
    private func welcomePageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 0) {
            Spacer()
            
            appIconView
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
            
            Spacer().frame(height: 20)
            
            Text(page.title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .opacity(contentVisible ? 1 : 0)
                .offset(y: contentVisible ? 0 : 8)
                .animation(.easeOut(duration: 0.45).delay(0.25), value: contentVisible)
            
            Spacer().frame(height: 8)
            
            Text(page.subtitle)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(contentVisible ? 1 : 0)
                .offset(y: contentVisible ? 0 : 6)
                .animation(.easeOut(duration: 0.45).delay(0.35), value: contentVisible)
            
            Spacer().frame(height: 14)
            
            // Version badge
            versionBadge
                .opacity(contentVisible ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.45), value: contentVisible)
            
            Spacer()
            
            // Page dots
            HStack(spacing: 6) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? Color.primary : Color.primary.opacity(0.2))
                        .frame(width: 6, height: 6)
                        .scaleEffect(index == currentPage ? 1.0 : 0.85)
                        .animation(.easeInOut(duration: 0.25), value: currentPage)
                }
            }
            .opacity(contentVisible ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.5), value: contentVisible)
            
            Spacer().frame(height: 20)
            
            // Continue button centered
            Button(action: goToNextPage) {
                Text("Continue")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 9)
                    .modifier(GlassContinueButtonModifier())
            }
            .buttonStyle(.plain)
            .opacity(contentVisible ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.55), value: contentVisible)
            
            Spacer().frame(height: 32)
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: Version Badge
    
    private var versionBadge: some View {
        Group {
            if #available(macOS 26.0, *) {
                Text("v\(appVersion)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .glassEffect(.regular, in: .capsule)
            } else {
                Text("v\(appVersion)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
                    )
            }
        }
    }
    
    // MARK: Feature Page
    
    private func featurePageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 48)
            
            featurePageIcon(page.icon)
                .opacity(contentVisible ? 1 : 0)
                .scaleEffect(contentVisible ? 1 : 0.8)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: contentVisible)
            
            Spacer().frame(height: 18)
            
            Text(page.title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .opacity(contentVisible ? 1 : 0)
                .offset(y: contentVisible ? 0 : 6)
                .animation(.easeOut(duration: 0.4).delay(0.1), value: contentVisible)
            
            Spacer().frame(height: 4)
            
            Text(page.subtitle)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.secondary)
                .opacity(contentVisible ? 1 : 0)
                .offset(y: contentVisible ? 0 : 4)
                .animation(.easeOut(duration: 0.4).delay(0.15), value: contentVisible)
            
            Spacer().frame(height: 28)
            
            VStack(spacing: 0) {
                ForEach(Array(page.features.enumerated()), id: \.element.id) { index, feature in
                    featureRow(feature)
                        .opacity(contentVisible ? 1 : 0)
                        .offset(y: contentVisible ? 0 : 12)
                        .animation(
                            .easeOut(duration: 0.4).delay(0.2 + Double(index) * 0.08),
                            value: contentVisible
                        )
                    
                    if index < page.features.count - 1 {
                        Divider()
                            .padding(.leading, 52)
                            .opacity(0.5)
                    }
                }
            }
            .padding(.vertical, 4)
            .modifier(GlassFeatureCardModifier(colorScheme: colorScheme))
            .padding(.horizontal, 24)
            
            Spacer()
        }
    }
    
    // MARK: Feature Row
    
    private func featureRow(_ feature: OnboardingFeature) -> some View {
        HStack(spacing: 14) {
            Image(systemName: feature.icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 28, height: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(feature.description)
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
    
    // MARK: Final Page
    
    private func finalPageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 0) {
            Spacer()
            
            finalPageCheckmark
                .opacity(contentVisible ? 1 : 0)
                .scaleEffect(contentVisible ? 1 : 0.7)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.05), value: contentVisible)
            
            Spacer().frame(height: 24)
            
            Text(page.title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .opacity(contentVisible ? 1 : 0)
                .offset(y: contentVisible ? 0 : 8)
                .animation(.easeOut(duration: 0.45).delay(0.15), value: contentVisible)
            
            Spacer().frame(height: 10)
            
            Text(page.subtitle)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .opacity(contentVisible ? 1 : 0)
                .offset(y: contentVisible ? 0 : 6)
                .animation(.easeOut(duration: 0.45).delay(0.25), value: contentVisible)
            
            Spacer().frame(height: 24)
            
            menuBarHint
                .opacity(contentVisible ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.4), value: contentVisible)
            
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - App Icon
    
    private var appIconView: some View {
        Group {
            if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
               let iconImage = NSImage(contentsOf: iconURL) {
                Image(nsImage: iconImage)
                    .resizable()
            } else {
                Image(nsImage: NSImage(named: "AppIcon") ?? NSImage(named: NSImage.applicationIconName)!)
                    .resizable()
            }
        }
        .aspectRatio(contentMode: .fit)
        .frame(width: 88, height: 88)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
    
    // MARK: - Bottom Bar
    
    private var bottomBar: some View {
        HStack {
            if currentPage > 0 {
                Button(action: goToPreviousPage) {
                    Text("Back")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 40)
            }
            
            Spacer()
            
            HStack(spacing: 6) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? Color.primary : Color.primary.opacity(0.2))
                        .frame(width: 6, height: 6)
                        .scaleEffect(index == currentPage ? 1.0 : 0.85)
                        .animation(.easeInOut(duration: 0.25), value: currentPage)
                }
            }
            
            Spacer()
            
            Button(action: {
                if currentPage == pages.count - 1 {
                    completeOnboarding()
                } else {
                    goToNextPage()
                }
            }) {
                Text(currentPage == pages.count - 1 ? "Get Started" : "Continue")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 7)
                    .modifier(GlassContinueButtonModifier())
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Glass Helper Views
    
    @ViewBuilder
    private func featurePageIcon(_ iconName: String) -> some View {
        if #available(macOS 26.0, *) {
            Image(systemName: iconName)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 48, height: 48)
                .glassEffect(.regular, in: .circle)
        } else {
            Image(systemName: iconName)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                )
        }
    }
    
    private var finalPageCheckmark: some View {
        Group {
            if #available(macOS 26.0, *) {
                Image(systemName: "checkmark")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .frame(width: 64, height: 64)
                    .glassEffect(.regular, in: .circle)
            } else {
                Image(systemName: "checkmark")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .frame(width: 64, height: 64)
                    .background(
                        Circle()
                            .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.12 : 0.1))
                    )
            }
        }
    }
    
    private var menuBarHint: some View {
        Group {
            if #available(macOS 26.0, *) {
                HStack(spacing: 8) {
                    Image(systemName: "menubar.arrow.up.rectangle")
                        .font(.system(size: 13, weight: .medium))
                    Text("Look for the clipboard icon in your menu bar")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.tertiaryLabel)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .glassEffect(.regular, in: .capsule)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "menubar.arrow.up.rectangle")
                        .font(.system(size: 13, weight: .medium))
                    Text("Look for the clipboard icon in your menu bar")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.tertiaryLabel)
            }
        }
    }
    
    // MARK: - Navigation
    
    private func goToNextPage() {
        guard !transitioning, currentPage < pages.count - 1 else { return }
        transitioning = true
        pageDirection = 1
        
        withAnimation(.easeOut(duration: 0.15)) {
            contentVisible = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeInOut(duration: 0.35)) {
                currentPage += 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.4)) {
                    contentVisible = true
                }
                transitioning = false
            }
        }
    }
    
    private func goToPreviousPage() {
        guard !transitioning, currentPage > 0 else { return }
        transitioning = true
        pageDirection = -1
        
        withAnimation(.easeOut(duration: 0.15)) {
            contentVisible = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeInOut(duration: 0.35)) {
                currentPage -= 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.4)) {
                    contentVisible = true
                }
                transitioning = false
            }
        }
    }
    
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        FirstLaunchManager.shared.markAsLaunched()
        
        withAnimation(.easeIn(duration: 0.25)) {
            isPresented = false
        }
    }
}

// MARK: - Glass Modifiers

struct GlassFeatureCardModifier: ViewModifier {
    let colorScheme: ColorScheme
    
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.025))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06),
                            lineWidth: 0.5
                        )
                )
        }
    }
}

struct GlassContinueButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .background(Capsule().fill(Color.accentColor))
                .glassEffect(.regular.interactive(), in: .capsule)
        } else {
            content
                .background(Capsule().fill(Color.accentColor))
        }
    }
}

// MARK: - Visual Effect Background (pre-macOS 26)

struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Color Extension

extension Color {
    static var tertiaryLabel: Color {
        Color(nsColor: .tertiaryLabelColor)
    }
}

// MARK: - Onboarding Window Controller

class OnboardingWindowController: NSObject {
    static let shared = OnboardingWindowController()
    private var onboardingWindow: NSPanel?
    
    func showOnboarding() {
        guard onboardingWindow == nil else {
            onboardingWindow?.makeKeyAndOrderFront(nil)
            return
        }
        
        let onboardingView = OnboardingView(isPresented: Binding(
            get: { [weak self] in self?.onboardingWindow != nil },
            set: { [weak self] newValue in
                if !newValue {
                    self?.dismissOnboarding()
                }
            }
        ))
        
        let hostingView = NSHostingView(rootView: onboardingView)
        
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 460),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.contentView = hostingView
        panel.isMovableByWindowBackground = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .floating
        panel.center()
        
        // Hide traffic light buttons
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = 16
        panel.contentView?.layer?.masksToBounds = true
        
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
        
        onboardingWindow = panel
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose),
            name: NSWindow.willCloseNotification,
            object: panel
        )
    }
    
    @objc private func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === onboardingWindow {
            onboardingWindow = nil
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            FirstLaunchManager.shared.markAsLaunched()
        }
    }
    
    func dismissOnboarding() {
        guard let window = onboardingWindow else { return }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            window.close()
            self?.onboardingWindow = nil
            // Notify the app to show the clipboard window now
            NotificationCenter.default.post(name: NSNotification.Name("OnboardingDidComplete"), object: nil)
        })
    }
}
