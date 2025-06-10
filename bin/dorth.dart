import 'dart:io';

import 'package:dorth/dorth.dart' as dorth;

final List<dorth.Op> program = [.push(34), .push(35), .plus(), .dump(), .push(500), .push(80), .minus(), .dump(), .push(0), .dump()];

void main(List<String> arguments) async {  
  if (arguments.length == 1) {
    switch (arguments[0]) {
      case "sim":
        dorth.simulateProgram(program);
        break;
      case "com":
        final asmUri = await dorth.compileProgram(program, "output.S");
        final objUri = asmUri.replaceExtension('.o');
        await command(["as", asmUri.path, "-o", objUri.path]);
        final exeUri = asmUri.replaceExtension('');
        await command(["ld", objUri.path, "-o", exeUri.path]);
        break;
      default:
        usage();
        print("No subcommand is provided.");
        exit(1);
    }
  } else {
    usage();
  }
}

extension on Uri {
  String baseFilename() {
    return pathSegments.last;
  }

  String baseFilenameWithoutExtension() {
    final parts = baseFilename().split('.');
    if (parts.length == 1) return parts.first;
    parts.removeLast();
    return parts.join();
  }

  Uri replaceExtension(String newExtension) {
    final newFilenamem = "${baseFilenameWithoutExtension()}$newExtension";
    final pathSegms = pathSegments.toList();
    pathSegms.removeLast();
    pathSegms.add(newFilenamem);
    final newPath = replace(pathSegments: pathSegms);
    return newPath;
  }
}

void usage() {
  print(
"""Usage: dorth <subcommand> [args]
SUBCOMMANDS:
    sim        simulate the program.
    com        compile the program."""); 
}

Future<bool> command(List<String> args, [bool verbose = false]) async {
  print("\$ ${args.join(' ')}");
  final result = await Process.run(args.first, args.sublist(1));
  
  if (verbose) {
    // print(result.stdout);
  }
  
  if (result.exitCode != 0) {
    // print(result.stderr);
    return false;
  } else {
    return true;
  }
}