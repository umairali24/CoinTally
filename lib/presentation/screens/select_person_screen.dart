import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cointally/presentation/notifiers/person_notifier.dart';
import 'package:cointally/presentation/screens/lend_borrow_screen.dart';
import 'package:cointally/presentation/screens/add_person_screen.dart';
import 'package:cointally/presentation/widgets/sleek_components.dart';

class SelectPersonScreen extends ConsumerStatefulWidget {
  const SelectPersonScreen({super.key});

  @override
  ConsumerState<SelectPersonScreen> createState() => _SelectPersonScreenState();
}

class _SelectPersonScreenState extends ConsumerState<SelectPersonScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final personState = ref.watch(personProvider);
    final filteredPersons = personState.persons.where((p) => 
      p.name.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Select Person', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: SleekTextField(
              label: 'Search Person',
              controller: _searchController,
              hintText: 'Type a name...',
              prefixIcon: Icons.search_rounded,
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          
          Expanded(
            child: personState.isLoading 
              ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
              : filteredPersons.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: filteredPersons.length,
                    itemBuilder: (context, index) {
                      final person = filteredPersons[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: PremiumCard(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LendBorrowScreen(person: person, initialType: 'LEND'),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                child: Text(
                                  person.name[0].toUpperCase(),
                                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      person.name,
                                      style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 16),
                                    ),
                                    if (person.phoneNumber != null)
                                      Text(
                                        person.phoneNumber!,
                                        style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.3)),
                                      ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white24),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(24),
            child: SleekButton(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddPersonScreen()),
              ),
              label: 'Add New Person',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_rounded, size: 48, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'No people added yet' : 'No match found',
            style: GoogleFonts.manrope(color: Colors.white.withOpacity(0.3), fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
