import 'dart:io';
import 'package:dorth/interpreter.dart';
import 'package:quiver/iterables.dart';

import 'package:dorth/stack.dart';

enum OpCode {
  push,
  plus,
  minus,
  equal,
  neq,
  gt,
  ge,
  lt,
  le,
  dump,
  dup,
  dup2,
  if_,
  end,
  else_,
  while_,
  do_,
  mem,
  store,
  load,
  syscall,
}

class Op {
  final Token token;
  final OpCode code;
  dynamic operand;

  Op(this.code, this.token, [this.operand]);

  Location get location => token.location;
  String get locationAsLabel => ".__${location.line}_${location.column}";

  @override
  String toString() => "${token.location}:$code $operand";

  Op replaceOperand(dynamic operand) {
    final newOp = this;
    newOp.operand = operand;
    return newOp;
  }
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

        if (i+1 < line.length && line.substring(i, i+2) == "//") {
          break;
        }
      }

      return words;
    })
    .expand((e) => e)
    .toList();
}

List<Op> parseProgram(String source, [String? filepath]) =>
  lex(source, filepath)
  .parse()
  .crossreferenceBlocks();


extension on List<Token> {
  List<Op> parse() {
    return map((token) {
      Op op(OpCode code, [dynamic operand]) => Op(code, token, operand);
      
      switch (token.lexeme) {
        case "dump":
          return op(.dump);
        case "dup":
          return op(.dup);
        case "2dup":
          return op(.dup2);
        case '+':
          return op(.plus);
        case '-':
          return op(.minus);
        case '=':
          return op(.equal);
        case "!=":
          return op(.neq);
        case '>':
          return op(.gt);
        case ">=":
          return op(.ge);
        case '<':
          return op(.lt);
        case "<=":
          return op(.le);
        case "if":
          return op(.if_);
        case "end":
          return op(.end);
        case "else":
          return op(.else_);
        case "while":
          return op(.while_);
        case "do":
          return op(.do_);
        case "mem":
          return op(.mem);
        case '.':
          return op(.store);
        case ',':
          return op(.load);
        case "syscall0":
          return op(.syscall, 0);
        case "syscall1":
          return op(.syscall, 1);
        case "syscall2":
          return op(.syscall, 2);
        case "syscall3":
          return op(.syscall, 3);
        case "syscall4":
          return op(.syscall, 4);
        case "syscall5":
          return op(.syscall, 5);
        case "syscall6":
          return op(.syscall, 6);
        default:
          if (int.tryParse(token.lexeme) case var num?) {
            return op(.push, num);
          }
          throw SyntaxErrorException(token.location, "unknown word '${token.lexeme}'.");
      }
    }).toList();
  }
}

extension on List<Op> {
  List<Op> crossreferenceBlocks() {
    final stack = Stack<int>();
    for (var ip = 0; ip < length; ip++) {
      Op op = this[ip];
      switch (op.code) {
        case .push:
        case .plus:
        case .minus:
        case .equal:
        case .neq:
        case .gt:
        case .ge:
        case .lt:
        case .le:
        case .dump:
        case .dup:
          break;
        case .if_:
          stack.push(ip);
          break;
        case .else_:
          final addr = stack.pop();
          if (!<OpCode>[.if_].contains(this[addr].code)) {
            throw SyntaxErrorException(this[addr].location, "`else` can only close `if` block.");
          }
          this[addr] = this[addr].replaceOperand(ip);
          stack.push(ip);
          break;
        case .end:
          final addr = stack.pop();
          final blockStart = this[addr];
          if (<OpCode>[.if_, .else_].contains(blockStart.code)) {
            this[addr] = blockStart.replaceOperand(ip);
            this[ip] = this[ip].replaceOperand(ip);
          } else if (blockStart.code == .do_) {
            this[ip] = this[ip].replaceOperand(blockStart.operand);
            this[addr] = blockStart.replaceOperand(ip);
          } else {
            throw SyntaxErrorException(this[addr].location, "`end` can only close `if-else` or `while` block.");
          }
          break;
        case .while_:
          stack.push(ip);
          break;
        case .do_:
          final addr = stack.pop();
          this[ip] = this[ip].replaceOperand(addr);
          stack.push(ip);
          break;
        case .mem:
        case .store:
        case .load:
        case .syscall:
        case .dup2:
          break;
      }
    }

    if (stack.canPop()) {
      final op = this[stack.pop()];
      throw SyntaxErrorException(op.location, "`${op.token.lexeme}` block has not been closed.");
    }

    return this;
  }
}

Future<List<Op>> parseFile(String filepath) async {
  final source = await File(filepath).readAsString();
  return parseProgram(source, filepath);
}

extension on String {
  bool get isWhiteSpace => ['\n', '\t', '\r', ' ', '\f'].contains(this);
}

void interpretProgram(List<Op> program, {int memoryCapacity = 64000}) {
  Interpreter(memoryCapacity: memoryCapacity).interpret(program);
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
  
  void comment(String comment) {
    writeln("// $comment");
  }
}

Future<void> compileProgram(List<Op> program, Uri outputPath, {int memoryCapacity = 64_000}) async {
  final gen = CodeGen(outputPath);
  
  gen.writeln(".intel_syntax noprefix");

  gen.writeAll([
    ".section .bss",
    ".comm mem, $memoryCapacity",
  ]);

  gen.writeln(".section .text");

  gen.defineDump();

  gen.writeAll([
    ".global _start",
    "_start:",
  ]);

  for (int ip = 0; ip < program.length; ip++) {
    final op = program[ip];
    switch (op.code) {
      case .push:
        gen.comment("push ${op.operand}");
        gen.push(op.operand);
        break;
      case .plus:
        gen.comment("plus");
        gen.pop("rdi");
        gen.pop("rax");
        gen.add("rax", "rdi");
        gen.push("rax");
        break;
      case .minus:
        gen.comment("minus");
        gen.pop("rdi");
        gen.pop("rax");
        gen.sub("rax", "rdi");
        gen.push("rax");
        break;
      case .equal:
        gen.comment("equal");
        gen.writeln("mov rcx, 1");
        gen.pop("rdi");
        gen.pop("rax");
        gen.writeln("cmp rax, rdi");
        gen.writeln("mov rax, 0");
        gen.writeln("cmove rax, rcx");
        gen.push("rax");
        break;
      case .neq:
        gen.comment("equal");
        gen.writeln("mov rcx, 1");
        gen.pop("rdi");
        gen.pop("rax");
        gen.writeln("cmp rax, rdi");
        gen.writeln("mov rax, 0");
        gen.writeln("cmovne rax, rcx");
        gen.push("rax");
        break;
      case .gt:
        gen.comment("gt");
        gen.writeln("mov rcx, 1");
        gen.pop("rdi");
        gen.pop("rax");
        gen.writeln("cmp rax, rdi");
        gen.writeln("mov rax, 0");
        gen.writeln("cmovg rax, rcx");
        gen.push("rax");
        break;
      case .ge:
        gen.comment("ge");
        gen.writeln("mov rcx, 1");
        gen.pop("rdi");
        gen.pop("rax");
        gen.writeln("cmp rax, rdi");
        gen.writeln("mov rax, 0");
        gen.writeln("cmovge rax, rcx");
        gen.push("rax");
        break;
      case .lt:
        gen.comment("lt");
        gen.writeln("mov rcx, 1");
        gen.pop("rdi");
        gen.pop("rax");
        gen.writeln("cmp rax, rdi");
        gen.writeln("mov rax, 0");
        gen.writeln("cmovl rax, rcx");
        gen.push("rax");
        break;
      case .le:
        gen.comment("ge");
        gen.writeln("mov rcx, 1");
        gen.pop("rdi");
        gen.pop("rax");
        gen.writeln("cmp rax, rdi");
        gen.writeln("mov rax, 0");
        gen.writeln("cmovle rax, rcx");
        gen.push("rax");
        break;
      case .dump:
        gen.comment("dump");
        gen.pop("rdi");
        gen.writeln("call dump");
        break;
      case .dup:
        gen.pop("rax");
        gen.push("rax");
        gen.push("rax");
        break;
      case .if_:
        gen.comment("if");
        gen.pop("rax");
        gen.writeln("test rax, rax");
        gen.writeln("jz .label_${op.operand}");
        break;
      case .end:
        gen.comment("end");
        gen.writeln("jmp .label_${op.operand}");
        gen.writeln(".label_$ip:");
        break;
      case .else_:
        gen.comment("else");
        gen.writeln("jmp .label_${op.operand}");
        gen.writeln(".label_$ip:");
        break;
      case .while_:
        gen.comment("while");
        gen.writeln(".label_$ip:");
        break;
      case .do_:
        gen.comment("do");
        gen.pop("rax");
        gen.writeln("test rax, rax");
        gen.writeln("jz .label_${op.operand}");
        break;
      case .mem:
        gen.comment("mem");
        gen.writeln("lea rax, mem[rip]");
        gen.push("rax");
        break;
      case .store:
        gen.comment("store");
        gen.pop("rbx");
        gen.pop("rax");
        gen.writeln("movb [rax], bl");
        break;
      case .load:
        gen.comment("load");
        gen.pop("rax");
        gen.writeln("xor rbx, rbx");
        gen.writeln("mov bl, [rax]");
        gen.push("rbx");
        break;
      case .syscall:
        final registers = ["rdi", "rsi", "rdx", "r10", "r8", "r9"];
        gen.comment("syscall");
        gen.pop("rax"); // syscall number
        final int amount = op.operand;
        for (int i = 0; i < amount && i < registers.length; i++) {
          gen.pop(registers[i]);
        }
        gen.writeln("syscall");
        gen.push("rax");
        gen.comment("done syscall");
        break;
      case .dup2:
        gen.comment("2dup");
        gen.pop("rax");
        gen.pop("rbx");
        gen.push("rbx");
        gen.push("rax");
        gen.push("rbx");
        gen.push("rax");
        break;
    }
  }

  gen.writeAll([
    "mov rax, 60",
    "mov rdi, 0",
    "syscall",
  ]);

  await gen.done();
}