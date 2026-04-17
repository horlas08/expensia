import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/models/person_model.dart';

final personsProvider = AsyncNotifierProvider<PersonsNotifier, List<Person>>(PersonsNotifier.new);

class PersonsNotifier extends AsyncNotifier<List<Person>> {
  @override
  Future<List<Person>> build() async {
    return _fetchPersons();
  }

  Future<List<Person>> _fetchPersons() async {
    final results = await DatabaseService().getPersons();
    return results.map((m) => Person.fromMap(m)).toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchPersons());
  }

  Future<void> addPerson(String name, String? phone) async {
    await DatabaseService().addPerson(name, phone);
    await refresh();
  }

  Future<void> updatePerson(int id, String name, String? phone) async {
    await DatabaseService().updatePerson(id, name, phone);
    await refresh();
  }

  Future<void> deletePerson(int id) async {
    await DatabaseService().deletePerson(id);
    await refresh();
  }

  Future<bool> hasDependencies(int id) async {
    return await DatabaseService().hasPersonDependencies(id);
  }

  Future<int> syncFromDeviceOnOpen() async => importFromDevice();

  Future<int> importFromDevice() async {
    // 1. Request Permission
    if (!await FlutterContacts.requestPermission()) {
      throw Exception('Contacts permission denied');
    }

    // 2. Fetch Contacts with properties
    final contacts = await FlutterContacts.getContacts(withProperties: true);
    if (contacts.isEmpty) return 0;

    // 3. Prepare for batch insert
    final List<Map<String, String>> toImport = [];
    final existing = state.value ?? [];
    
    // Map existing by both normalized name and phone
    final existingPhones = existing
        .where((p) => p.phone != null)
        .map((p) => _normalizePhone(p.phone))
        .toSet();
    final existingNames = existing.map((p) => p.name.trim().toLowerCase()).toSet();

    for (final contact in contacts) {
      final name = contact.displayName.trim();
      if (name.isEmpty) continue;

      // Extract and normalize the first primary/mobile phone
      String? rawPhone;
      if (contact.phones.isNotEmpty) {
        // Prefer mobile if available
        final mobile = contact.phones.firstWhere(
          (p) => p.label == PhoneLabel.mobile,
          orElse: () => contact.phones.first,
        );
        rawPhone = mobile.number;
      }

      final normalizedPhone = _normalizePhone(rawPhone);

      // Skip if exactly same name or same phone exists
      if (existingNames.contains(name.toLowerCase())) continue;
      if (normalizedPhone.isNotEmpty && existingPhones.contains(normalizedPhone)) continue;

      toImport.add({
        'name': name,
        'phone': rawPhone ?? '',
      });
      
      // Update local sets to avoid duplicates within the import batch itself
      existingNames.add(name.toLowerCase());
      if (normalizedPhone.isNotEmpty) existingPhones.add(normalizedPhone);
    }

    if (toImport.isNotEmpty) {
      await DatabaseService().importDeviceContacts(toImport);
      await refresh();
    }
    
    return toImport.length;
  }

  String _normalizePhone(String? phone) {
    if (phone == null) return '';
    // Strip all non-numeric characters for comparison (including +)
    // This makes "+1(234)" match "1234"
    return phone.replaceAll(RegExp(r'\D'), '');
  }
}

final personsSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredPersonsProvider = Provider<AsyncValue<List<Person>>>((ref) {
  final personsAsync = ref.watch(personsProvider);
  final query = ref.watch(personsSearchQueryProvider).toLowerCase();

  return personsAsync.whenData((persons) {
    if (query.isEmpty) return persons;
    return persons.where((p) {
      return p.name.toLowerCase().contains(query) || 
             (p.phone?.toLowerCase().contains(query) ?? false);
    }).toList();
  });
});
