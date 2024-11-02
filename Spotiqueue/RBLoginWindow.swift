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

            let worker_initialized = spotiqueue_login_worker(username, password)
            switch worker_initialized.tag {
                case InitOkay:
                    // It went fine, let's open the main view.
                // TODO somehow signal that we successfully logged in.
                    self.window?.sheetParent?.endSheet(self.window!, returnCode: .OK)
                case InitBadCredentials:
                    self.showLoginError(message: "Your credentials are incorrect.")
                case InitNotPremium:
                    self.showLoginError(message: "Unfortunately, Spotify requires you to have a Spotify Premium account to use 3rd-party clients.")
                case InitProblem:
                    let problem = String(cString: worker_initialized.init_problem.description)
                    self.showLoginError(message: problem)
                default:
                    fatalError("Unable to launch spotiqueue-worker!")
            }
        } else {
            // signal that login faailed, so that we don't bother trying to restore previous playlist on auth error.  causes a crash.
            logger.info("Eek, couldn't retrieve username or password from Keychain! Let's ask the user.")
        }
        self.endSpinning()
    }

    @IBAction func loginPressed(_ sender: Any) {
        RBSecrets.setSecret(s: .username, v: self.usernameField.stringValue.data(using: .utf8)!)
        RBSecrets.setSecret(s: .password, v: self.passwordField.stringValue.data(using: .utf8)!)
        self.startLoginRoutine()
    }

    func showLoginError(message: String) {
        let alert = NSAlert()
        alert.messageText = "Login error"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: self.window!) { _ in
        }
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
