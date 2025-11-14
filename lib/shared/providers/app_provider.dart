import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppProvider extends ChangeNotifier {
  List<String> allMedia = [];

  setMedia(String allMediax) {
    allMedia.add(allMediax);
    notifyListeners();
  }
}
