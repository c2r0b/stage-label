//
//  InvisibleWindow.swift
//  Stage Label
//
//  Created by c2r0b on 03/01/24.
//

import SwiftUI


class InvisibleWindow: NSWindow, NSTextFieldDelegate {
    private var textField: NSTextField!
    private var allowKeyStatus = false
    public var groupId: UUID
    private var viewModel: WindowListViewModel
    

    init(label: String, frame: NSRect, groupId: UUID, viewModel: WindowListViewModel) {
        self.groupId = groupId
        self.viewModel = viewModel
        super.init(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        self.isOpaque = false
        self.backgroundColor = NSColor.clear
        self.hasShadow = false
        // Set the window level to be lower than normal windows
        self.level = .floating

        self.ignoresMouseEvents = false

        setupTextField(with: label, frame: frame)
        
        // Deselect text after setting up the text field
        DispatchQueue.main.async {
            self.textField.currentEditor()?.selectedRange = NSRange(location: 0, length: 0)
            self.updateTextFieldAppearance()
        }
    }
    
    override var canBecomeKey: Bool {
        return true
    }
    
    func updateTextFieldAppearance() {
        // Update text field appearance based on the viewModel's colors
        textField.textColor = viewModel.textFieldColor.nsColor
        textField.isBordered = viewModel.backgroundColor != .clear
        textField.drawsBackground = viewModel.backgroundColor != .clear
        textField.backgroundColor = viewModel.backgroundColor.nsColor.withAlphaComponent(CGFloat(viewModel.backgroundOpacity))
        textField.font = NSFont.systemFont(ofSize: viewModel.textFieldSize)
        textField.frame.size.height = viewModel.textFieldSize + 8
    }
    
    private func setupTextField(with label: String, frame: NSRect) {
        // Define the height for the text field
        let textFieldHeight: CGFloat = viewModel.textFieldSize + 8  // Adjust this height to match your font size
        let horizontalPadding: CGFloat = 10  // Horizontal padding

        // Create the text field
        textField = NSTextField(frame: NSRect(x: 0, y: 0, width: frame.width - 2 * horizontalPadding, height: textFieldHeight))
        textField.stringValue = label
        textField.isEditable = true
        textField.focusRingType = .none
        textField.font = NSFont.systemFont(ofSize: viewModel.textFieldSize)
        textField.alignment = .left  // Align text to the left
        textField.delegate = self
        textField.target = self
        textField.action = #selector(textFieldClicked(_:))

        // Configure layer for rounded corners and remove borders
        textField.wantsLayer = true
        textField.layer?.cornerRadius = 5  // Adjust corner radius as needed
        textField.layer?.borderWidth = 1   // Set border width to 0 to remove borders
        textField.layer?.masksToBounds = true  // Ensure the layer clips to bounds

        // Create a container view for padding
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: frame.width, height: textFieldHeight))
        containerView.wantsLayer = true

        // Add the text field to the container view
        textField.frame.origin.x = horizontalPadding
        textField.frame.origin.y = 0  // Vertically center
        containerView.addSubview(textField)

        // Add the container view to the window's content view
        self.contentView?.addSubview(containerView)
    }

    @objc private func textFieldClicked(_ sender: NSTextField) {
        allowKeyStatus = true
        self.makeKeyAndOrderFront(nil)
        textField.becomeFirstResponder()
    }
    
    func controlTextDidBeginEditing(_ obj: Notification) {
        if let textField = obj.object as? NSTextField {
            // Deselect text when editing begins
            textField.currentEditor()?.selectedRange = NSRange(location: 0, length: 0)
        }
    }

    // Method to update the text field
    func updateTextField(with text: String) {
        textField.stringValue = text
    }

    // Override this method to save the text value when editing ends
    func controlTextDidEndEditing(_ obj: Notification) {
        allowKeyStatus = false
    }


    func controlTextDidChange(_ obj: Notification) {
        print("Text changed")
        if let textField = obj.object as? NSTextField, let window = textField.window as? InvisibleWindow {
            let updatedText = textField.stringValue
            if let identifier = viewModel.groupIdentifierMapping.first(where: { $1 == window.groupId })?.key {
                viewModel.textFieldValues[identifier] = updatedText
                viewModel.saveTextFieldValues()
            }
        }
    }
    
    func isOnScreen(_ screenFrame: CGRect) -> Bool {
        return self.frame.intersects(screenFrame)
    }
}
