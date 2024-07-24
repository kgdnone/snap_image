import UIKit
import Flutter
import CoreGraphics

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    let methodName = "com.example.flutter_app/method_channel"
    let resultName = "result.png"
    var controller: FlutterViewController? = nil
    
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
      
      controller = self.window.rootViewController as? FlutterViewController
      if (controller != nil) {
          let methodChannel = FlutterMethodChannel.init(name: methodName, binaryMessenger: controller!.binaryMessenger)
          methodChannel.setMethodCallHandler({ call, result in
              if (call.method == "snap") {
                  guard let arguments = call.arguments as? [String: Any],
                        let origin = arguments["origin"] as? String,
                            let mask = arguments["mask"] as? String else {
                      result(["status": "error", "data": "param empty"])
                      return
                  }
                  
                  let ret = self.snapImage(origin: origin, mask: mask)
                  result(ret)
              }
          })
      }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
    
    //加载本地图片读到数组里面
    func loadImagePixels(cgImage: CGImage) -> [UInt32] {
        let width = Int(cgImage.width)
        let height = Int(cgImage.height)
        let bytesPerRow = width * 4 //RGBA格式，每个像素4个字节
        let totalBytes = bytesPerRow * height
          
        // 分配内存来存储位图数据
        let pixelData = UnsafeMutablePointer<UInt32>.allocate(capacity: totalBytes / MemoryLayout<UInt32>.size)
        defer { pixelData.deallocate() } // 使用defer确保内存被释放
          
        // 创建位图上下文
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        let context = CGContext(data: pixelData, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)!
          
        // 将CGImage绘制到位图上下文中
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var pixelArray = [UInt32](repeating: 0, count: totalBytes / MemoryLayout<UInt32>.size)
        pixelData.withMemoryRebound(to: UInt32.self, capacity: totalBytes / MemoryLayout<UInt32>.size) {
            let ptr = UnsafeBufferPointer(start: $0, count: totalBytes / MemoryLayout<UInt32>.size)
            pixelArray = Array(ptr)
        }
          
        return pixelArray
    }
    

    //扣图
    func snapImage(origin: String, mask: String) -> [String: String] {
        let mainBundle = Bundle.main
        let originKey = controller!.lookupKey(forAsset: origin)
        let maskKey = controller!.lookupKey(forAsset: mask)
        guard let originFileName = mainBundle.path(forResource: originKey, ofType: nil),
              let maskFileName = mainBundle.path(forResource: maskKey, ofType: nil)
        else {
            return ["status": "error", "data": "file not found"]
        }
        
        
        let originImage = UIImage(named: originFileName)
        let maskImage = UIImage(named: maskFileName)
        
        guard let originCGImage = originImage?.cgImage,
              let maskCGImage = maskImage?.cgImage else {
            return ["status": "error", "data": "file not found"]
        }
        
        let originArray = loadImagePixels(cgImage: originCGImage)
        let maskArray = loadImagePixels(cgImage: maskCGImage)
        
        
        let resultArray = UnsafeMutablePointer<UInt32>.allocate(capacity: originArray.count / MemoryLayout<UInt32>.size)
        defer { resultArray.deallocate() } // 使用defer确保内存被释放
        
        for index in maskArray.indices {
            let maskPixel = maskArray[index]
            if (isWhitePixel(maskPixel)) {
                resultArray[index] = originArray[index]
            } else {
                //太耗时，去掉
//                resultArray[index] = blendPixel(x: index % maskCGImage.width, y: index / maskCGImage.width, width: maskCGImage.width, height: maskCGImage.height, originPixels: originArray, maskPixels: maskArray)
            }
        }
        
        
        let fileName = saveImage(resultArray, maskCGImage.width, maskCGImage.height)
        if (fileName.isEmpty) {
            return ["status": "error", "data": "save file error"]
        }
            
        return ["status": "succeed", "data": fileName]
    }
    
    func saveImage(_ data: UnsafeMutablePointer<UInt32>, _ width: Int, _ height: Int) -> String {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerRow = width * 4
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue).union(.byteOrder32Big)
        let context = CGContext(data: data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)!
        guard let cgImage = context.makeImage() else { return "" }
        let uiImage = UIImage(cgImage: cgImage)
        
        guard let data = uiImage.pngData() else {
            return ""
        }
              
        let documentsDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectoryURL.appendingPathComponent("result.png")
              
        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            return ""
        }
    
        
        return fileURL.path
    }
    
    /**
     * 计算一个新的像素
     * 大概逻辑：计算遮罩当前像素点与周围80个像素点，是否白色。
     * 如果不是，那就将这81个像素点的透明度、RGB值相加，然后计算出平均值
     */
    func blendPixel(
        x: Int,
        y: Int,
        width: Int,
        height: Int,
        originPixels: [UInt32],
        maskPixels: [UInt32]
    ) -> UInt32 {
        var alphaSum: UInt32 = 0
        var redSum: UInt32 = 0
        var greenSum: UInt32 = 0
        var blueSum: UInt32 = 0
        var pixelCount: Int32 = 0
      
        let kernelRadius = 1
        let kernelSize = (2 * kernelRadius + 1) * (2 * kernelRadius + 1)
      
        print("blend-->start:", Date().timeIntervalSince1970)
        
        for dy in -kernelRadius...kernelRadius {
            for dx in -kernelRadius...kernelRadius {
                let nx = x + dx
                let ny = y + dy
      
                // 检查是否越界
                guard nx >= 0, nx < width, ny >= 0, ny < height else {
                   //如果越界，返回透明
                    return 0// Transparent
                }
      
                //注意，数组里，每四个数字为一组，组成argb
                let nearIndex = ny * width + nx
                
                // 检查遮罩像素点是否为非白色
                if !isWhitePixel(maskPixels[nearIndex]) {
                    let (a, r, g, b) = deconstructARGB(originPixels[nearIndex])
                    // 累加
                    alphaSum += a
                    redSum += r
                    greenSum += g
                    blueSum += b
                    pixelCount += 1
                }
            }
        }
      
        // 如果周围都是白色或没有非白色像素，返回透明
        if pixelCount == 0 || pixelCount == kernelSize {
            return 0 // Transparent
        }
      
        // 计算平均值
        let alphaAvg = alphaSum / UInt32(pixelCount)
        let redAvg = redSum / UInt32(pixelCount)
        let greenAvg = greenSum / UInt32(pixelCount)
        let blueAvg = blueSum / UInt32(pixelCount)
        
        print("blend-->over:", Date().timeIntervalSince1970)
        return constructARGB(redAvg, greenAvg, blueAvg, alphaAvg)
    }
      
    //判断是否白色
    func isWhitePixel(_ a: UInt32, _ r: UInt32, _ g: UInt32, _ b:UInt32) -> Bool {
        // 这里可以设置一个容差值来判断颜色是否“足够白”
        return a == 255 && r > 240 && g > 240 && b > 240
    }
    
    
    func deconstructARGB(_ argb: UInt32) -> (alpha: UInt32, red: UInt32, green: UInt32, blue: UInt32) {
        let alpha = (argb >> 24) & 0xFF
        let red = (argb >> 16) & 0xFF
        let green = (argb >> 8) & 0xFF
        let blue = argb & 0xFF
        return (alpha, red, green, blue)
    }
      
    func constructARGB(_ red: UInt32, _ green: UInt32, _ blue: UInt32, _ alpha: UInt32) -> UInt32 {
        return (alpha << 24) | (red << 16) | (green << 8 | blue)
    }
      
    // Function to check if a pixel is white (with a tolerance, if needed)
    func isWhitePixel(_ pixel: UInt32) -> Bool {
        let (r, g, b, a) = deconstructARGB(pixel)
        // 这里可以设置一个容差值来判断颜色是否“足够白”
        return a == 255 && r > 230 && g > 230 && b > 230 // 示例容差
    }
}
