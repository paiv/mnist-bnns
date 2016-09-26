//
//  CanvasView.swift
//  mnistios
//
//  Created by Pavel Ivashkov on 2016-09-25.
//  Copyright © 2016 paiv. All rights reserved.
//

import UIKit


protocol CanvasViewDelegate : class {
    func canvasViewDidFinishDrawing(canvas: CanvasView)
    func canvasViewDidClear(canvas: CanvasView)
}


class CanvasView: UIView {
    
    weak var delegate: CanvasViewDelegate?
    
    func clear() {
        bufferImage = nil
        lastPoint = nil
        paint(touches: [])
        delegate?.canvasViewDidClear(canvas: self)
    }
    
    func getImage() -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(bounds.size, false, 1)
        defer {
            UIGraphicsEndImageContext()
        }
        
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        layer.render(in: context)
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        paint(touches: touches)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        
        paint(touches: touches)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        paint(touches: touches)
        lastPoint = nil
        
        delegate?.canvasViewDidFinishDrawing(canvas: self)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
    }
    

    private var bufferImage: UIImage?
    private var brushImage = #imageLiteral(resourceName: "brush-20")
    private var lastPoint: CGPoint?

    private func paint(touches: Set<UITouch>) {
        autoreleasepool {
            UIGraphicsBeginImageContextWithOptions(bounds.size, true, 0)
            defer {
                UIGraphicsEndImageContext()
            }
            
            guard let context = UIGraphicsGetCurrentContext() else { return }
            
            context.setFillColor(backgroundColor?.cgColor ?? UIColor.white.cgColor)
            context.fill(bounds)
            
            if let image = bufferImage {
                image.draw(in: bounds)
            }
            
            for touch in touches {
                let point = touch.location(in: self)
                paint(from: lastPoint, to: point)
                lastPoint = point
            }
 
            bufferImage = UIGraphicsGetImageFromCurrentImageContext()
        }
        
        layer.contents = bufferImage?.cgImage
    }
    
    private func paint(from: CGPoint?, to: CGPoint) {
        
        guard let from = from else {
            stamp(at: to)
            return
        }
        
        let dx = to.x - from.x
        let dy = to.y - from.y
        let dist = sqrt(dx * dx + dy * dy)
        var stepx: CGFloat = 0
        var stepy: CGFloat = 0
        if dist > 0 {
            stepx = dx / dist
            stepy = dy / dist
        }
        
        var offset = CGPoint.zero
        
        var path = dist
        while path >= 1 {
            stamp(at: CGPoint(x: from.x + offset.x, y: from.y + offset.y))
            offset.x += stepx
            offset.y += stepy
            path -= 1
        }
    }
    
    private func stamp(at point: CGPoint) {
        let size = brushImage.size
        let rect = CGRect(origin: point, size: CGSize.zero).insetBy(dx: -size.width / 2, dy: -size.height / 2)
        brushImage.draw(in: rect)
    }
}
