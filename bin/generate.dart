import 'dart:io';
import 'package:logging/logging.dart';
import 'package:webidl_generator/generator.dart';

main(List<String> args) {
  Logger.root.onRecord.listen((r) => stderr.writeln(r.message));
  Logger.root.level=Level.FINE;
  return generateAll(args[0]);
}
