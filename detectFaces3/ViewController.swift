//
//  ViewController.swift
//  detectFaces3
//
//  Created by yuki on 2015/07/25.
//  Copyright (c) 2015年 higegiraffe. All rights reserved.
//

import UIKit
import GLKit
import AVFoundation

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    var videoDisplayView: GLKView!
    var videoDisplayViewRect: CGRect!
    var renderContext: CIContext!
    var cpsSession: AVCaptureSession!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(animated: Bool) {
        //画面の生成
        self.initDisplay()
        
        // カメラの使用準備.
        self.initCamera()
        
    }
    
    override func viewDidDisappear(animated: Bool) {
        // カメラの停止とメモリ解放.
        self.cpsSession.stopRunning()
        for output in self.cpsSession.outputs
        {
            self.cpsSession.removeOutput(output as! AVCaptureOutput)
        }
        for input in self.cpsSession.inputs
        {
            self.cpsSession.removeInput(input as! AVCaptureInput)
        }
        self.cpsSession = nil
    }
    
    func initDisplay()
    {
        videoDisplayView = GLKView(frame: view.bounds, context: EAGLContext(API: .OpenGLES2))
        videoDisplayView.transform = CGAffineTransformMakeRotation(CGFloat(M_PI_2))
        videoDisplayView.frame = view.bounds
        view.addSubview(videoDisplayView)
        
        renderContext = CIContext(EAGLContext: videoDisplayView.context)
        videoDisplayView.bindDrawable()
        videoDisplayViewRect = CGRect(x: 0, y: 0, width: videoDisplayView.drawableWidth, height: videoDisplayView.drawableHeight)
    }
    
    func initCamera() {
        //カメラからの入力を作成
        var captureDevice: AVCaptureDevice!
        
        //背面カメラの検索
        for device: AnyObject in AVCaptureDevice.devices()
        {
            if device.position == AVCaptureDevicePosition.Front
            {
                captureDevice = device as! AVCaptureDevice
            }
        }
        
        //入力データの取得
        var deviceInput: AVCaptureDeviceInput = AVCaptureDeviceInput.deviceInputWithDevice(captureDevice, error: nil) as! AVCaptureDeviceInput
        
        //出力データの取得
        var videoDataOutput:AVCaptureVideoDataOutput = AVCaptureVideoDataOutput()
        
        //カラーチャンネルの設定
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey : kCVPixelFormatType_32BGRA]
        
        //画像をキャプチャするキューを指定
        videoDataOutput.setSampleBufferDelegate(self, queue: dispatch_get_main_queue())
        
        //キューがブロックされているときに新しいフレームが来たら削除
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        
        //セッションの使用準備
        self.cpsSession = AVCaptureSession()
        
        //Input
        if(self.cpsSession.canAddInput(deviceInput))
        {
            self.cpsSession.addInput(deviceInput as AVCaptureDeviceInput)
        }
        //Output
        if(self.cpsSession.canAddOutput(videoDataOutput))
        {
            self.cpsSession.addOutput(videoDataOutput)
        }
        //解像度の指定
        self.cpsSession.sessionPreset = AVCaptureSessionPresetMedium
        
        self.cpsSession.startRunning()
    }
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        //SampleBufferから画像を取得
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let opaqueBuffer = Unmanaged<CVImageBuffer>.passUnretained(imageBuffer).toOpaque()
        let pixelBuffer = Unmanaged<CVPixelBuffer>.fromOpaque(opaqueBuffer).takeUnretainedValue()
        let outputImage = CIImage(CVPixelBuffer: pixelBuffer, options: nil)
        
        //補正
        var drawFrame = outputImage.extent()
        let imageAR = drawFrame.width / drawFrame.height
        let viewAR = videoDisplayViewRect.width / videoDisplayViewRect.height
        if imageAR > viewAR {
            drawFrame.origin.x += (drawFrame.width - drawFrame.height * viewAR) / 2.0
            drawFrame.size.width = drawFrame.height / viewAR
        } else {
            drawFrame.origin.y += (drawFrame.height - drawFrame.width / viewAR) / 2.0
            drawFrame.size.height = drawFrame.width / viewAR
        }
        
        //出力
        videoDisplayView.bindDrawable()
        if videoDisplayView.context != EAGLContext.currentContext() {
            EAGLContext.setCurrentContext(videoDisplayView.context)
        }
        renderContext.drawImage(outputImage, inRect: videoDisplayViewRect, fromRect: drawFrame)
        videoDisplayView.display()
        
        // NSDictionary型のoptionを生成。顔認識の精度を追加する.
        var options : NSDictionary = NSDictionary(object: CIDetectorAccuracyHigh, forKey: CIDetectorAccuracy)
        
        // CIDetectorを生成。顔認識をするのでTypeはCIDetectorTypeFace.
        let detector : CIDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: options as [NSObject : AnyObject])
        
        // detectorで認識した顔のデータを入れておくNSArray.
        var faces : NSArray = detector.featuresInImage(outputImage, options: options as [NSObject : AnyObject])
        
        // UIKitは画面左上に原点があるが、CoreImageは画面左下に原点があるのでそれを揃えなくてはならない.
        // CoreImageとUIKitの原点を画面左上に統一する処理.
        var transform : CGAffineTransform = CGAffineTransformMakeScale(1, -1)
        transform = CGAffineTransformTranslate(transform, 0, -videoDisplayView.bounds.size.height)
        
        // 検出された顔のデータをCIFaceFeatureで処理.
        var feature : CIFaceFeature = CIFaceFeature()
        for feature in faces {
            
            // 座標変換.
            let faceRect : CGRect = CGRectApplyAffineTransform(feature.bounds, transform)
            
            // 画像の顔の周りを線で囲うUIViewを生成.
            var faceOutline = UIView(frame: faceRect)
            faceOutline.layer.borderWidth = 1
            faceOutline.layer.borderColor = UIColor.redColor().CGColor
            videoDisplayView.addSubview(faceOutline)
            
        }
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}