import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ContactSaver {
  static const String _firstLaunchKey = 'first_launch';

  static Future<void> checkAndSaveContact() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool(_firstLaunchKey) ?? true;

    if (isFirstLaunch) {
      await _saveContactNumber();
      await prefs.setBool(_firstLaunchKey, false);
    }
  }

  static Future<bool> _saveContactNumber() async {
    // طلب الإذن
    if (await FlutterContacts.requestPermission()) {
      try {
        final contact = Contact()
          ..name.first = 'Globee'
          ..name.last = 'Trading'
          ..phones = [Phone('71402613', label: PhoneLabel.mobile)];

        await contact.insert();
        print('✅ تم حفظ رقم الدعم في جهات الاتصال');
        return true;
      } catch (e) {
        print('❌ خطأ في حفظ جهة الاتصال: $e');
        return false;
      }
    } else {
      print('⚠️ لم يتم السماح بالوصول لجهات الاتصال');
      return false;
    }
  }
}
