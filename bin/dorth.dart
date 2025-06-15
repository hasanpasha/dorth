import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:dorth/dorth.dart';
import 'package:dorth/interpreter.dart';
import 'package:dorth/parser.dart';

void main(List<String> arguments) async {  
  final args = Queue<String>.from(arguments);
  if (args.isEmpty) {
    repl();
  }

  final cmd = args.removeFirst();
  
  switch (cmd) {
        case "sim":
        if (args.isEmpty) {
        print("Error: no input file is provided.");
        exit(1);
      }
      final inputFilePath = args.removeFirst();
      final inputFileUri = Uri.file(inputFilePath);
      await interpretFile(inputFileUri);
      break;
    case "com":
      if (args.isEmpty) {
        print("Error: no args is provided for compilation mode.");
        exit(1);
      }
      bool run = false;
      late final inputFileUri;
      while (true) {
        if (args.isEmpty) {
          print("Error: input file has not been provided for compilation.");
        }
        final arg = args.removeFirst();
        if (arg.startsWith('-')) {
          if (arg == "-r" || arg == "--run") {
            run = true;
          } else if (arg == "-nr" || arg == "--no-run") {
            run = false;
          } else {
            print("Error: unknown flag `$arg`.");
            exit(1);
          }
        } else {
          inputFileUri = Uri.file(arg);
          break;
        }
      }
      await compileFile(inputFileUri, run: run);
      break;
    default:
      usage();
      print("No subcommand is provided.");
      exit(1);
  }
}

void repl() {
  final parser = Parser();
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
      final program = parser.parse(line);
      interpreter.interpret(program);
    } catch (e) {
      print(e);
    }
  }
  exit(0);
}

void usage() {
  print(
"""Usage: dorth <subcommand> [args]
SUBCOMMANDS:
    sim         <file>    simulate the program.
    com  [-r]   <file>    compile the program."""); 
}