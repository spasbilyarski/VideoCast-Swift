//
//  VCPreviewView.swift
//  VideoCast
//
//  Created by Tomohiro Matsuzawa on 2018/01/05.
//  Copyright © 2018年 CyberAgent, Inc. All rights reserved.
//

import UIKit

open class VCPreviewView: UIImageView {
    
    var paused = Atomic(false)

    public var flipX = false
    
    public var aspectMode: VCAspectMode {
        set {
            switch newValue {
            case .fill:
                contentMode = .scaleAspectFill
            case .fit:
                contentMode = .scaleAspectFit
            }
        }
        get {
            contentMode == .scaleAspectFit ? .fit : .fill
        }
    }

    public var isRotatingWithOrientation = false
    
    private lazy var ciContext = CIContext(options: nil)
    
    private let drawingQueue = DispatchQueue(label: "openfresh.videocast.drawingQueue")

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configure()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    open func drawFrame(_ pixelBuffer: CVPixelBuffer) {
        guard !paused.value else {
            return
        }
        
        drawingQueue.async { [weak self] in
            guard let `self` = self else {
                return
            }
            
            var ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            
            let size = CGSize(width: CGFloat(CVPixelBufferGetWidth(pixelBuffer)), height: CGFloat(CVPixelBufferGetHeight(pixelBuffer)))
            var rect = CGRect(origin: .zero, size: size)
            
            if self.isRotatingWithOrientation {
                let orientation = UIDevice.current.orientation
                let imageOrientation: CGImagePropertyOrientation
                
                switch orientation {
                case .landscapeLeft:
                    imageOrientation = self.flipX ? .rightMirrored : .right
                case .landscapeRight:
                    imageOrientation = self.flipX ? .leftMirrored : .left
                default:
                    imageOrientation = .up
                }
                
                ciImage = ciImage.oriented(forExifOrientation: Int32(imageOrientation.rawValue))
                
                if orientation.isLandscape {
                    rect = CGRect(origin: .zero, size: CGSize(width: size.height, height: size.width))
                }
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let `self` = self else {
                    return
                }
                
                EAGLContext.setCurrent(nil)
                
                guard let cgImage = self.ciContext.createCGImage(ciImage, from: rect) else {
                    return
                }

                let uiImage = UIImage(cgImage: cgImage)
                self.image = uiImage
            }
        }
    }
}

private extension VCPreviewView {
    
    func configure() {
        contentMode = .scaleAspectFit
        autoresizingMask = [.flexibleWidth, .flexibleHeight]

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationDidEnterBackground),
                                               name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationWillEnterForeground),
                                               name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    @objc func applicationDidEnterBackground() {
        paused.value = true
    }

    @objc func applicationWillEnterForeground() {
        paused.value = false
    }

}
