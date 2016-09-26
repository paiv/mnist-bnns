//
//  ImageMagic.swift
//  mnistios
//
//  Created by Pavel Ivashkov on 2016-09-25.
//  Copyright © 2016 paiv. All rights reserved.
//

import UIKit


class ImageMagic {
    
    func mnist(image: UIImage) -> UIImage? {

        let mass = centerOfMass(image: image)
        
        let target = CGSize(width: 28, height: 28)
        
        let scale = max(target.width / mass.width, target.height / mass.height)
        let scaledSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        
        var rect = CGRect(origin: CGPoint(x: -mass.minX * scale, y: -mass.minY * scale), size: scaledSize)
        
        UIGraphicsBeginImageContextWithOptions(target, false, 1)
        defer {
            UIGraphicsEndImageContext()
        }
        
        image.draw(in: rect)
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    func centerCropResize(image: UIImage, target: CGSize) -> UIImage? {
        
        let scale = max(target.width / image.size.width, target.height / image.size.height)
        let scaledSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        
        var rect = CGRect(origin: CGPoint(x: (target.width - scaledSize.width) / 2, y: (target.height - scaledSize.height) / 2), size: scaledSize)
        
        UIGraphicsBeginImageContextWithOptions(target, false, 1)
        defer {
            UIGraphicsEndImageContext()
        }
        
        image.draw(in: rect)
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    func centerOfMass(image: UIImage) -> CGRect {
        let width = Int(image.size.width)
        let height = Int(image.size.height)
        let midpoint = CGRect(origin: CGPoint.zero, size: image.size)
        
        guard let data = bytes(image: image) else { return midpoint }
        
        var mass: CGFloat = 0
        var rx: CGFloat = 0
        var ry: CGFloat = 0
        var minPoint = CGPoint(x: Int.max, y: Int.max)
        var maxPoint = CGPoint(x: Int.min, y: Int.min)
        
        for row in 0..<height {
            for col in 0..<width {
                let px = 1 - CGFloat(data[row * width + col]) / 255
                guard px > 0 else { continue }
                
                let x = CGFloat(col)
                let y = CGFloat(row)
                
                mass += px
                rx += px * x
                ry += px * y
                
                if x < minPoint.x {
                    minPoint.x = x
                }
                if x > maxPoint.x {
                    maxPoint.x = x
                }
                if y < minPoint.y {
                    minPoint.y = y
                }
                if y > maxPoint.y {
                    maxPoint.y = y
                }
            }
        }
        
        guard mass > 0 else { return midpoint }
        
        let center = CGPoint(x: rx / mass, y: ry / mass)
        
        let hx = max(center.x - minPoint.x, maxPoint.x - center.x)
        let hy = max(center.y - minPoint.y, maxPoint.y - center.y)
        let hh = max(hx, hy)
        
        return CGRect(origin: center, size: CGSize.zero).insetBy(dx: -hh, dy: -hh)
    }
    
    func bytes(image: UIImage) -> Data? {
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGBitmapInfo()

        guard let context = CGContext(data: nil, width: Int(image.size.width), height: Int(image.size.height), bitsPerComponent: 8, bytesPerRow: Int(image.size.width), space: colorSpace, bitmapInfo: bitmapInfo.rawValue) else { return nil }
        
        context.draw(image.cgImage!, in: CGRect(origin: CGPoint.zero, size: image.size))
        
        let data = Data(bytes: context.data!, count: Int(image.size.width * image.size.height))
        
        return data
    }
    
    func mnistData(image: UIImage) -> [Float32]? {
        guard let mnistImage = mnist(image: image),
            let data = bytes(image: mnistImage)
            else { return nil }
        
        return data.map { 1 - Float32($0) / 255.0 }
    }
}
