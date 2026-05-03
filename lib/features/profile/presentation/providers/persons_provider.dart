import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/models/person_model.dart';

final personsProvider = AsyncNotifierProvider<PersonsNotifier, List<Person>>(
  PersonsNotifier.new,
);

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

  Future<int> syncFromDeviceOnOpen() async {
    return 0;
  }

  Future<Person?> importPickedContact(Person person) async {
    final existing = state.value ?? await _fetchPersons();
    final normalizedIncomingPhone = _normalizePhone(person.phone);
    final normalizedIncomingName = person.name.trim().toLowerCase();

    for (final entry in existing) {
      final sameName =
          entry.name.trim().toLowerCase() == normalizedIncomingName;
      final samePhone =
          normalizedIncomingPhone.isNotEmpty &&
          _normalizePhone(entry.phone) == normalizedIncomingPhone;
      if (sameName || samePhone) {
        return entry;
      }
    }

    final id = await DatabaseService().addPerson(person.name, person.phone);
    await refresh();

    return Person(id: id, name: person.name, phone: person.phone);
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
