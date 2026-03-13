import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cointally/domain/entities/person_entity.dart';
import 'package:cointally/presentation/notifiers/person_notifier.dart';
import 'package:cointally/presentation/widgets/sleek_components.dart';

class AddPersonScreen extends ConsumerStatefulWidget {
  const AddPersonScreen({super.key});

  @override
  ConsumerState<AddPersonScreen> createState() => _AddPersonScreenState();
}

class _AddPersonScreenState extends ConsumerState<AddPersonScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isSaving = false;

  Future<void> _pickFromContacts() async {
    final status = await Permission.contacts.request();
    if (status.isGranted) {
      final contact = await FlutterContacts.openExternalPick();
      if (contact != null) {
        setState(() {
          _nameController.text = contact.displayName;
          if (contact.phones.isNotEmpty) {
            _phoneController.text = contact.phones.first.number;
          }
        });
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contacts permission is required to pick from list.')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (_nameController.text.isEmpty) return;

    setState(() => _isSaving = true);
    final person = PersonEntity(
      name: _nameController.text.trim(),
      phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
    );

    await ref.read(personProvider.notifier).addPerson(person);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Add Person', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            PremiumCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                   SleekTextField(
                    label: 'Full Name',
                    controller: _nameController,
                    hintText: 'e.g. Ali Khan',
                  ),
                  const SizedBox(height: 20),
                  SleekTextField(
                    label: 'Phone Number (Optional)',
                    controller: _phoneController,
                    hintText: 'e.g. +92 300 1234567',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 32),
                  SleekButton(
                    onTap: _pickFromContacts,
                    label: 'Pick from Contacts',
                    isSecondary: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            SleekButton(
              onTap: _isSaving ? null : _save,
              label: _isSaving ? 'Adding...' : 'Add Person',
            ),
          ],
        ),
      ),
    );
  }
}
