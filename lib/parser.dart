import 'dart:io';
import 'package:dorth/extensions.dart';
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
  drop,
  shr,
  shl,
  bitOr,
  bitAnd,
  swap,
  over,
}

class Op {
  final Token token;
  final OpCode code;
  dynamic operand;

  Op(this.code, this.token, [this.operand]);

  Location get location => token.location;

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

class Parser {
  final String code;
  final Uri? filepath;

  Parser(this.code, this.filepath);

  static List<Op> parse({required String code, Uri? filepath}) {
    final parser = Parser(code, filepath);

    return parser._parse();
  }

  List<Token> _lex(String source, [String? filepath]) {
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

  List<Op> _tokensToOps(List<Token> tokens) {
    return tokens.map((token) {
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
        case "drop":
          return op(.drop);
        case "shr":
          return op(.shr);
        case "shl":
          return op(.shl);
        case "bor":
          return op(.bitOr);
        case "band":
          return op(.bitAnd);
        case "swap":
          return op(.swap);
        case "over":
          return op(.over);
        default:
          if (int.tryParse(token.lexeme) case var num?) {
            return op(.push, num);
          }
          throw SyntaxErrorException(token.location, "unknown word '${token.lexeme}'.");
      }
    }).toList();
  }

  List<Op> _crossreferenceBlocks(List<Op> ops) {
    final stack = Stack<int>();
    for (var ip = 0; ip < ops.length; ip++) {
      Op op = ops[ip];
      switch (op.code) {
        case .if_:
          stack.push(ip);
          break;
        case .else_:
          final addr = stack.pop();
          if (!<OpCode>[.if_].contains(ops[addr].code)) {
            throw SyntaxErrorException(ops[addr].location, "`else` can only close `if` block.");
          }
          ops[addr] = ops[addr].replaceOperand(ip);
          stack.push(ip);
          break;
        case .end:
          final addr = stack.pop();
          final blockStart = ops[addr];
          if (<OpCode>[.if_, .else_].contains(blockStart.code)) {
            ops[addr] = blockStart.replaceOperand(ip);
            ops[ip] = ops[ip].replaceOperand(ip);
          } else if (blockStart.code == .do_) {
            ops[ip] = ops[ip].replaceOperand(blockStart.operand);
            ops[addr] = blockStart.replaceOperand(ip);
          } else {
            throw SyntaxErrorException(ops[addr].location, "`end` can only close `if-else` or `while` block.");
          }
          break;
        case .while_:
          stack.push(ip);
          break;
        case .do_:
          final addr = stack.pop();
          ops[ip] = ops[ip].replaceOperand(addr);
          stack.push(ip);
          break;
        case .mem:
        case .store:
        case .load:
        case .syscall:
        case .dup2:
        case .drop:
        case .shr:
        case .shl:
        case .bitOr:
        case .bitAnd:
        case .swap:
        case .over:
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
      }
    }

    if (stack.canPop()) {
      final op = ops[stack.pop()];
      throw SyntaxErrorException(op.location, "`${op.token.lexeme}` block has not been closed.");
    }

    return ops;
  }
  
  List<Op> _parse() {
    final tokens = _lex(code, filepath?.path);
    var ops = _tokensToOps(tokens);
    return _crossreferenceBlocks(ops);
  }
}

List<Op> parseProgram(String source, [Uri? filepath]) {
  return Parser.parse(code: source, filepath: filepath);
}

Future<List<Op>> parseFile(Uri filepath) async {
  final source = await File(filepath.path).readAsString();
  return parseProgram(source, filepath);
}