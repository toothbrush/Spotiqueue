//
//  RBLoginWindow.swift
//  Spotiqueue
//
//  Created by paul david on 14/6/21.
//  Copyright © 2021 Rustling Broccoli. All rights reserved.
//

import Cocoa

class RBLoginWindow: NSWindowController {
    @IBOutlet var usernameField: NSTextField!
    @IBOutlet var passwordField: NSSecureTextField!
    @IBOutlet var loginButton: NSButton!
    @IBOutlet var quitButton: NSButton!
    @IBOutlet var loginSpinner: NSProgressIndicator!

    override func windowDidLoad() {
        super.windowDidLoad()
        self.startSpinning()
    }

    func startLoginRoutine() {
        self.startSpinning()
        // try to grab user/pass from keychain:
        if let username = RBSecrets.getSecret(s: .username),
           let password = RBSecrets.getSecret(s: .password)
        {
            self.usernameField.isEnabled = true
            self.passwordField.isEnabled = true
            self.usernameField.stringValue = username
            self.passwordField.stringValue = password
            self.usernameField.isEnabled = false
            self.passwordField.isEnabled = false

            let worker_initialized = spotiqueue_initialize_worker(username, password)
            if !worker_initialized {
                fatalError("Unable to launch spotiqueue-worker!")
            }

            self.window?.sheetParent?.endSheet(self.window!, returnCode: .OK)
        } else {
            logger.info("Eek, couldn't retrieve username or password from Keychain! Let's ask the user.")
        }
        self.endSpinning()
    }

    @IBAction func loginPressed(_ sender: Any) {
        RBSecrets.setSecret(s: .username, v: self.usernameField.stringValue.data(using: .utf8)!)
        RBSecrets.setSecret(s: .password, v: self.passwordField.stringValue.data(using: .utf8)!)
        self.startLoginRoutine()
    }

    @IBAction func quitButton(_ sender: Any) {
        for window in NSApp.windows {
            window.close()
        }
        NSApp.terminate(self)
    }

    func startSpinning() {
        self.usernameField.isEnabled = false
        self.passwordField.isEnabled = false
        self.quitButton.isEnabled = false
        self.loginButton.isEnabled = false
        self.loginSpinner.isHidden = false
        self.loginSpinner.startAnimation(self)
    }

    func endSpinning() {
        self.loginSpinner.isHidden = true
        self.loginSpinner.stopAnimation(self)
        self.usernameField.isEnabled = true
        self.passwordField.isEnabled = true
        self.quitButton.isEnabled = true
        self.loginButton.isEnabled = true
        self.window?.makeFirstResponder(self.usernameField)
    }
}
