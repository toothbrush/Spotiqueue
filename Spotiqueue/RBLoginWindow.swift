//
//  RBLoginWindow.swift
//  Spotiqueue
//
//  Created by paul david on 14/6/21.
//  Copyright © 2021 Rustling Broccoli. All rights reserved.
//

import Cocoa

class RBLoginWindow: NSWindowController {

    @IBOutlet weak var usernameField: NSTextField!
    @IBOutlet weak var passwordField: NSSecureTextField!
    @IBOutlet weak var loginButton: NSButton!
    @IBOutlet weak var quitButton: NSButton!
    @IBOutlet weak var loginSpinner: NSProgressIndicator!
    
    override func windowDidLoad() {
        super.windowDidLoad()
        startSpinning()
    }
    
    func startLoginRoutine(){
        startSpinning()
        // try to grab user/pass from keychain:
        if let username = RBSecrets.getSecret(s: .username),
           let password = RBSecrets.getSecret(s: .password) {
            usernameField.stringValue = username
            passwordField.stringValue = password
            
            let worker_initialized = spotiqueue_initialize_worker(username, password)
            if !worker_initialized {
                fatalError("Unable to launch spotiqueue-worker!")
            }
            
            self.window?.sheetParent?.endSheet(self.window!, returnCode: .OK)
        } else {
            logger.info("Eek, couldn't retrieve username or password from Keychain! Let's ask the user.")
        }
        endSpinning()
    }
    
    @IBAction func loginPressed(_ sender: Any) {
        RBSecrets.setSecret(s: .username, v: usernameField.stringValue.data(using: .utf8)!)
        RBSecrets.setSecret(s: .password, v: passwordField.stringValue.data(using: .utf8)!)
        self.startLoginRoutine()
    }
    
    @IBAction func quitButton(_ sender: Any) {
        for window in NSApp.windows {
            window.close()
        }
        NSApp.terminate(self)
    }
    
    func startSpinning() {
        usernameField.isEnabled = false
        passwordField.isEnabled = false
        quitButton.isEnabled = false
        loginButton.isEnabled = false
        self.loginSpinner.isHidden = false
        self.loginSpinner.startAnimation(self)
    }
    
    func endSpinning() {
        self.loginSpinner.isHidden = true
        self.loginSpinner.stopAnimation(self)
        usernameField.isEnabled = true
        passwordField.isEnabled = true
        quitButton.isEnabled = true
        loginButton.isEnabled = true
        self.window?.makeFirstResponder(self.usernameField)
    }
}
