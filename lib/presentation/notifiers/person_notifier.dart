import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cointally/data/local/db_helper.dart';
import 'package:cointally/domain/entities/person_entity.dart';

class PersonState {
  final List<PersonEntity> persons;
  final bool isLoading;

  PersonState({this.persons = const [], this.isLoading = false});

  PersonState copyWith({List<PersonEntity>? persons, bool? isLoading}) {
    return PersonState(
      persons: persons ?? this.persons,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class PersonNotifier extends StateNotifier<PersonState> {
  PersonNotifier() : super(PersonState()) {
    loadPersons();
  }

  Future<void> loadPersons() async {
    state = state.copyWith(isLoading: true);
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query('persons', orderBy: 'name ASC');
    final persons = maps.map((m) => PersonEntity.fromMap(m)).toList();
    state = state.copyWith(persons: persons, isLoading: false);
  }

  Future<int> addPerson(PersonEntity person) async {
    final db = await DatabaseHelper.instance.database;
    final id = await db.insert('persons', person.toMap());
    await loadPersons();
    return id;
  }

  Future<void> deletePerson(int id) async {
    final db = await DatabaseHelper.instance.database;
    // Also delete associated debts (simple Cascade simulation)
    await db.delete('debts', where: 'person_id = ?', whereArgs: [id]);
    await db.delete('persons', where: 'id = ?', whereArgs: [id]);
    await loadPersons();
  }
}

final personProvider = StateNotifierProvider<PersonNotifier, PersonState>((ref) {
  return PersonNotifier();
});
