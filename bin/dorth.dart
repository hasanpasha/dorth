import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:dorth/dorth.dart';
import 'package:dorth/interpreter.dart';

void main(List<String> arguments) async {  
  final args = Queue<String>.from(arguments);
  if (args.isEmpty) {
    repl();
  }

  final cmd = args.removeFirst();
  if (args.isEmpty) {
    print("Error: no input file is provided.");
    exit(1);
  }
  final inputFilePath = args.removeFirst();
  
  switch (cmd) {
    case "sim":
      final program = await parseFile(inputFilePath);
      interpretProgram(program);
      break;
    case "com":
      final inputFileUri = Uri.file(inputFilePath);
      final program = await parseFile(inputFilePath);
      final asmUri = inputFileUri.replaceExtension('.S');
      await compileProgram(program, asmUri);
      final objUri = asmUri.replaceExtension('.o');
      await command(["as", asmUri.path, "-o", objUri.path]);
      final exeUri = asmUri.replaceExtension('');
      await command(["ld", objUri.path, "-o", exeUri.path]);
      if (args.isNotEmpty) {
        final flag = args.removeFirst();
        if (flag == "-r") {
          await command([exeUri.path], verbose: true);
        }
      }
      break;
    default:
      usage();
      print("No subcommand is provided.");
      exit(1);
  }
}

void repl() {
  final interpreter = Interpreter();
  interpreter.registerExitCallback((code) {
    print("going to exit with $code code.");
  });

  while (true) {
    stdout.write("> ");
    final line = stdin.readLineSync(encoding: utf8);
    
    if (line == null || line == ".quit" || line == ".exit") {
      break;
    } 

    try {
      final program = parseProgram(line);      
      interpreter.interpret(program);
    } catch (e) {
      print(e);
    }
  }
  exit(0);
}

extension UriPathExtension on Uri {
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
    sim    <file>    simulate the program.
    com    <file>    compile the program."""); 
}

Future<bool> command(List<String> args, {bool verbose = false}) async {
  print("\$ ${args.join(' ')}");
  final result = await Process.run(args.first, args.sublist(1));
  
  if (verbose) {
    stdout.write(result.stdout.toString());
  }
  
  if (result.exitCode != 0) {
    print("abnormal exit ${result.exitCode}: ${result.stderr}");
    return false;
  }
  
  return true;
}