import 'package:flutter/services.dart';

class Native {
  static Native instance = Native._();

  final _methodChannelName = 'com.example.flutter_app/method_channel';

  late final MethodChannel _methodChannel;

  Native._() {
    _methodChannel = MethodChannel(_methodChannelName);
  }

  Future<Map?> snap({required Map<String, String> param}) async {
    return await _methodChannel.invokeMapMethod('snap', param);
  }
}
