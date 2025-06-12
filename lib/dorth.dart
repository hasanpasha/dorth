import 'dart:io';

import 'package:dorth/code_gen.dart';
import 'package:dorth/interpreter.dart';
import 'package:dorth/parser.dart';

void interpretProgram(List<Op> program, {int memoryCapacity = 64000}) {
  Interpreter(memoryCapacity: memoryCapacity).interpret(program);
}

Future<void> compileProgram(List<Op> program, Uri outputPath, {int memoryCapacity = 64_000}) async {
  final generated = CodeGen.gen(program, memoryCapacity: memoryCapacity);
  await File(outputPath.path).writeAsString(generated);
}