import Foundation
import AppKit

let MinstImageFile = "t10k-images-idx3-ubyte"
let MinstLabelFile = "t10k-labels-idx1-ubyte"
let ImageSamplePng = "sample.png"


struct MnistReader {
    let data: NSData

    init(data: NSData) {
        self.data = data
    }

    func int(at location: Int) -> UInt32 {
        var value: UInt32 = 0
        data.getBytes(&value, range: NSRange(location: location, length: 4))
        return CFSwapInt32BigToHost(value)
    }

    func bytes(range: NSRange) -> NSData {
        return data.subdata(with: range) as NSData
    }

    func byte(at location: Int) -> UInt8 {
        let ptr = data.bytes.bindMemory(to: UInt8.self, capacity: data.length)
        return ptr[location]
    }
}


struct MnistImage {

    let reader: MnistReader
    var magic: UInt32
    var count: Int
    let imageSize: (width: Int, height: Int)

    init?(data: NSData?) {
        guard let data = data else { return nil }
        reader = MnistReader(data: data)

        magic = reader.int(at: 0)
        count = Int(reader.int(at: 4))
        let w = Int(reader.int(at: 8))
        let h = Int(reader.int(at: 12))
        imageSize = (width: w, height: h)
    }

    init?(file: String) {
        self.init(data: NSData(contentsOfFile: file))
        guard magic == 0x803 else { return nil }
    }

    func sample(index: Int) -> NSData {
        let stride = imageSize.width * imageSize.height
        let header = 16
        return reader.bytes(range: NSRange(location: header + stride * index, length: stride))
    }

    func sampleInverse(index: Int) -> NSData {
        let data = NSMutableData(data: sample(index: index) as Data)

        let ptr = data.mutableBytes.bindMemory(to: UInt8.self, capacity: data.length)

        for i in 0..<data.length {
            ptr[i] = 255 - ptr[i]
        }

        return data
    }

    func image(index: Int) -> NSImage {
        let grayscale = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGBitmapInfo()
        let dataProvider = CGDataProvider(data: sampleInverse(index: index))!

        let cgimg = CGImage(width: imageSize.width, height: imageSize.height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: imageSize.width, space: grayscale, bitmapInfo: bitmapInfo, provider: dataProvider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!

        let image = NSImage(cgImage: cgimg, size: NSSize(width: imageSize.width, height: imageSize.height))

        return image
    }
}

extension NSImage {

    func toPNG() -> NSData? {
        guard let tif = tiffRepresentation,
            let rep = NSBitmapImageRep(data: tif) else { return nil }
        return rep.representation(using: .PNG, properties: [:]) as NSData?
    }
}


struct MnistLabel {

    let reader: MnistReader
    var magic: UInt32
    var count: Int

    init?(data: NSData?) {
        guard let data = data else { return nil }
        reader = MnistReader(data: data)

        magic = reader.int(at: 0)
        count = Int(reader.int(at: 4))
    }

    init?(file: String) {
        self.init(data: NSData(contentsOfFile: file))
        guard magic == 0x801 else { return nil }
    }

    func label(index: Int) -> Int {
        let header = 8
        return Int(reader.byte(at: header + index))
    }
}


let args = CommandLine.arguments

if args.count <= 1 {
    print("usage: sample index [filename]")
}
else {
    let sampleIndex = args.count > 1 ? Int(args[1])! : 0
    let exportFile = args.count > 2 ? args[2] : ImageSamplePng

    let data = MnistImage(file: MinstImageFile)!
    let labels = MnistLabel(file: MinstLabelFile)!

    let img = data.image(index: sampleIndex)
    let lbl = labels.label(index: sampleIndex)

    print(lbl)
    let png = img.toPNG()
    png?.write(toFile: exportFile, atomically: true)
}
