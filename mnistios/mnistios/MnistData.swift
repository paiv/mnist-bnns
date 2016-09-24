//
//  MnistData.swift
//  mnistios
//
//  Created by Pavel Ivashkov on 2016-08-28.
//  Copyright © 2016 paiv. All rights reserved.
//

import Foundation
import UIKit


struct MnistReader {
    let data: Data
    
    init(data: Data) {
        self.data = data
    }
    
    func int(at location: Int) -> UInt32 {
        var value: UInt32 = 0
        let ptr = UnsafeMutableBufferPointer<UInt32>(start: &value, count: 1)
        let _ = data.copyBytes(to: ptr, from: location..<(location + 4))
        return CFSwapInt32BigToHost(value)
    }
    
    func bytes(in range: Range<Int>) -> Data {
        return data.subdata(in: range)
    }
    
    func byte(at location: Int) -> UInt8 {
        return data.withUnsafeBytes { (ptr) in
            return ptr[location]
        }
    }
}


struct MnistImage {
    
    let reader: MnistReader
    let magic: UInt32
    let count: Int
    let imageSize: (width: Int, height: Int)
    
    init?(data: Data?) {
        guard let data = data else { return nil }
        reader = MnistReader(data: data)
        
        magic = reader.int(at: 0)
        guard magic == 0x803 else { return nil }

        count = Int(reader.int(at: 4))
        let w = Int(reader.int(at: 8))
        let h = Int(reader.int(at: 12))
        imageSize = (width: w, height: h)
    }
    
    func sample(index: Int) -> Data {
        let stride = imageSize.width * imageSize.height
        let header = 16
        let offset = header + stride * index
        return reader.bytes(in: offset..<(offset + stride))
    }
    
    func samples(range: Range<Int>) -> Data {
        let stride = imageSize.width * imageSize.height
        let header = 16
        let offset = header
        return reader.bytes(in: (offset + stride * range.lowerBound) ..< (offset + stride * range.upperBound))
    }
    
    func samples(indexes: [Int]) -> Data {
        let stride = imageSize.width * imageSize.height
        let header = 16
        
        var data = Data(count: stride * indexes.count)
        
        for i in 0..<indexes.count {
            let offset = header + stride * indexes[i]
            let bytes = reader.bytes(in: offset..<(offset + stride))
            data.replaceSubrange(stride * i..<stride * (i + 1), with: bytes)
        }
        return data
    }
    
    func sampleInverse(index: Int) -> Data {
        let data = NSMutableData(data: sample(index: index) as Data)
        
        let ptr = data.mutableBytes.bindMemory(to: UInt8.self, capacity: data.length)
        
        for i in 0..<data.length {
            ptr[i] = 255 - ptr[i]
        }
        
        return data as Data
    }
    
    func image(index: Int) -> UIImage {
        return image(data: sampleInverse(index: index), width: imageSize.width, height: imageSize.height)
    }
    
    func invertedImage(index: Int) -> UIImage {
        return image(data: sample(index: index), width: imageSize.width, height: imageSize.height)
    }
    
    func transparentImage(index: Int) -> UIImage {
        return transparentImage(data: sample(index: index), width: imageSize.width, height: imageSize.height)
    }
    
    private func image(data: Data, width: Int, height: Int) -> UIImage {
        let grayscale = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGBitmapInfo()
        let dataProvider = CGDataProvider(data: data as CFData)!
        
        let cgimg = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width, space: grayscale, bitmapInfo: bitmapInfo, provider: dataProvider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
        
        return UIImage(cgImage: cgimg)
    }

    private func transparentImage(data: Data, width: Int, height: Int) -> UIImage {
        let rgbData = Data(bytes: data.flatMap { [0, 0, 0, $0] })

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo: CGBitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue)
        let dataProvider = CGDataProvider(data: rgbData as CFData)!

        let cgimg = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: bitmapInfo, provider: dataProvider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        
        return UIImage(cgImage: cgimg)
    }
}


struct MnistLabel {
    
    let reader: MnistReader
    let magic: UInt32
    let count: Int
    
    init?(data: Data?) {
        guard let data = data else { return nil }
        reader = MnistReader(data: data)
        
        magic = reader.int(at: 0)
        guard magic == 0x801 else { return nil }

        count = Int(reader.int(at: 4))
    }
    
    func label(index: Int) -> Int {
        let header = 8
        return Int(reader.byte(at: header + index))
    }
}


class MnistDataset {
    
    lazy var samples: MnistImage = {
        let data = NSDataAsset(name: "t10k-images-idx3-ubyte")?.data
        return MnistImage(data: data)!
    }()

    lazy var labels: MnistLabel = {
        let data = NSDataAsset(name: "t10k-labels-idx1-ubyte")?.data
        return MnistLabel(data: data)!
    }()
}
