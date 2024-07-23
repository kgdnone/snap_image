package com.example.snap_image

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.os.Bundle
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream


class MainActivity : FlutterActivity() {
    private lateinit var methodChannel: MethodChannel
    private val methodChannelName = "com.example.flutter_app/method_channel"
    private val resultName = "result.png"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        methodChannel =
            MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, methodChannelName)
        methodChannel.setMethodCallHandler { call, result ->
            if (call.method == "snap") {
                val origin = call.argument<String>("origin").toString()
                val mask = call.argument<String>("mask").toString()
                val ret = snapImage(origin, mask)
                result.success(ret)
            }
        }
    }

    /**
     * 扣图
     */
    private fun snapImage(origin: String, mask: String): Map<String, String> {
        try {

            //flutter loader
            val flutterLoader = FlutterInjector.instance().flutterLoader()

            //图片资源的stream
            val originInputSteam = assets.open(flutterLoader.getLookupKeyForAsset(origin))
            val maskInputSteam = assets.open(flutterLoader.getLookupKeyForAsset(mask))

            //图片
            val originBitmap = BitmapFactory.decodeStream(originInputSteam)
            val maskBitmap = BitmapFactory.decodeStream(maskInputSteam)

            //结果图片
            val resultBitmap =
                Bitmap.createBitmap(maskBitmap.width, maskBitmap.height, maskBitmap.config)

            //存储图片像素的数组
            val pixelsOrigin = IntArray(originBitmap.width * originBitmap.height)
            val pixelsMask = IntArray(maskBitmap.width * maskBitmap.height)
            val pixelsResult = IntArray(resultBitmap.width * resultBitmap.height)

            //图片的像素
            originBitmap.getPixels(
                pixelsOrigin, 0, originBitmap.width, 0, 0, originBitmap.width, originBitmap.height
            )
            maskBitmap.getPixels(
                pixelsMask, 0, maskBitmap.width, 0, 0, maskBitmap.width, maskBitmap.height
            )


            // 遍历遮罩的像素，是否为白色。
            // 如果是，将源图的像素复制到结果图中
            // 如果不是，计算一个新的像素，并复制到结果图中
            for (y in 0 until maskBitmap.height) {
                for (x in 0 until maskBitmap.width) {
                    val index = y * maskBitmap.width + x
                    val maskPixel = pixelsMask[index]
                    if (isWhitePixel(maskPixel)) {
                        pixelsResult[index] = pixelsOrigin[index]
                    } else {
                        pixelsResult[index] = blendPixel(
                            x,
                            y,
                            maskBitmap.width,
                            maskBitmap.height,
                            pixelsOrigin,
                            pixelsMask
                        )
                    }
                }
            }

            resultBitmap.setPixels(
                pixelsResult, 0, resultBitmap.width, 0, 0, resultBitmap.width, resultBitmap.height
            )

            val ret = saveImage(resultBitmap)
            return mapOf("status" to "success", "data" to ret)

        } catch (e: Exception) {
            return mapOf("status" to "error", "data" to e.message.toString())
        }
    }

    /**
     * 判断像素是否为白色
     */
    private fun isWhitePixel(pixel: Int): Boolean {
        return Color.alpha(pixel) == 255 && Color.red(pixel) == 255 && Color.green(pixel) == 255 && Color.blue(
            pixel
        ) == 255
    }


    /**
     * 计算一个新的像素
     * 大概逻辑：计算遮罩当前像素点与周围80个像素点，是否白色。
     * 如果不是，那就将这81个像素点的透明度、RGB值相加，然后计算出平均值
     */
    private fun blendPixel(
        x: Int,
        y: Int,
        width: Int,
        height: Int,
        pixelsOrigin: IntArray,
        pixelsMask: IntArray,
    ): Int {
        var alphaSum = 0
        var redSum = 0
        var greenSum = 0
        var blueSum = 0
        var pixelCount = 0

        // 计算当前像素周围的像素
        for (dy in -4..4) {
            for (dx in -4..4) {
                val nx = x + dx
                val ny = y + dy
                //判断是否越界
                if (nx in 0 until width && ny >= 0 && ny < height) {
                    //获取附近像素点在数组中的索引
                    val nearIndex = ny * width + nx
                    //遮罩图附近像素点
                    val nearMaskPixel = pixelsMask[nearIndex]
                    //如果不是白色
                    if (!isWhitePixel(nearMaskPixel)) {
                        //源图附近像素点
                        val nearOriginPixel = pixelsOrigin[nearIndex]
                        //将透明度、RGB值相加
                        alphaSum += Color.alpha(nearOriginPixel)
                        redSum += Color.red(nearOriginPixel)
                        greenSum += Color.green(nearOriginPixel)
                        blueSum += Color.blue(nearOriginPixel)
                        pixelCount++
                    }
                } else {
                    //越界，直接返回透明，这是边界，不用模糊
                    return Color.TRANSPARENT
                }
            }
        }

        //0个不用算，直接返回，如果周围都是黑的，也不用算，直接返回透明
        if (pixelCount == 0 || pixelCount == 81) {
            return Color.TRANSPARENT
        }

        //计算平均值
        val alphaAvg = alphaSum / pixelCount
        val redAvg = redSum / pixelCount
        val greenAvg = greenSum / pixelCount
        val blueAvg = blueSum / pixelCount

        return Color.argb(alphaAvg, redAvg, greenAvg, blueAvg)
    }

    /**
     * 保存图片
     */
    private fun saveImage(bitmap: Bitmap): String {
        val director = application.filesDir.absolutePath
        val file = File(director, resultName)
        var fos: FileOutputStream? = null
        try {
            fos = FileOutputStream(file)
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, fos)
            fos.flush()
            return file.absolutePath
        } catch (e: Exception) {
            return e.message.toString()
        } finally {
            fos?.close()
        }
    }
}
