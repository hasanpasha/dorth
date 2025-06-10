import 'dart:io';
import 'package:quiver/iterables.dart';

import 'package:dorth/stack.dart';

enum OpCode {
  push,
  plus,
  minus,
  dump;
}

class Op {
  final Token token;
  final OpCode code;
  final List<dynamic> operands;

  Op(this.code, this.token, [List<dynamic>? operands]) : operands = operands ?? [];

  @override
  String toString() => "${token.location}:$code ${operands.join(", ")}";
}

class Location {
  final int line;
  final int column;
  final String? filename;

  Location(this.line, this.column, [this.filename]);

  @override
  String toString() =>  "${filename ?? ""}:$line:$column";
}

class Token {
  final String lexeme;
  final Location location;

  const Token(this.lexeme, this.location);
  
  @override
  String toString() => "$location:$lexeme";
}

class SyntaxErrorException implements Exception {
  final Location location;
  final String? message;

  SyntaxErrorException(this.location, [this.message]);

  @override
  String toString() => "$location: $message";
}

List<Op> tokensToOp(List<Token> tokens) {
  return tokens.map((token) {
      switch (token.lexeme) {
        case '.':
          return Op(.dump, token);
        case '+':
          return Op(.plus, token);
        case '-':
          return Op(.minus, token);
        default:
          if (int.tryParse(token.lexeme) case var num?) {
            return Op(.push, token, [num]);
          }
          throw SyntaxErrorException(token.location, "unknown word '${token.lexeme}'.");
      }
    }).toList();
}

List<Token> lex(String source, [String? filepath]) {
  return enumerate(source
    .split('\n'))
    .map((indexed) {
      final lineNumber = indexed.index;
      final line = indexed.value;

      List<Token> words = [];

      String buffer = "";
      int start = 0;
      for (int i = 0; i < line.length; i++) {
        String cur = line.substring(i, i+1);
        
        if (!cur.isWhiteSpace) {
          buffer += cur;
        } 
        
        if (cur.isWhiteSpace || i == line.length-1) {
          if (buffer.isNotEmpty) {
            words.add(Token(buffer, Location(lineNumber+1, start+1, filepath)));
          }

          start = i+1;
          buffer = "";
        }
      }

      return words;
    })
    .expand((e) => e)
    .toList();
}

List<Op> parseProgram(String source, [String? filepath]) {
  return tokensToOp(lex(source, filepath));
}

Future<List<Op>> parseFile(String filepath) async {
  final source = await File(filepath).readAsString();
  return parseProgram(source, filepath);
}

extension on String {
  bool get isWhiteSpace => ['\n', '\t', '\r', ' ', '\f'].contains(this);
}

void interpretProgram(List<Op> program) {
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

  CodeGen(Uri outputName) {
    file = File(outputName.path);
    output = file.openWrite();
  }

  Future<void> done() async {
    await output.flush();
    await output.close();
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

Future<void> compileProgram(List<Op> program, Uri outputPath) async {
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

  await gen.done();
}