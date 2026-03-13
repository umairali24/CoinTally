import 'database_config_stub.dart'
    if (dart.library.html) 'database_config_web.dart'
    if (dart.library.io) 'database_config_vm.dart';

Future<void> configureDatabase() async {
  await configurePlatformDatabase();
}
