//
//  MainController.swift
//  MacSymbolicator
//

import Cocoa

class MainController: NSObject {
    private let mainWindow = CenteredWindow(width: 1200, height: 800)
    private let textWindowController = TextWindowController(title: "Symbolicated Content", clearable: false)

    private var updateButton: NSButton?
    private var availableUpdateURL: URL?

    // Split view components
    private let splitView = NSSplitView()
    private let leftSideView = NSView()
    private let rightSideView = NSView()
    
    // Left side components (input)
    private let dropZonesContainerView = NSView()
    private let statusView = NSView()
    private let statusTextField = NSTextField()
    private let symbolicateButton = NSButton()
    private let viewLogsButton = NSButton()
    
    // Right side components (result display)
    private let resultContainerView = NSView()
    private let resultScrollView = NSScrollView()
    private let resultTextView = NSTextView()
    private let resultToolbarView = NSView()
    private let saveButton = NSButton()
    private let clearButton = NSButton()
    private let resultTitleLabel = NSTextField()
    
    // Logs display components
    private let logsScrollView = NSScrollView()
    private let logsTextView = NSTextView()
    
    // View switching
    private let viewSwitchButton = NSButton()
    private var isShowingLogs = true {  // 默认显示结果视图
        didSet {
            switchRightPanelView()
        }
    }
    
    // Split view state
    private var userHasAdjustedSplit = false
    
    // Constraint references for dynamic layout
    private var viewSwitchButtonConstraint: NSLayoutConstraint?

    private lazy var inputCoordinator = InputCoordinator(logController: logController)

    private var isSymbolicating: Bool = false {
        didSet {
            symbolicateButton.isEnabled = !isSymbolicating
            symbolicateButton.title = isSymbolicating ? "Symbolicating…" : "Symbolicate"
        }
    }

    private let logController: ViewableLogController = DefaultViewableLogController()

    override init() {
        super.init()
        
        logController.delegate = self
        inputCoordinator.delegate = self
        
        // 添加一个测试日志消息以确保日志功能正常工作
        logController.addLogMessage("MacSymbolicator started successfully")

        let reportFileDropZone = inputCoordinator.reportFileDropZone
        let dsymFilesDropZone = inputCoordinator.dsymFilesDropZone
        
        // Configure main window
        mainWindow.styleMask = [.unifiedTitleAndToolbar, .titled, .closable, .resizable]
        mainWindow.title = "MacSymbolicator"
        mainWindow.minSize = NSSize(width: 800, height: 600)

        setupUI()
        setupConstraints()
        setupResultView()

        mainWindow.makeKeyAndOrderFront(nil)
    }
    
    private func setupUI() {
        let reportFileDropZone = inputCoordinator.reportFileDropZone
        let dsymFilesDropZone = inputCoordinator.dsymFilesDropZone
        
        // Configure status text field
        statusTextField.drawsBackground = false
        statusTextField.isBezeled = false
        statusTextField.isEditable = false
        statusTextField.isSelectable = false

        // Configure symbolicate button
        symbolicateButton.title = "Symbolicate"
        symbolicateButton.bezelStyle = .rounded
        symbolicateButton.focusRingType = .none
        symbolicateButton.keyEquivalent = "\r"
        symbolicateButton.target = self
        symbolicateButton.action = #selector(MainController.symbolicate)

        // Configure view logs button
        viewLogsButton.title = "View Logs…"
        viewLogsButton.bezelStyle = .rounded
        viewLogsButton.focusRingType = .none
        viewLogsButton.target = self
        viewLogsButton.action = #selector(showLogsInRightPanel)
        viewLogsButton.isHidden = true
        
        // Configure split view
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.delegate = self
        
        // Add subviews
        let contentView = mainWindow.contentView!
        contentView.addSubview(splitView)
        
        splitView.addArrangedSubview(leftSideView)
        splitView.addArrangedSubview(rightSideView)
        
        // Left side setup
        leftSideView.addSubview(dropZonesContainerView)
        leftSideView.addSubview(statusView)
        dropZonesContainerView.addSubview(reportFileDropZone)
        dropZonesContainerView.addSubview(dsymFilesDropZone)
        statusView.addSubview(statusTextField)
        statusView.addSubview(symbolicateButton)
        statusView.addSubview(viewLogsButton)
        
        // Right side setup
        rightSideView.addSubview(resultContainerView)
        resultContainerView.addSubview(resultToolbarView)
        resultContainerView.addSubview(resultScrollView)
        
        // Set initial split position (fixed left width)
        splitView.setPosition(480, ofDividerAt: 0)
    }
    
    private func setupConstraints() {
        let reportFileDropZone = inputCoordinator.reportFileDropZone
        let dsymFilesDropZone = inputCoordinator.dsymFilesDropZone
        
        // Disable autoresizing masks
        [splitView, leftSideView, rightSideView, dropZonesContainerView, statusView,
         statusTextField, symbolicateButton, viewLogsButton, resultContainerView,
         resultScrollView, resultToolbarView, logsScrollView, reportFileDropZone, dsymFilesDropZone].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            // Split view constraints
            splitView.topAnchor.constraint(equalTo: mainWindow.contentView!.topAnchor),
            splitView.leadingAnchor.constraint(equalTo: mainWindow.contentView!.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: mainWindow.contentView!.trailingAnchor),
            splitView.bottomAnchor.constraint(equalTo: mainWindow.contentView!.bottomAnchor),
            
            // Left side constraints
            dropZonesContainerView.topAnchor.constraint(equalTo: leftSideView.topAnchor),
            dropZonesContainerView.leadingAnchor.constraint(equalTo: leftSideView.leadingAnchor),
            dropZonesContainerView.trailingAnchor.constraint(equalTo: leftSideView.trailingAnchor),
            
            statusView.topAnchor.constraint(equalTo: dropZonesContainerView.bottomAnchor),
            statusView.leadingAnchor.constraint(equalTo: leftSideView.leadingAnchor),
            statusView.trailingAnchor.constraint(equalTo: leftSideView.trailingAnchor),
            statusView.bottomAnchor.constraint(equalTo: leftSideView.bottomAnchor),
            statusView.heightAnchor.constraint(equalToConstant: 60),

            // Drop zones constraints - 上下排列
            reportFileDropZone.topAnchor.constraint(equalTo: dropZonesContainerView.topAnchor),
            reportFileDropZone.leadingAnchor.constraint(equalTo: dropZonesContainerView.leadingAnchor),
            reportFileDropZone.trailingAnchor.constraint(equalTo: dropZonesContainerView.trailingAnchor),
            reportFileDropZone.heightAnchor.constraint(equalTo: dropZonesContainerView.heightAnchor, multiplier: 0.5),

            dsymFilesDropZone.topAnchor.constraint(equalTo: reportFileDropZone.bottomAnchor),
            dsymFilesDropZone.leadingAnchor.constraint(equalTo: dropZonesContainerView.leadingAnchor),
            dsymFilesDropZone.trailingAnchor.constraint(equalTo: dropZonesContainerView.trailingAnchor),
            dsymFilesDropZone.bottomAnchor.constraint(equalTo: dropZonesContainerView.bottomAnchor),

            // Status view constraints - 调整按钮布局和间距
            statusTextField.leadingAnchor.constraint(equalTo: statusView.leadingAnchor, constant: 20),
            statusTextField.centerYAnchor.constraint(equalTo: statusView.centerYAnchor),
            statusTextField.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),

            symbolicateButton.centerXAnchor.constraint(equalTo: statusView.centerXAnchor, constant: -65),
            symbolicateButton.centerYAnchor.constraint(equalTo: statusView.centerYAnchor),
            symbolicateButton.widthAnchor.constraint(equalToConstant: 120),

            viewLogsButton.centerXAnchor.constraint(equalTo: statusView.centerXAnchor, constant: 65),
            viewLogsButton.centerYAnchor.constraint(equalTo: statusView.centerYAnchor),
            viewLogsButton.widthAnchor.constraint(equalToConstant: 120),
            
            // Right side constraints
            resultContainerView.topAnchor.constraint(equalTo: rightSideView.topAnchor),
            resultContainerView.leadingAnchor.constraint(equalTo: rightSideView.leadingAnchor),
            resultContainerView.trailingAnchor.constraint(equalTo: rightSideView.trailingAnchor),
            resultContainerView.bottomAnchor.constraint(equalTo: rightSideView.bottomAnchor),
            
            // Result toolbar constraints
            resultToolbarView.topAnchor.constraint(equalTo: resultContainerView.topAnchor),
            resultToolbarView.leadingAnchor.constraint(equalTo: resultContainerView.leadingAnchor),
            resultToolbarView.trailingAnchor.constraint(equalTo: resultContainerView.trailingAnchor),
            resultToolbarView.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func setupResultView() {
        // Configure result title label
        resultTitleLabel.stringValue = "Symbolicated Result"
        resultTitleLabel.font = NSFont.boldSystemFont(ofSize: 16)
        resultTitleLabel.drawsBackground = false
        resultTitleLabel.isBezeled = false
        resultTitleLabel.isEditable = false
        resultTitleLabel.isSelectable = false
        
        // Configure view switch button
        viewSwitchButton.title = "View Logs"
        viewSwitchButton.bezelStyle = .rounded
        viewSwitchButton.target = self
        viewSwitchButton.action = #selector(toggleView)
        
        // Configure save button
        saveButton.title = "Save"
        saveButton.bezelStyle = .rounded
        saveButton.target = self
        saveButton.action = #selector(saveResult)
        saveButton.isEnabled = false
        
        // Configure clear button
        clearButton.title = "Clear"
        clearButton.bezelStyle = .rounded
        clearButton.target = self
        clearButton.action = #selector(clearResult)
        clearButton.isEnabled = false
        
        // Configure result scroll view and text view
        resultScrollView.hasVerticalScroller = true
        resultScrollView.hasHorizontalScroller = true
        resultScrollView.borderType = .noBorder
        
        resultTextView.isEditable = false
        resultTextView.isSelectable = true
        resultTextView.autoresizingMask = .width
        resultTextView.isVerticallyResizable = true
        resultTextView.isHorizontallyResizable = false
        
        // Configure logs scroll view and text view
        logsScrollView.hasVerticalScroller = true
        logsScrollView.hasHorizontalScroller = true
        logsScrollView.borderType = .noBorder
        
        logsTextView.isEditable = false
        logsTextView.isSelectable = true
        logsTextView.autoresizingMask = .width
        logsTextView.isVerticallyResizable = true
        logsTextView.isHorizontallyResizable = false
        logsTextView.textContainer?.containerSize = NSSize(width: logsScrollView.frame.width, height: CGFloat.greatestFiniteMagnitude)
        logsTextView.textContainer?.widthTracksTextView = true
        
        // Set monospaced font with compatibility for older macOS versions
        var fonts = [NSFont]()
        
        #if compiler(>=5.1) // Only build this part in Xcode 11, which knows about monospacedSystemFont
        if #available(macOS 10.15, *) {
            fonts.append(NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular))
        }
        #endif
        
        let monospacedFonts = ["SFMono-Regular", "Menlo", "Monaco", "Courier New"].compactMap {
            NSFont(name: $0, size: NSFont.systemFontSize)
        }
        
        fonts.append(contentsOf: monospacedFonts)
        let monospaceFont = fonts.first ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
        
        resultTextView.font = monospaceFont
        logsTextView.font = monospaceFont
        
        resultTextView.string = "Symbolication results will appear here..."
        logsTextView.string = "Logs will appear here..."
        
        // 使用统一的高辨识度配色方案
        resultTextView.textColor = NSColor.labelColor
        logsTextView.textColor = NSColor.labelColor
        
        resultScrollView.documentView = resultTextView
        logsScrollView.documentView = logsTextView
        
        // 确保文本视图正确适配滚动视图
        resultTextView.frame = resultScrollView.contentView.bounds
        logsTextView.frame = logsScrollView.contentView.bounds
        
        // Add toolbar components
        resultToolbarView.addSubview(resultTitleLabel)
        resultToolbarView.addSubview(viewSwitchButton)
        resultToolbarView.addSubview(saveButton)
        resultToolbarView.addSubview(clearButton)
        
        // Add scroll views to container (initially show result view)
        resultContainerView.addSubview(resultScrollView)
        resultContainerView.addSubview(logsScrollView)
        
        [resultTitleLabel, viewSwitchButton, saveButton, clearButton, resultScrollView, logsScrollView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        NSLayoutConstraint.activate([
            resultTitleLabel.leadingAnchor.constraint(equalTo: resultToolbarView.leadingAnchor, constant: 16),
            resultTitleLabel.centerYAnchor.constraint(equalTo: resultToolbarView.centerYAnchor),
            
            clearButton.trailingAnchor.constraint(equalTo: resultToolbarView.trailingAnchor, constant: -16),
            clearButton.centerYAnchor.constraint(equalTo: resultToolbarView.centerYAnchor),
            clearButton.widthAnchor.constraint(equalToConstant: 100),
            
            saveButton.trailingAnchor.constraint(equalTo: clearButton.leadingAnchor, constant: -12),
            saveButton.centerYAnchor.constraint(equalTo: resultToolbarView.centerYAnchor),
            saveButton.widthAnchor.constraint(equalToConstant: 80),
            
            viewSwitchButton.centerYAnchor.constraint(equalTo: resultToolbarView.centerYAnchor),
            viewSwitchButton.widthAnchor.constraint(equalToConstant: 110),
        ])
        
        // Set initial viewSwitchButton position constraint (will be updated in switchRightPanelView)
        viewSwitchButtonConstraint = viewSwitchButton.trailingAnchor.constraint(equalTo: saveButton.leadingAnchor, constant: -12)
        viewSwitchButtonConstraint?.isActive = true
        
        NSLayoutConstraint.activate([
            resultScrollView.topAnchor.constraint(equalTo: resultToolbarView.bottomAnchor),
            resultScrollView.leadingAnchor.constraint(equalTo: resultContainerView.leadingAnchor),
            resultScrollView.trailingAnchor.constraint(equalTo: resultContainerView.trailingAnchor),
            resultScrollView.bottomAnchor.constraint(equalTo: resultContainerView.bottomAnchor),
            
            // Logs scroll view constraints (same position as result view)
            logsScrollView.topAnchor.constraint(equalTo: resultToolbarView.bottomAnchor),
            logsScrollView.leadingAnchor.constraint(equalTo: resultContainerView.leadingAnchor),
            logsScrollView.trailingAnchor.constraint(equalTo: resultContainerView.trailingAnchor),
            logsScrollView.bottomAnchor.constraint(equalTo: resultContainerView.bottomAnchor)
        ])
        
        // Initialize logs display
        updateLogsDisplay()
        
        // Ensure the UI matches the initial isShowingLogs state
        switchRightPanelView()
    }
    
    @objc private func toggleView() {
        isShowingLogs.toggle()
    }
    
    private func switchRightPanelView() {
        // Update viewSwitchButton position constraint
        viewSwitchButtonConstraint?.isActive = false
        
        if isShowingLogs {
            resultScrollView.isHidden = true
            logsScrollView.isHidden = false
            resultTitleLabel.stringValue = "Logs"
            resultTitleLabel.textColor = NSColor.labelColor
            viewSwitchButton.title = "View Result"
            saveButton.isHidden = true
            clearButton.title = "Clear Logs"
            clearButton.target = self
            clearButton.action = #selector(clearLogs)
            
            // Position viewSwitchButton relative to clearButton when saveButton is hidden
            viewSwitchButtonConstraint = viewSwitchButton.trailingAnchor.constraint(equalTo: clearButton.leadingAnchor, constant: -12)
            
            updateLogsDisplay()
            
            // 强制重新布局和显示
            logsScrollView.needsLayout = true
            logsScrollView.layoutSubtreeIfNeeded()
            logsTextView.needsDisplay = true
        } else {
            resultScrollView.isHidden = false
            logsScrollView.isHidden = true
            resultTitleLabel.stringValue = "Symbolicated Result"
            resultTitleLabel.textColor = NSColor.labelColor
            viewSwitchButton.title = "View Logs"
            saveButton.isHidden = false
            clearButton.title = "Clear"
            clearButton.target = self
            clearButton.action = #selector(clearResult)
            
            // Position viewSwitchButton relative to saveButton when saveButton is visible
            viewSwitchButtonConstraint = viewSwitchButton.trailingAnchor.constraint(equalTo: saveButton.leadingAnchor, constant: -12)
            
            // 强制重新布局和显示
            resultScrollView.needsLayout = true
            resultScrollView.layoutSubtreeIfNeeded()
            resultTextView.needsDisplay = true
        }
        
        viewSwitchButtonConstraint?.isActive = true
    }
    
    private func updateLogsDisplay() {
        DispatchQueue.main.async {
            let logs = self.logController.logMessages.joined(separator: "\n\n")
            print("DEBUG: updateLogsDisplay called, logs count: \(self.logController.logMessages.count)")
            print("DEBUG: logs content: \(logs)")
            
            self.logsTextView.string = logs.isEmpty ? "No logs available..." : logs
            
            // 使用统一的高辨识度配色方案
            self.logsTextView.textColor = logs.isEmpty ? NSColor.secondaryLabelColor : NSColor.labelColor
            
            // 强制刷新显示
            self.logsTextView.needsDisplay = true
            self.logsScrollView.needsDisplay = true
        }
    }
    
    @objc private func clearLogs() {
        logController.resetLogs()
        updateLogsDisplay()
    }
    
    @objc private func showLogsInRightPanel() {
        isShowingLogs = true
        rightSideView.alphaValue = 1.0
    }

    @objc func symbolicate() {
        guard !isSymbolicating else { return }

        guard let reportFile = inputCoordinator.reportFile else {
            inputCoordinator.reportFileDropZone.flash()
            return
        }

        guard !inputCoordinator.dsymFiles.isEmpty else {
            inputCoordinator.dsymFilesDropZone.flash()
            return
        }
        
        // 检查是否有缺失的 DSYM 文件
        if inputCoordinator.hasMissingDSYMs {
            let missingCount = inputCoordinator.missingDSYMsCount
            let alert = NSAlert()
            alert.messageText = "Missing dSYM Files"
            alert.informativeText = "There are \(missingCount) dSYM file(s) still missing for complete symbolication. Do you want to continue with partial symbolication?"
            alert.addButton(withTitle: "Continue")
            alert.addButton(withTitle: "Cancel")
            alert.alertStyle = .warning
            
            let response = alert.runModal()
            if response == .alertSecondButtonReturn {
                // 用户选择取消
                return
            }
        }

        logController.resetLogs()
        logController.addLogMessage("Starting symbolication process...")

        isSymbolicating = true
        
        // 符号化时切换到结果页面以显示进度和结果
        isShowingLogs = false
        
        // Show loading state in result view
        resultTextView.string = "Symbolicating..."
        resultTextView.textColor = NSColor.labelColor
        rightSideView.alphaValue = 1.0
        saveButton.isEnabled = false
        clearButton.isEnabled = false

        let dsymFiles = inputCoordinator.dsymFiles
        var symbolicator = Symbolicator(
            reportFile: reportFile,
            dsymFiles: dsymFiles,
            logController: logController
        )

        DispatchQueue.global(qos: .userInitiated).async {
            let success = symbolicator.symbolicate()

            DispatchQueue.main.async {
                if success {
                    // Display result in the right panel
                    self.resultTextView.string = symbolicator.symbolicatedContent ?? ""
                    self.resultTextView.textColor = NSColor.labelColor
                    self.saveButton.isEnabled = true
                    self.clearButton.isEnabled = true
                    self.currentSaveURL = reportFile.symbolicatedContentSaveURL
                    
                    // Update save button title
                    self.saveButton.title = self.currentSaveURL != nil ? "Save" : "Save As..."
                } else {
                    self.resultTextView.string = "Symbolication failed. See logs for more info."
                    self.resultTextView.textColor = NSColor.systemRed
                    self.clearButton.isEnabled = true
                    
                    let alert = NSAlert()
                    alert.informativeText = "Symbolication failed. See logs for more info."
                    alert.alertStyle = .critical

                    alert.addButton(withTitle: "OK")
                    alert.addButton(withTitle: "View Logs…")

                    if alert.runModal() == .alertSecondButtonReturn {
                        self.logController.viewLogs()
                    }
                }

                self.isSymbolicating = false
            }
        }
    }
    
    // Add a property to store the current save URL
    private var currentSaveURL: URL?
    
    @objc func saveResult() {
        let content = resultTextView.string
        guard !content.isEmpty else { return }
        
        let saveFailureHandler: (Error) -> Void = { error in
            let alert = NSAlert()
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
        
        if let defaultSaveURL = currentSaveURL {
            do {
                try content.write(to: defaultSaveURL, atomically: true, encoding: .utf8)
                NSWorkspace.shared.activateFileViewerSelecting([defaultSaveURL])
            } catch {
                saveFailureHandler(error)
            }
        } else {
            let savePanel = NSSavePanel()
            savePanel.allowedFileTypes = ["txt", "crash", "ips"] // 使用 allowedFileTypes 而不是 allowedContentTypes
            savePanel.beginSheetModal(for: mainWindow) { response in
                switch response {
                case .OK:
                    guard let url = savePanel.url else { return }
                    
                    do {
                        try content.write(to: url, atomically: true, encoding: .utf8)
                        self.currentSaveURL = url
                        self.saveButton.title = "Save"
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    } catch {
                        saveFailureHandler(error)
                    }
                default:
                    return
                }
            }
        }
    }
    
    @objc func clearResult() {
        resultTextView.string = "Symbolication results will appear here..."
        resultTextView.textColor = NSColor.labelColor
        saveButton.isEnabled = false
        clearButton.isEnabled = false
        currentSaveURL = nil
        saveButton.title = "Save"
        rightSideView.alphaValue = 1.0
    }

    func openFile(_ path: String) -> Bool {
        let fileURL = URL(fileURLWithPath: path)
        return inputCoordinator.acceptReportFile(url: fileURL) || inputCoordinator.acceptDSYMFile(url: fileURL)
    }

    func suggestUpdate(version: String, url: URL) {
        availableUpdateURL = url

        let updateButton = self.updateButton ?? NSButton()
        updateButton.title = "Update available: \(version)"
        updateButton.controlSize = .small
        updateButton.bezelStyle = .roundRect
        updateButton.target = self
        updateButton.action = #selector(self.tappedUpdateButton(_:))

        guard let frameView = mainWindow.contentView?.superview else {
            return
        }

        frameView.addSubview(updateButton)
        updateButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            updateButton.trailingAnchor.constraint(equalTo: frameView.trailingAnchor, constant: -6),
            updateButton.topAnchor.constraint(equalTo: frameView.topAnchor, constant: 6)
        ])
    }

    @objc
    private func tappedUpdateButton(_ sender: AnyObject?) {
        guard let availableUpdateURL = availableUpdateURL else { return }
        NSWorkspace.shared.open(availableUpdateURL)
    }
}

extension MainController: LogControllerDelegate {
    func logController(_ controller: LogController, logsUpdated logMessages: [String]) {
        DispatchQueue.main.async {
            self.viewLogsButton.isHidden = logMessages.isEmpty
            if self.isShowingLogs {
                self.updateLogsDisplay()
            }
        }
    }
}

extension MainController: NSSplitViewDelegate {
    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        return 400 // Minimum width for left side (input area)
    }
    
    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        return splitView.frame.width - 300 // Minimum width for right side (result area)
    }
    
    func splitViewDidResizeSubviews(_ notification: Notification) {
        // Mark that user has manually adjusted the split
        userHasAdjustedSplit = true
    }
    
    func splitView(_ splitView: NSSplitView, resizeSubviewsWithOldSize oldSize: NSSize) {
        guard splitView.subviews.count == 2 else { return }
        
        let leftView = splitView.subviews[0]
        let rightView = splitView.subviews[1]
        
        let dividerThickness = splitView.dividerThickness
        let newWidth = splitView.frame.width
        let newHeight = splitView.frame.height
        
        // Keep left side width fixed, only adjust right side
        let leftMinWidth: CGFloat = 400
        let rightMinWidth: CGFloat = 300
        
        let currentLeftWidth = leftView.frame.width
        var newLeftWidth = currentLeftWidth
        var newRightWidth = newWidth - newLeftWidth - dividerThickness
        
        // If it's the first time setting up or user hasn't adjusted, use default
        if currentLeftWidth <= 0 || !userHasAdjustedSplit {
            newLeftWidth = 480 // Fixed default width for left side
            newRightWidth = newWidth - newLeftWidth - dividerThickness
        }
        
        // Ensure minimum widths are respected
        if newLeftWidth < leftMinWidth {
            newLeftWidth = leftMinWidth
            newRightWidth = newWidth - newLeftWidth - dividerThickness
        }
        
        if newRightWidth < rightMinWidth {
            newRightWidth = rightMinWidth
            newLeftWidth = newWidth - newRightWidth - dividerThickness
        }
        
        leftView.frame = NSRect(x: 0, y: 0, width: newLeftWidth, height: newHeight)
        rightView.frame = NSRect(x: newLeftWidth + dividerThickness, y: 0, width: newRightWidth, height: newHeight)
    }
}

extension MainController: InputCoordinatorDelegate {
    func inputCoordinatorDidUpdateReportFile(_ coordinator: InputCoordinator) {
        DispatchQueue.main.async {
            // 选中新的crash文件时，切换到日志视图
            self.isShowingLogs = true
        }
    }
}
