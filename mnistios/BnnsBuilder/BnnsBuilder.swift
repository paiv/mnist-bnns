//
//  BnnsBuilder.swift
//
//  Created by Pavel Ivashkov, paiv on 2016-09-18.
//
//  MIT License
//  Copyright © 2016 Pavel Ivashkov. All rights reserved.
//

import Accelerate


struct BnnsShape {
    let width: Int
    let height: Int
    let channels: Int
    
    var size: Int {
        get {
            return width * height * channels
        }
    }
}


class BnnsFilter {
    let filter: BNNSFilter
    let shape: BnnsShape
    
    init(filter: BNNSFilter, shape: BnnsShape) {
        self.filter = filter
        self.shape = shape
    }
    
    deinit {
        BNNSFilterDestroy(filter)
    }
}


struct BnnsNetwork {
    let network: [BnnsFilter]
    
    func apply(input: [Float32]) -> [Float32] {
        var outputs = input
        
        for layer in network {
            let inputs = outputs
            outputs = Array(repeating: 0, count: layer.shape.size)
            
            guard BNNSFilterApply(layer.filter, inputs, &outputs) == 0
                else { return [] }
        }
        
        return outputs
    }
    
    func batch(input: [Float32], count: Int) -> [[Float32]] {
        var outputs = input
        var outputStride = input.count / count
        
        for layer in network {
            let inputs = outputs
            let inputStride = outputStride
            
            outputs = Array(repeating: 0, count: layer.shape.size * count)
            outputStride = layer.shape.size
            
            guard BNNSFilterApplyBatch(layer.filter, count, inputs, inputStride, &outputs, outputStride) == 0
                else { return [] }
        }
        
        var result: [[Float32]] = []
        outputStride = outputs.count / count
        
        for row in 0..<count {
            let res = Array(outputs[outputStride * row ..< outputStride * (row + 1)])
            result.append(res)
        }
        
        return result
    }
}

class BnnsBuilder {
    
    var dataType: BNNSDataType {
        get {
            return BNNSDataType.float
        }
    }
    
    private var descriptors: [LayerDescriptor] = []
    
    private var inputShape: BnnsShape!
    private var kernel: (width: Int, height: Int)!
    private var stride = (x: 1, y: 1)
    private var activation = BNNSActivationFunction.rectifiedLinear
    
    func shape(width: Int, height: Int, channels: Int) -> Self {
        let shape = BnnsShape(width: width, height: height, channels: channels)
        inputShape = shape
        
        if let lastFilter = descriptors.last {
            lastFilter.output = shape
        }
        
        return self
    }
    
    func shape(size: Int) -> Self {
        return shape(width: size, height: 1, channels: 1)
    }
    
    func kernel(width: Int, height: Int) -> Self {
        kernel = (width: width, height: height)
        return self
    }
    
    func stride(x: Int, y: Int) -> Self {
        stride = (x: x, y: y)
        return self
    }
    
    func activation(function: BNNSActivationFunction) -> Self {
        activation = function
        return self
    }
    
    func convolve(weights: [Float32], bias: [Float32]) -> Self {
        let desc = ConvolutionLayerDescriptor()
        desc.dataType = dataType
        desc.input = inputShape
        desc.kernel = kernel
        desc.stride = stride
        desc.weights = weights
        desc.bias = bias
        desc.activation = activation
        
        descriptors.append(desc)
        return self
    }
    
    func maxpool(width: Int, height: Int) -> Self {
        let desc = MaxPoolingLayerDescriptor()
        desc.dataType = dataType
        desc.input = inputShape
        desc.kernel = (width: width, height: height)
        
        descriptors.append(desc)
        return self
    }
    
    func connect(weights: [Float32], bias: [Float32]) -> Self {
        let desc = FullyConnectedLayerDescriptor()
        desc.dataType = dataType
        desc.input = inputShape
        desc.weights = weights
        desc.bias = bias
        desc.activation = activation
        
        descriptors.append(desc)
        return self
    }
    
    func build() -> BnnsNetwork? {
        let building = descriptors.map { $0.build() }
        let network = building.flatMap{$0}
        
        guard network.count == building.count else { return nil }
        
        return BnnsNetwork(network: network)
    }
    
    
    private class LayerDescriptor {
        var dataType: BNNSDataType!
        var input: BnnsShape!
        var output: BnnsShape!
        
        func build() -> BnnsFilter? {
            return nil
        }
    }
    
    private class ConvolutionLayerDescriptor : LayerDescriptor {
        var kernel: (width: Int, height: Int)!
        var stride: (x: Int, y: Int)!
        var weights: [Float32]!
        var bias: [Float32]!
        var activation: BNNSActivationFunction!
        
        override func build() -> BnnsFilter? {
            
            let x_padding: Int = (stride.x * (output.width - 1) + kernel.width - input.width) / 2
            let y_padding: Int = (stride.y * (output.height - 1) + kernel.height - input.height) / 2
            let pad = (x: x_padding, y: y_padding)
            
            var imageStackIn = BNNSImageStackDescriptor(width: input.width, height: input.height, channels: input.channels, row_stride: input.width, image_stride: input.width * input.height, data_type: dataType, data_scale: 0, data_bias: 0)
            
            var imageStackOut = BNNSImageStackDescriptor(width: output.width, height: output.height, channels: output.channels, row_stride: output.width, image_stride: output.width * output.height, data_type: dataType, data_scale: 0, data_bias: 0)
            
            let weights_data = BNNSLayerData(data: weights, data_type: dataType, data_scale: 0, data_bias: 0, data_table: nil)
            let bias_data = BNNSLayerData(data: bias, data_type: dataType, data_scale: 0, data_bias: 0, data_table: nil)
            let activ = BNNSActivation(function: activation, alpha: 0, beta: 0)
            
            var layerParams = BNNSConvolutionLayerParameters(x_stride: stride.x, y_stride: stride.y, x_padding: pad.x, y_padding: pad.y, k_width: kernel.width, k_height: kernel.height, in_channels: input.channels, out_channels: output.channels, weights: weights_data, bias: bias_data, activation: activ)
            
            var filterParams = defaultFilterParameters()
            
            guard let convolve = BNNSFilterCreateConvolutionLayer(&imageStackIn, &imageStackOut, &layerParams, &filterParams)
                else { return nil }
            
            return BnnsFilter(filter: convolve, shape: output)
        }
    }
    
    private class MaxPoolingLayerDescriptor : LayerDescriptor {
        var kernel: (width: Int, height: Int)!
        
        override func build() -> BnnsFilter? {
            
            let stride = (x: kernel.width, y: kernel.height)
            
            let x_padding: Int = (stride.x * (output.width - 1) + kernel.width - input.width) / 2
            let y_padding: Int = (stride.y * (output.height - 1) + kernel.height - input.height) / 2
            let pad = (x: x_padding, y: y_padding)
            
            var imageStackIn = BNNSImageStackDescriptor(width: input.width, height: input.height, channels: input.channels, row_stride: input.width, image_stride: input.width * input.height, data_type: dataType, data_scale: 0, data_bias: 0)
            
            var imageStackOut = BNNSImageStackDescriptor(width: output.width, height: output.height, channels: output.channels, row_stride: output.width, image_stride: output.width * output.height, data_type: dataType, data_scale: 0, data_bias: 0)
            
            let bias_data = BNNSLayerData()
            let activ = BNNSActivation(function: BNNSActivationFunction.identity, alpha: 0, beta: 0)
            
            var layerParams = BNNSPoolingLayerParameters(x_stride: stride.x, y_stride: stride.y, x_padding: pad.x, y_padding: pad.y, k_width: kernel.width, k_height: kernel.height, in_channels: input.channels, out_channels: output.channels, pooling_function: BNNSPoolingFunction.max, bias: bias_data, activation: activ)
            
            var filterParams = defaultFilterParameters()
            
            guard let pool = BNNSFilterCreatePoolingLayer(&imageStackIn, &imageStackOut, &layerParams, &filterParams)
                else { return nil }
            
            return BnnsFilter(filter: pool, shape: output)
        }
    }
    
    private class FullyConnectedLayerDescriptor : LayerDescriptor {
        var weights: [Float32]!
        var bias: [Float32]!
        var activation: BNNSActivationFunction!
        
        override func build() -> BnnsFilter? {
            
            var hiddenIn = BNNSVectorDescriptor(size: input.size, data_type: dataType, data_scale: 0, data_bias: 0)
            var hiddenOut = BNNSVectorDescriptor(size: output.size, data_type: dataType, data_scale: 0, data_bias: 0)
            
            let weights_data = BNNSLayerData(data: weights, data_type: dataType, data_scale: 0, data_bias: 0, data_table: nil)
            let bias_data = BNNSLayerData(data: bias, data_type: dataType, data_scale: 0, data_bias: 0, data_table: nil)
            let activ = BNNSActivation(function: activation, alpha: 0, beta: 0)
            
            var layerParams = BNNSFullyConnectedLayerParameters(in_size: input.size, out_size: output.size, weights: weights_data, bias: bias_data, activation: activ)
            
            var filterParams = defaultFilterParameters()
            
            guard let layer = BNNSFilterCreateFullyConnectedLayer(&hiddenIn, &hiddenOut, &layerParams, &filterParams)
                else { return nil }
            
            return BnnsFilter(filter: layer, shape: output)
        }
    }
}
