//
//  MnistNet.swift
//  mnistios
//
//  Created by Pavel Ivashkov on 2016-09-11.
//  Copyright © 2016 paiv. All rights reserved.
//

import Foundation
import UIKit


class MnistNet {
    
    init() {
        network = MnistNet.setupNetwork()
    }
    
    static let weights: [[Float32]] = MnistNet.readWeights()
    
    let network: BnnsNetwork
    
    private class func readWeights() -> [[Float32]] {
        
        func read(asset: String) -> [Float32]? {
            guard let data = NSDataAsset(name: asset)?.data else { return nil }
            return read(floats: data)
        }
        
        func read(floats: Data) -> [Float32]? {
            var res: [Float32] = Array(repeating: 0, count: floats.count / 4)
            guard floats.copyBytes(to: UnsafeMutableBufferPointer(start: &res, count: res.count)) == floats.count
                else { return nil }
            return res
        }

        let h1_h2_weights = read(asset: "model-h1w-5x5x1x32")!
        let h1_h2_bias = read(asset: "model-h1b-32")!
        let h2_h3_weights = read(asset: "model-h2w-5x5x32x64")!
        let h2_h3_bias = read(asset: "model-h2b-64")!
        let h3_h4_weights = read(asset: "model-h3w-3136x1024")!
        let h3_h4_bias = read(asset: "model-h3b-1024")!
        let h4_y_weights = read(asset: "model-h4w-1024x10")!
        let h4_y_bias = read(asset: "model-h4b-10")!
        
        return [h1_h2_weights, h1_h2_bias,
                h2_h3_weights, h2_h3_bias,
                h3_h4_weights, h3_h4_bias,
                h4_y_weights, h4_y_bias]
    }
    
    private class func setupNetwork() -> BnnsNetwork {
        return BnnsBuilder()
            .shape(width: 28, height: 28, channels: 1)
            .kernel(width: 5, height: 5)
            .convolve(weights: weights[0], bias: weights[1])
            .shape(width: 28, height: 28, channels: 32)
            .maxpool(width: 2, height: 2)
            .shape(width: 14, height: 14, channels: 32)
            .convolve(weights: weights[2], bias: weights[3])
            .shape(width: 14, height: 14, channels: 64)
            .maxpool(width: 2, height: 2)
            .shape(width: 7, height: 7, channels: 64)
            .connect(weights: weights[4], bias: weights[5])
            .shape(size: 1024)
            .connect(weights: weights[6], bias: weights[7])
            .shape(size: 10)
            .build()!
    }
    
    func predict(image: Data) -> Int {
        return predict(input: read(image: image))
    }
    
    func predict(input: [Float32]) -> Int {
        
        let outputs = network.apply(input: input)

        return outputs.index(of: outputs.max()!)!
    }
    
    func predictBatch(images: Data, count: Int) -> [Int] {
        
        let outputs = network
            .batch(input: read(image: images), count: count)
            .map { $0.index(of: $0.max()!)! }

        return outputs
    }

    private func read(image: Data) -> [Float32] {
        return image.map { Float32($0) / 255.0 }
    }
}
