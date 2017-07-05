import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as path;
import 'package:logging/logging.dart';

Logger _logger = new Logger('generator');

typedef String Translator();

class TypeManager {
  Map<String, Translator> typedefs = {};
  void addTypedef(Map def) {
    typedefs[def['name']] = () => translateType(def['idlType']);
  }

  void addEnum(Map def) {
    _logger.fine("Mapping ${def} -> String");
    typedefs[def['name']] = () => "String"; // Better way to map this ?
  }

  String translateType(Map type,
      {bool asReturnType: false, bool asTypeArgument: false}) {
    String res;
    if (type['union'] ?? false) {
      res = "var";
    } else if (type['generic'] != null) {
      if (type['idlType'] is Map) {
        String genType = type['generic'];
        genType = const {
              'sequence': 'List',
            }[genType] ??
            genType;

        res =
            "${genType}<${translateType(type['idlType'],asTypeArgument:true)}>";
      } else {
        res = "var";
      }
    } else {
      res = const {
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
            'unrestricted float': 'num',
            'object': 'Object',
            'Float32Array': 'var',
            'Float64Array': 'var',
            'USVString': 'String',
            'Date': 'DateTime',
            'ByteString': 'String',
          }[type['idlType']] ??
          type['idlType'];
    }
    while (typedefs.containsKey(res)) {
      res = typedefs[res]();
    }
    if (asTypeArgument) {
      if (res == 'void' || res == 'var') res = "dynamic";
    } else if (asReturnType) {
      if (res == 'var') res = "";
    }
    return res;
  }

  String toArg(arg) =>
      "${translateType(arg['idlType'])} ${sanitizeName(arg['name'])}";

  String argumentList(List args) {
    int nonOpt = 0;
    if (args == null) {
      return "";
    }
    if (args.every((arg) {
      if (arg['optional']) {
        return false;
      }
      nonOpt++;
      return true;
    })) {
      return args.map(toArg).join(',');
    } else {
      return [
        args.sublist(0, nonOpt).map(toArg).join(','),
        "[" + args.sublist(nonOpt).map(toArg).join(',') + "]"
      ].where((x) => x.isNotEmpty).join(',');
    }
  }
}

String sanitizeName(String name) =>
    {
      'default': 'defaultValue',
      'continue': 'doContinue',
      'is': 'IS',
      'extends': 'Extends',
      'assert' : '\$assert',
      'MozSelfSupport': 'mozSelfSupport',
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
  String namespace;
  Stream<String> generate(TypeManager manager);

  factory Generator(def, {String namespace}) {
    if (def['type'] == 'callback') {
      return new CallbackGenerator(def)..namespace = namespace;
    } else if (def['type'] == 'typedef') {
      return new TypedefGeneretor(def)..namespace = namespace;
    } else if (def['type'] == 'operation') {
      return new OperationGenerator(def)..namespace = namespace;
    }
    return null;
  }
}

class OperationGenerator implements Generator {
  String namespace;
  Map def;

  OperationGenerator(this.def);

  Stream<String> generate(TypeManager manager) async* {
    yield '@JS("${namespace}${def['name']}")\n';
    yield 'external ';
    yield* generateOperation(manager, def);
  }
}

class CallbackGenerator implements Generator {
  String namespace;
  Map def;

  CallbackGenerator(this.def);

  Stream<String> generate(TypeManager manager) async* {
    yield 'typedef ';
    yield* generateOperation(manager, def);
  }
}

class TypedefGeneretor implements Generator {
  String namespace;
  Map def;
  TypedefGeneretor(this.def);

  @override
  Stream<String> generate(TypeManager manager) async* {
    yield 'typedef ${manager.translateType(def['idlType'])} ${def['name']};\n';
  }
}

class InterfaceDef implements Generator {
  String namespace;
  String name;
  String inherits;
  List extAttrs = [];
  List<String> implementz = [];
  List members = [];

  Stream<String> generate(TypeManager manager) async* {
    yield "@JS('$name')\n";
    yield "abstract class ${name}";

    List all = [];
    if (inherits != null) {
      all.add(inherits);
    }
    all.addAll(implementz);

    if (inherits != null) {
      yield " implements ${all.join(',')}";
    }
    /*
    if (implementz.isNotEmpty) {
      String conj = " with ";

      for (String imp in implementz) {
        yield conj;
        yield imp;
        conj = ", ";
      }
    }*/
    yield " {\n";

    yield* generateConstructor(manager);

    yield* generateAttributes(manager);

    yield "}\n";
  }

  Stream<String> generateConstructor(TypeManager manager) async* {
    for (Map arg in extAttrs) {
      if (arg['name'] == 'Constructor') {
        yield "    external factory ${name}(${manager.argumentList(arg['arguments'])});\n";
        break;
      }
    }
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
      String name;
      String origName = member['name'];
      name = sanitizeName(origName);
      String type;
      Map idlType = (member['idlType'] ?? {});
      type = typeManager.translateType(idlType);
      String returnType = type == 'var' ? '' : type;
      if (name != origName) {
        name = 'JS\$${origName}';
        //    yield "    @JS('${origName}')\n";
      }
      yield "    external ${returnType} get ${name};\n";
      if (!(member['readonly'] ?? false)) {
        if (name != origName) {
          yield "    @JS('${origName}')\n";
        }
        yield "    external set ${name} (${type} val);\n";
      }
    } else if (type == 'operation') {
      yield* generateOperation(typeManager, member, prefix: '    external ');
    }
  }
}

class DictionaryDef implements Generator {
  String namespace;
  String name;
  String inherits;
  List extAttrs = [];
  List<String> implementz = [];
  List members = [];

  DictionaryDef(Map<String, dynamic> record) {
    inherits = record['inheritance'];
    name = record['name'];
    extAttrs = record['extAttrs'];
    members = record['members'];
  }

  Stream<String> generate(TypeManager manager) async* {
    yield "@JS()\n";
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
      String origName = member['name'];
      String name;
      name = sanitizeName(origName);
      String type;
      Map idlType = (member['idlType'] ?? {});
      type = typeManager.translateType(idlType);
      String returnType = type == 'var' ? '' : type;
      if (name != origName) {
        yield "    @JS('${origName}')\n";
      }
      yield "    external ${returnType} get ${name};\n";
      if (!(member['readonly'] ?? false)) {
        if (name != origName) {
          yield "    @JS('${origName}')\n";
        }
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

  for (String k in interfaces.keys.toList()..sort()) {
    Generator def = interfaces[k];
    await stdout
        .addStream(def.generate(typeManager).transform(new Utf8Encoder()));

    stdout.writeln();
  }

  stdout.writeln("const INTERFACES = const [");
  interfaces.keys
      .where((k) => interfaces[k] is InterfaceDef)
      .forEach((k) => stdout.writeln("   '${k}',"));
  stdout.writeln("];");

  stdout.flush();
}

Future collect(String webIdlPath, Map<String, Generator> interfaces,
    TypeManager typeManager) async {
  var webidlJson = JSON.decode(await new File(webIdlPath).readAsString());
  mergeInterfaces(webidlJson, interfaces, typeManager);
}

void mergeInterfaces(
    var webidlJson, Map<String, Generator> res, TypeManager typeManager,
    {String namespacePrefix: ""}) {
  webidlJson.forEach((Map<String, dynamic> record) {
    String type = record['type'];
    String name = '${namespacePrefix}${record['name']}';
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
    } else if (type == 'callback' || type == 'operation') {
      res[name] = new Generator(record, namespace: namespacePrefix);
    } else if (type == 'typedef') {
      typeManager.addTypedef(record);
    } else if (type == 'dictionary') {
      res[name] = new DictionaryDef(record);
    } else if (type == 'enum') {
      typeManager.addEnum(record);
    } else if (type == 'namespace') {
      String namespace = namespacePrefix + record['name'];
      mergeInterfaces(record['members'], res, typeManager,
          namespacePrefix: namespace + '.');
    }
  });
}
