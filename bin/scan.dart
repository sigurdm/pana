import 'package:pana/src/library_scanner.dart';
import 'package:pana/src/sdk_env.dart';

main(List<String> args) async {
  var pubEnv = new PubEnvironment();

  var scanner = new LibraryScanner(pubEnv, args.single, false);

  await scanner.scanDirectLibs();
}
