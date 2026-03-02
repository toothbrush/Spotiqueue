//
//  RBLoginWindow.swift
//  Spotiqueue
//
//  Created by paul david on 14/6/21.
//  Copyright © 2021 Rustling Broccoli. All rights reserved.
//

import Cocoa
import Combine

class RBLoginWindow: NSWindowController {
    @IBOutlet var loginButton: NSButton!
    @IBOutlet var quitButton: NSButton!
    @IBOutlet var loginSpinner: NSProgressIndicator!

    private var userCodeLabel: NSTextField!
    private var cancellables: Set<AnyCancellable> = []

    override func windowDidLoad() {
        super.windowDidLoad()
        self.window?.title = "Login to Tidal"

        // Add a label for displaying the device code
        if let contentView = self.window?.contentView {
            let label = NSTextField(wrappingLabelWithString: "")
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = NSFont.monospacedSystemFont(ofSize: 18, weight: .bold)
            label.alignment = .center
            label.isHidden = true
            contentView.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 90),
                label.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, constant: -40),
            ])
            self.userCodeLabel = label
        }

        // Observe user code changes from the Tidal auth flow
        AppDelegate.appDelegate().tidalAuth.$userCode
            .receive(on: RunLoop.main)
            .sink { [weak self] code in
                guard let self = self else { return }
                if let code = code {
                    self.userCodeLabel.stringValue = "Your code: \(code)"
                    self.userCodeLabel.isHidden = false
                } else {
                    self.userCodeLabel.isHidden = true
                }
            }
            .store(in: &self.cancellables)
    }

    @IBAction func loginPressed(_ sender: Any) {
        self.loginButton.isEnabled = false
        self.loginSpinner.isHidden = false
        self.loginSpinner.startAnimation(self)
        AppDelegate.appDelegate().tidalAuth.startDeviceCodeFlow()
    }

    @IBAction func quitButton(_ sender: Any) {
        for window in NSApp.windows {
            window.close()
        }
        NSApp.terminate(self)
    }
}
