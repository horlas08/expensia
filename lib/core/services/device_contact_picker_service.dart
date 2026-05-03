import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';

import '../models/person_model.dart';

class DeviceContactPickerService {
  DeviceContactPickerService._();

  static final FlutterNativeContactPicker _picker =
      FlutterNativeContactPicker();

  static Future<Person?> pickPerson() async {
    final contact = await _picker.selectPhoneNumber();
    if (contact == null) return null;

    final rawName = (contact.fullName ?? '').trim();
    final rawPhone =
        (contact.selectedPhoneNumber ??
                contact.phoneNumbers?.firstWhere(
                  (phone) => phone.trim().isNotEmpty,
                  orElse: () => '',
                ) ??
                '')
            .trim();

    if (rawName.isEmpty && rawPhone.isEmpty) {
      return null;
    }

    return Person(
      name: rawName.isEmpty ? rawPhone : rawName,
      phone: rawPhone.isEmpty ? null : rawPhone,
    );
  }
}
