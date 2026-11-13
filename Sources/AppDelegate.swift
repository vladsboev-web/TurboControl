import Cocoa
import SwiftUI
import Combine
import QuartzCore

private final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: FloatingPanel!
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    private var cancellables = Set<AnyCancellable>()
    private var isPanelOpen = false
    
    private lazy var leafIcon: NSImage? = {
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        let img = NSImage(systemSymbolName: "leaf.fill", accessibilityDescription: "TurboControl")?.withSymbolConfiguration(config)
        img?.isTemplate = true
        return img
    }()
    
    private lazy var boltIcon: NSImage? = {
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        let img = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "TurboControl")?.withSymbolConfiguration(config)
        img?.isTemplate = true
        return img
    }()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if !SystemCapabilities.isIntelMac {
            let alert = NSAlert()
            alert.messageText = L10n.appleSiliconAlertTitle
            alert.informativeText = L10n.appleSiliconAlertMessage
            alert.alertStyle = .informational
            alert.addButton(withTitle: L10n.continueMonitorOnlyBtn)
            alert.addButton(withTitle: L10n.quit)
            NSApp.activate(ignoringOtherApps: true)
            if alert.runModal() == .alertSecondButtonReturn {
                NSApplication.shared.terminate(nil)
                return
            }
        }
        
        // Setup floating panel (immune to fullscreen menu bar auto-hide clipping)
        let panelWidth: CGFloat = 360
        let panelHeight: CGFloat = 504
        let panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovable = false
        
        let hostingView = NSHostingView(rootView: MainPopoverView())
        hostingView.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 16
        hostingView.layer?.masksToBounds = true
        panel.contentView = hostingView
        self.panel = panel
        applyPanelAppearance()
        
        // Setup status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.action = #selector(handleStatusItemClick(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            updateStatusItemDisplay()
        }
        
        // Setup event monitors for outside clicks and Escape key
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.isPanelOpen else { return }
            self.closePopover(sender: event)
        }
        
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self, self.isPanelOpen else { return event }
            if event.keyCode == 53 { // Escape
                self.closePopover(sender: nil)
                return nil
            }
            return event
        }
        
        NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification, object: panel)
            .sink { [weak self] _ in
                guard let self = self, self.isPanelOpen else { return }
                if let buttonWindow = self.statusItem.button?.window,
                   let event = NSApp.currentEvent,
                   event.window == buttonWindow,
                   (event.type == .leftMouseDown || event.type == .leftMouseUp) {
                    return
                }
                self.closePopover(sender: nil)
            }
            .store(in: &cancellables)
        
        // Listen for metric updates, settings changes & turbo state changes
        NotificationCenter.default.publisher(for: .metricsDidUpdate)
            .sink { [weak self] _ in
                self?.updateStatusItemDisplay()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .menuBarDisplayChanged)
            .sink { [weak self] _ in
                self?.updateStatusItemDisplay()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .appThemeChanged)
            .sink { [weak self] _ in
                self?.applyPanelAppearance()
            }
            .store(in: &cancellables)
        
        // Initialize automation and restore Turbo Boost state only on Intel Macs
        if SystemCapabilities.isIntelMac {
            _ = AutomationService.shared
            
            TurboBoostService.shared.$isTurboDisabled
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    self?.updateStatusItemDisplay()
                }
                .store(in: &cancellables)
            
            if AppSettings.shared.restoreLastTurboState && UserDefaults.standard.object(forKey: AppSettings.Keys.userChosenTurboDisabled) != nil {
                let savedChoice = AppSettings.shared.userChosenTurboDisabled
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    TurboBoostService.shared.setTurboDisabled(savedChoice, isUserInitiated: false)
                }
            }
        }
        
        // Apply fan mode on startup
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            FanControlService.shared.applyCurrentMode()
        }
    }
    
    private func updateStatusItemDisplay() {
        guard let button = statusItem.button else { return }
        
        let turbo = TurboBoostService.shared
        let monitor = SystemMonitor.shared
        let settings = AppSettings.shared
        
        let targetImage = turbo.isTurboDisabled ? leafIcon : boltIcon
        if button.image !== targetImage {
            button.image = targetImage
            button.imagePosition = .imageLeft
        }
        
        let newTitle: String
        if settings.showTempInMenuBar && monitor.cpuTemp > 0 {
            newTitle = String(format: " %.0f°C", monitor.cpuTemp)
        } else {
            newTitle = ""
        }
        if button.title != newTitle {
            button.title = newTitle
        }
    }
    
    @objc func handleStatusItemClick(_ sender: AnyObject?) {
        guard let event = NSApp.currentEvent else {
            togglePopover(sender)
            return
        }
        
        if event.type == .rightMouseUp || (event.type == .leftMouseUp && event.modifierFlags.contains(.control)) {
            if isPanelOpen {
                closePopover(sender: sender)
            }
            showContextMenu()
        } else {
            togglePopover(sender)
        }
    }
    
    private func showContextMenu() {
        let menu = NSMenu()
        
        if SystemCapabilities.isIntelMac {
            let turbo = TurboBoostService.shared
            let isOff = turbo.isTurboDisabled
            
            let statusTitle = isOff ? L10n.menuTurboStatusDisabled : L10n.menuTurboStatusEnabled
            let statusItemMenu = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
            statusItemMenu.isEnabled = false
            menu.addItem(statusItemMenu)
            
            menu.addItem(NSMenuItem.separator())
            
            let toggleTitle = isOff ? L10n.menuEnableTurbo : L10n.menuDisableTurbo
            let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleTurboFromMenu), keyEquivalent: "")
            toggleItem.target = self
            toggleItem.isEnabled = !turbo.isWorking
            if let icon = NSImage(systemSymbolName: isOff ? "bolt.fill" : "leaf.fill", accessibilityDescription: nil) {
                icon.isTemplate = true
                toggleItem.image = icon
            }
            menu.addItem(toggleItem)
        } else {
            let statusItemMenu = NSMenuItem(title: L10n.menuMonitorOnlyStatus, action: nil, keyEquivalent: "")
            statusItemMenu.isEnabled = false
            menu.addItem(statusItemMenu)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: L10n.quit, action: #selector(quitAppFromMenu), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }
    
    @objc private func toggleTurboFromMenu() {
        let turbo = TurboBoostService.shared
        turbo.setTurboDisabled(!turbo.isTurboDisabled)
    }
    
    @objc private func quitAppFromMenu() {
        NSApplication.shared.terminate(nil)
    }
    
    private func applyPanelAppearance() {
        let appearance: NSAppearance?
        switch AppSettings.shared.theme {
        case .auto:
            appearance = nil
        case .light:
            appearance = NSAppearance(named: .aqua)
        case .dark:
            appearance = NSAppearance(named: .darkAqua)
        }
        panel.appearance = appearance
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if isPanelOpen {
            closePopover(sender: sender)
        } else {
            showPopover(sender: sender)
        }
    }
    
    func showPopover(sender: AnyObject?) {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }
        NotificationCenter.default.post(name: .resetToMainTab, object: nil)
        isPanelOpen = true
        SystemMonitor.shared.isPopoverVisible = true
        SystemMonitor.shared.updateMetrics()
        TurboBoostService.shared.refreshStatus()
        
        let buttonRectInWindow = button.convert(button.bounds, to: nil)
        let buttonScreenRect = buttonWindow.convertToScreen(buttonRectInWindow)
        let screen = buttonWindow.screen ?? NSScreen.main ?? NSScreen.screens.first
        
        let panelSize = panel.frame.size
        var originX = round(buttonScreenRect.midX - panelSize.width / 2.0)
        var originY = round(buttonScreenRect.minY - panelSize.height - 6.0)
        
        if let screenFrame = screen?.frame {
            originX = max(screenFrame.minX + 8.0, min(originX, screenFrame.maxX - panelSize.width - 8.0))
            // Guarantee the top of the panel never exceeds the top of the screen even if the fullscreen menu bar slides away
            let maxTopY = screenFrame.maxY - 28.0
            if originY + panelSize.height > maxTopY {
                originY = maxTopY - panelSize.height
            }
        }
        
        let targetOrigin = NSPoint(x: originX, y: originY)
        panel.alphaValue = 0.0
        panel.setFrameOrigin(targetOrigin)
        panel.makeKeyAndOrderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.20
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0.1, 0.25, 1.0)
            panel.animator().alphaValue = 1.0
        }
    }
    
    func closePopover(sender: AnyObject?) {
        guard isPanelOpen else { return }
        isPanelOpen = false
        SystemMonitor.shared.isPopoverVisible = false
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0.0, 1.0, 1.0)
            panel.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            guard let self = self, !self.isPanelOpen else { return }
            self.panel.orderOut(nil)
            self.panel.alphaValue = 1.0
        })
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        FanControlService.shared.resetToAppleAuto()
    }
}

extension Notification.Name {
    static let resetToMainTab = Notification.Name("resetToMainTab")
}
