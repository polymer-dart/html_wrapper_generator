import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as path;
import 'package:logging/logging.dart';

Logger _logger = new Logger('generator');

class TypeManager {
  Map<String, String> typedefs = {};
  void addTypedef(Map def) {
    typedefs[def['name']] = translateType(def['idlType']);
  }

  void addEnum(Map def) {
    typedefs[def['name']] = "String"; // Better way to map this ?
  }

  String translateType(Map type,
      {bool asReturnType: false, bool asTypeArgument: false}) {
    String res;
    if (type['union'] ?? false) {
      res = "var";
    } else if (type['generic'] != null) {
      if (type['idlType'] is Map) {
        String genType = type['generic'];
        genType = {
              'sequence': 'List',
            }[genType] ??
            genType;

        res =
            "${genType}<${translateType(type['idlType'],asTypeArgument:true)}>";
      } else {
        res = "var";
      }
    } else {
      res = {
            "DOMString": "String",
            "long": "num",
            "short": "num",
            'float': 'num',
            'double': 'num',
            'unsigned float': 'num',
            'unsigned double': 'num',
            "boolean": "bool",
            "DOMStringMap": "var",
            "unsigned long": "num",
            "unsigned short": "num",
            "sequence": "List",
            'unrestricted double': 'num',
            'unsigned long long': 'num',
            'long long': 'num',
            'any': 'var',
            'unrestricted float':'num',
            'object' : 'Object',
          }[type['idlType']] ??
          type['idlType'];
    }
    res = typedefs[res] ?? res;
    if (asTypeArgument) {
      if (res == 'void' || res == 'var') res = "dynamic";
    } else if (asReturnType) {
      if (res == 'var') res = "";
    }
    return res;
  }

  String argumentList(List args) => args
      .map((arg) =>
          "${translateType(arg['idlType'])} ${sanitizeName(arg['name'])}")
      .join(',');
}

String sanitizeName(String name) =>
    {
      'default': 'defaultValue',
      'continue' :'doContinue',
      'is' :'IS',
    }[name] ??
    name;

Stream<String> generateOperation(TypeManager typeManager, member,
    {String prefix: ""}) async* {
  String name = member['name'];
  name = sanitizeName(name);
  String type;
  Map idlType = (member['idlType']);
  if (idlType == null) {
    _logger.warning("Type is null in ${member}");
    return;
  }
  bool isGetter = member['getter'];
  bool isSetter = member['setter'];
  bool isDeleter = member['deleter'];
  bool isStringifier = member['stringifier'] ?? false;
  type = typeManager.translateType(idlType, asReturnType: true);
  assert(!isGetter || !isSetter, "not setter and getter");

  if (isGetter) {
    yield "${prefix}${type} operator[](${typeManager.argumentList(member['arguments'])});\n";
  } else if (isSetter) {
    yield "${prefix}${type} operator[]=(${typeManager.argumentList(member['arguments'])});\n";
  } else if (isDeleter) {
    yield "    // Deleter ?\n";
  } else if (isStringifier) {
    yield "    // isStringifier ?\n";
  } else {
    yield "${prefix}${type} ${name}(${typeManager.argumentList(member['arguments'])});\n";
  }
}

abstract class Generator {
  Stream<String> generate(TypeManager manager);

  factory Generator(def) {
    if (def['type'] == 'callback') {
      return new CallbackGenerator(def);
    } else if (def['type'] == 'typedef') {
      return new TypedefGeneretor(def);
    }
    return null;
  }
}

class CallbackGenerator implements Generator {
  Map def;

  CallbackGenerator(this.def);

  Stream<String> generate(TypeManager manager) async* {
    yield 'typedef ';
    yield* generateOperation(manager, def);
  }
}

class TypedefGeneretor implements Generator {
  Map def;
  TypedefGeneretor(this.def);

  @override
  Stream<String> generate(TypeManager manager) async* {
    yield 'typedef ${manager.translateType(def['idlType'])} ${def['name']};\n';
  }
}

class InterfaceDef implements Generator {
  String name;
  String inherits;
  List extAttrs = [];
  List<String> implementz = [];
  List members = [];

  Stream<String> generate(TypeManager manager) async* {
    yield "@JS('$name')\n";
    yield "class ${name}";
    if (inherits != null) {
      yield " extends ${inherits}";
    }
    if (implementz.isNotEmpty) {
      String conj = " with ";
      for (String imp in implementz) {
        yield conj;
        yield imp;
        conj = ", ";
      }
    }
    yield " {\n";

    yield* generateAttributes(manager);

    yield "}\n";
  }

  Stream<String> generateAttributes(TypeManager typeManager) async* {
    for (Map<String, dynamic> member in members) {
      yield* writeMember(typeManager, member);
    }
  }

  Stream<String> writeMember(
      TypeManager typeManager, Map<String, dynamic> member) async* {
    String type = member['type'];

    if (type == 'attribute') {
      String name = member['name'];
      name = sanitizeName(name);
      String type;
      Map idlType = (member['idlType'] ?? {});
      type = typeManager.translateType(idlType);
      String returnType = type == 'var' ? '' : type;
      yield "    external ${returnType} get ${name};\n";
      if (!(member['readonly'] ?? false)) {
        yield "    external set ${name} (${type} val);\n";
      }
    } else if (type == 'operation') {
      yield* generateOperation(typeManager, member, prefix: '    external ');
    }
  }
}


class DictionaryDef implements Generator {
  String name;
  String inherits;
  List extAttrs = [];
  List<String> implementz = [];
  List members = [];

  DictionaryDef(Map<String,dynamic> record) {
    inherits = record['inheritance'];
    name =record['name'];
    extAttrs = record['extAttrs'];
    members=record['members'];
  }

  Stream<String> generate(TypeManager manager) async* {
    yield "@anonymous\n";
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

    yield* generateAttributes(manager);

    yield "}\n";
  }

  Stream<String> generateAttributes(TypeManager typeManager) async* {
    for (Map<String, dynamic> member in members) {
      yield* writeMember(typeManager, member);
    }
  }

  Stream<String> writeMember(
      TypeManager typeManager, Map<String, dynamic> member) async* {
    String type = member['type'];

    if (type == 'field') {
      String name = member['name'];
      name = sanitizeName(name);
      String type;
      Map idlType = (member['idlType'] ?? {});
      type = typeManager.translateType(idlType);
      String returnType = type == 'var' ? '' : type;
      yield "    external ${returnType} get ${name};\n";
      if (!(member['readonly'] ?? false)) {
        yield "    external set ${name} (${type} val);\n";
      }
    } else if (type == 'operation') {
      yield* generateOperation(typeManager, member, prefix: '    external ');
    }
  }
}

Future generateAll(String folderPath) async {
  Map<String, Generator> interfaces = {};
  TypeManager typeManager = new TypeManager();
  Directory dir = new Directory(folderPath);

  stdout.writeln("""part of html_lib;""");

  await for (FileSystemEntity idl in dir.list()) {
    if (!idl.path.endsWith(".webidl.json") || (idl is! File)) continue;
    stderr.write("Reading ${idl.path}...");
    await collect(idl.path, interfaces, typeManager);
    stderr.writeln("OK");
  }

  for (Generator def in interfaces.values) {
    await stdout
        .addStream(def.generate(typeManager).transform(new Utf8Encoder()));

    stdout.writeln();
  }

  stdout.flush();
}

Future collect(String webIdlPath, Map<String, Generator> interfaces,
    TypeManager typeManager) async {
  var webidlJson = JSON.decode(new File(webIdlPath).readAsStringSync());
  mergeInterfaces(webidlJson, interfaces, typeManager);
}

void mergeInterfaces(
    var webidlJson, Map<String, Generator> res, TypeManager typeManager) {
  webidlJson.forEach((Map<String, dynamic> record) {
    String type = record['type'];
    String name = record['name'];
    if (type == 'interface') {
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
    } else if (type == 'callback') {
      res[name] = new Generator(record);
    } else if (type == 'typedef') {
      typeManager.addTypedef(record);
    } else if (type=='dictionary') {
      res[name]= new DictionaryDef(record);
    } else if(type=='enum') {
      typeManager.addEnum(record);
    }
  });
}
