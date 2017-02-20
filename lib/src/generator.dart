import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as path;
import 'package:logging/logging.dart';

Logger _logger = new Logger('generator');

class InterfaceDef {
  String name;
  String inherits;
  List extAttrs = [];
  List<String> implementz = [];
  List members = [];

  Stream<String> writeWrapper() async* {
    yield "@JS('$name')\n";
    yield "class ${name}";
    if (inherits != null) {
      yield " extends ${inherits}";
    }
    if (implementz.isNotEmpty) {
      String conj = " implements ";
      for (String imp in implementz) {
        yield conj;
        yield imp;
        conj = ", ";
      }
    }
    yield " {\n";

    yield* generateAttributes();

    yield "}\n";
  }

  Stream<String> generateAttributes() async* {
    for (Map<String, dynamic> member in members) {
      yield* writeMember(member);
    }
  }

  Stream<String> writeMember(Map<String, dynamic> member) async* {
    String type = member['type'];

    if (type == 'attribute') {
      String name = member['name'];
      String type = member['idlType']['idlType'];
      type = translateType(type);
      yield "    external ${type} get ${name};\n";
      yield "    external set ${name} (${type} val);\n";
    } else if (type == 'operation') {
      String name = member['name'];
      String type = (member['idlType'] ?? {})['idlType'];
      if (type == null) {
        _logger.warning("Type is null in ${member}");
        return;
      }
      bool isGetter = member['getter'];
      bool isSetter = member['setter'];
      bool isDeleter = member['deleter'];
      type = translateType(type);
      assert(!isGetter || !isSetter, "not setter and getter");

      if (isGetter) {
        yield "    external ${type} operator[](${argumentList(member['arguments'])});\n";
      } else if (isSetter) {
        yield "    external ${type} operator[]=(${argumentList(member['arguments'])});\n";
      } else if (isDeleter) {
        yield "    // Deleter ?\n";
      } else {
        yield "    external ${type} ${name}(${argumentList(member['arguments'])});\n";
      }
    }
  }

  String argumentList(List args) => args
      .map(
          (arg) => "${translateType(arg['idlType']['idlType'])} ${arg['name']}")
      .join(',');

  String translateType(String type) {
    return {
          "DOMString": "String",
          "long": "num",
          "boolean": "bool",
          "DOMStringMap": "var",
          "unsigned long": "num",
        }[type] ??
        type;
  }
}

Future generateAll(String folderPath) async {
  Map<String, InterfaceDef> interfaces = {};
  Directory dir = new Directory(folderPath);
  await for (FileSystemEntity idl in dir.list()) {
    if (!idl.path.endsWith(".webidl.json") || (idl is! File)) continue;
    stderr.write("Reading ${idl.path}...");
    await generate(idl.path, interfaces);
    stderr.writeln("OK");
  }

  for (InterfaceDef def in interfaces.values) {
    await stdout.addStream(def.writeWrapper().transform(new Utf8Encoder()));

    stdout.writeln();
  }

  stdout.flush();
}

Future generate(String webIdlPath, Map<String, InterfaceDef> interfaces) async {
  var webidlJson = JSON.decode(new File(webIdlPath).readAsStringSync());
  mergeInterfaces(webidlJson, interfaces);
}

void mergeInterfaces(var webidlJson, Map<String, InterfaceDef> res) {
  webidlJson.forEach((Map<String, dynamic> record) {
    String type = record['type'];
    if (type == 'interface') {
      String name = record['name'];
      InterfaceDef def =
          res.putIfAbsent(name, () => new InterfaceDef()..name = name);
      bool partial = record['partial'];
      if (!partial) {
        def.inherits = record['inheritance'];
        def.extAttrs = record['extAttrs'];
      }
      def.members.addAll(record['members']);
    } else if (type == 'implements') {
      String target = record['target'];
      InterfaceDef def =
          res.putIfAbsent(target, () => new InterfaceDef()..name = target);
      def.implementz.add(record['implements']);
    }
  });
}
