import 'dart:io';

import 'package:dorth/stack.dart';

enum OpCode {
  push,
  plus,
  minus,
  dump;
}

class Op {
  final OpCode code;
  final List<dynamic> operands;

  Op(this.code, [List<dynamic>? operands]) : operands = operands ?? [];

  @override
  String toString() => "$code ${operands.join(", ")}";

  static Op push(num x) {
    return Op(OpCode.push, [x]);
  }

  static Op plus() {
    return Op(OpCode.plus);
  }

  static Op minus() {
    return Op(OpCode.minus);
  }

  static Op dump() {
    return Op(OpCode.dump);
  }
}

void simulateProgram(List<Op> program) {
  final stack = Stack<num>();

  for (var op in program) {
    switch (op.code) {
      case .push:
        stack.push(op.operands[0]);
        break;
      case .plus:
        final b = stack.pop();
        final a = stack.pop();
        stack.push(a + b);
        break;
      case .minus:
        final b = stack.pop();
        final a = stack.pop();
        stack.push(a - b);
        break;
      case .dump:
        final x = stack.pop();
        print(x);
    }
  }
}

class CodeGen {
  late File file;
  late IOSink output;

  CodeGen(String outputName) {
    file = File(outputName);
    output = file.openWrite();
  }

  Future<Uri> done() async {
    await output.flush();
    await output.close();
    return file.absolute.uri;
  }

  void writeln(String str) {
    output.writeln(str);
  }

  void writeAll(List<Object> objs) {
    for (var obj in objs) {
      writeln(obj.toString());
    }
  }
  
  void push(Object operand) {
    writeln("push $operand");
  }
  
  void pop(String reg) {
    writeln("pop $reg");
  }
  
  void add(String reg1, String reg2) {
    writeln("add $reg1, $reg2");
  }
  
  void sub(String reg1, String reg2) {
    writeln("sub $reg1, $reg2");
  }

  void defineDump() {
    writeAll([
      "dump:",
      "sub rsp, 40",
      "mov rcx, 30",
      "movabs r8, 0xcccccccccccccccd",
      "mov BYTE PTR [rsp+31], 10",
      "dump.loop:",
      "mov rax, rdi",
      "mul r8",
      "mov rax, rdi",
      "shr rdx, 3",
      "lea rsi, [rdx+rdx*4]",
      "add rsi, rsi",
      "sub rax, rsi",
      "mov rsi, rcx",
      "add eax, 48",
      "mov BYTE PTR [rsp+rcx], al",
      "sub rcx, 1",
      "cmp rdi, 9",
      "mov rdi, rdx",
      "ja dump.loop",
      "lea rsi, [rsp+rcx+1]",
      "mov rdx, 31",
      "sub rdx, rcx",
      "mov edi, 1",
      "mov rax, 1",
      "syscall",
      "add rsp, 40",
      "ret",
    ]);
  }
}

Future<Uri> compileProgram(List<Op> program, [String outputPath = "output.S"]) async {
  final gen = CodeGen(outputPath);
  
  gen.writeln(".intel_syntax noprefix");

  gen.writeAll([
    ".section .data",
  ]);

  gen.writeln(".section .text");

  gen.defineDump();

  gen.writeAll([
    ".global _start",
    "_start:",
  ]);

  for (var op in program) {
    switch (op.code) {
      case .push:
        gen.push(op.operands.first);
        break;
      case .plus:
        gen.pop("rax");
        gen.pop("rdi");
        gen.add("rax", "rdi");
        gen.push("rax");
        break;
      case .minus:
        gen.pop("rdi");
        gen.pop("rax");
        gen.sub("rax", "rdi");
        gen.push("rax");
        break;
      case .dump:
        gen.pop("rdi");
        gen.writeln("call dump");
        break;
    }
  }

  gen.writeAll([
    "mov rax, 60",
    "mov rdi, 1",
    "syscall",
  ]);

  return gen.done();
}