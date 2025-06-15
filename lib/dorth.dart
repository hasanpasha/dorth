import 'dart:io';

import 'package:dorth/code_gen.dart';
import 'package:dorth/extensions.dart';
import 'package:dorth/interpreter.dart';
import 'package:dorth/parser.dart';

Future<void> interpretFile(Uri filepath, {int memoryCapacity = 64000}) async {
  final code = await File(filepath.path).readAsString();
  final program = Parser().parse(code, filepath);
  Interpreter(memoryCapacity: memoryCapacity).interpret(program);
}

Future<void> compileFile(Uri inputFileUri, {Uri? outputPath, int memoryCapacity = 64_000, bool run = true}) async {
  final code = await File(inputFileUri.path).readAsString();
  final program = Parser().parse(code, inputFileUri);
  final generated = CodeGen.gen(program, memoryCapacity: memoryCapacity);
  
  final outputUri = outputPath ?? inputFileUri.replaceExtension('');
  final generatedFileUri = outputUri.replaceExtension('.S');
  final generatedObjectUri = outputUri.replaceExtension('.o');

  await File(generatedFileUri.path).writeAsString(generated, flush: true);

  int exitCode = 0;
  exitCode = await command(Uri.file("/usr/bin/as"), [generatedFileUri.path, "-o", generatedObjectUri.path]);
  if (exitCode != 0) {
    print("failed to compile generated code.");
    exit(exitCode);
  }

  exitCode = (await command(Uri.file("/usr/bin/ld"), [generatedObjectUri.path, "-o", outputUri.path]));
  if (exitCode != 0) {
    print("failed to link generated object file.");
    exit(exitCode);
  }

  if (run) {
    exitCode = (await command(outputUri, [], verbose: true)); 
    if (exitCode != 0) {
      print("error running output file.");
      exit(exitCode);
    }
  }
}

Future<int> command(Uri binUri, List<String> args, {bool verbose = false}) async {
  final binPath = binUri.hasAbsolutePath ? binUri.path : "./${binUri.path}";

  print("\$ $binPath ${args.join(' ')}");
  final result = await Process.run(binPath, args);
  
  if (verbose) {
    stdout.write(result.stdout.toString());
  }
  
  if (result.exitCode != 0) {
    print("abnormal exit ${result.exitCode}: ${result.stderr}");
  }
  
  return result.exitCode;
}