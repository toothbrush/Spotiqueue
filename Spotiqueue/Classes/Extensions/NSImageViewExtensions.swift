//
//  NSImageViewExtensions.swift
//  Spotiqueue
//
//  Created by Paul on 25/5/21.
//  Copyright © 2021 Rustling Broccoli. All rights reserved.
//

import Cocoa
import Foundation

extension NSImageView {
    // ooooh icky https://stackoverflow.com/questions/44674549/extensions-may-not-contain-stored-properties-unless-your-are-apple-what-am-i
    private enum uglyImageState {
        static var imageCache = NSCache<NSString, NSImage>()
    }

    var imageCache: NSCache<NSString, NSImage> {
        get {
            guard let theName = objc_getAssociatedObject(self, &uglyImageState.imageCache) as? NSCache<NSString, NSImage> else {
                return NSCache<NSString, NSImage>()
            }
            return theName
        }
        set {
            objc_setAssociatedObject(self, &uglyImageState.imageCache, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    // https://stackoverflow.com/questions/37018916/swift-async-load-image
    func imageFromServerURL(_ URLString: String, placeHolder: NSImage?) {
        self.image = nil
        // If imageurl's imagename has space then this line going to work for this
        let imageServerUrl = URLString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let cachedImage = imageCache.object(forKey: NSString(string: imageServerUrl)) {
            self.image = cachedImage
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
                            imageCache.setObject(downloadedImage, forKey: NSString(string: imageServerUrl))
                            self.image = downloadedImage
                        }
                    }
                }
            }).resume()
        }
    }
}
