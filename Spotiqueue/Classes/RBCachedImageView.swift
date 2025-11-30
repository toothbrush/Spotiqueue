//
//  RBCachedImageView.swift
//  Spotiqueue
//
//  Created by Paul on 25/5/21.
//  Copyright © 2021 Rustling Broccoli. All rights reserved.
//

import Cocoa
import Foundation

class RBCachedImageView: NSImageView {
    static var imageCache = NSCache<NSString, NSImage>()

    var currentURL: String?

    // https://stackoverflow.com/questions/37018916/swift-async-load-image
    func imageFromServerURL(_ URLString: String, placeHolder: NSImage?) {
        guard self.currentURL ?? "" != URLString else {
            return
        }
        self.currentURL = URLString

        image = nil
        // In case URLString has a space:
        let imageServerUrl = URLString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let cachedImage = RBCachedImageView.imageCache.object(forKey: NSString(string: imageServerUrl)) {
            image = cachedImage
            return
        }

        if let url = URL(string: imageServerUrl) {
            URLSession.shared.dataTask(with: url, completionHandler: { data, _, error in
                if error != nil {
                    logger.error("Error loading image from URL: \(String(describing: error?.localizedDescription))")
                    DispatchQueue.main.async {
                        self.image = placeHolder
                    }
                    return
                }
                DispatchQueue.main.async { [self] in
                    if let data = data {
                        if let downloadedImage = NSImage(data: data) {
                            RBCachedImageView.imageCache.setObject(downloadedImage, forKey: NSString(string: imageServerUrl))
                            self.image = downloadedImage
                        }
                    }
                }
            }).resume()
        }
    }
}
