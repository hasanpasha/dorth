import 'dart:io';
import 'package:dorth/extensions.dart';

import 'package:dorth/stack.dart';
import 'package:string_unescape/string_unescape.dart';

enum OpCode {
  pushNum,
  pushStr,
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
  int line;
  int column;
  final String? filename;

  Location(this.line, this.column, [this.filename]);

  Location copyWith({int? line, int? column, String? filename}) {
    return Location(line ?? this.line, column ?? this.column, filename ?? this.filename);
  }

  @override
  String toString() =>  "${filename ?? ""}:$line:$column";
}

enum TokenKind {
  word,
  number,
  string,
}

class Lexer {
  final String _source;
  int _start = 0;
  int _current = 0;
  final Location _location;
  final List<Token> tokens = [];

  Lexer(this._source, [String? filename]) : 
    _location = Location(1, 1, filename)
  {
    while (!_isAtEnd) {
      _lexNext();
    }
  }
  
  bool get _isAtEnd => _current == _source.length;

  void _lexNext() {
    _skipWhitespaces();
    _start = _current;

    if (_isAtEnd) return;

    final String cur = _advance();

    if (cur.isDigit && (_peek().isDigit || _peek().isWhiteSpace)) {
      while (!_isAtEnd && _peek().isDigit) {
        _advance();
      } 
      _pushToken(.number);
    } else if (cur == '"') {
      while (!_isAtEnd && _peek() != '"') {
        _advance();
      }
      if (_isAtEnd && _prev() != '"') throw Exception("code ended without terminating a string.");
      _advance();
      _pushToken(.string);
    } else if (cur == '/' && _peek() == '/') {
      while (!_isAtEnd && !_match('\n')) {
        _advance();
      }
    } else if (cur.isWhiteSpace) {
      _advance();
    } else {
      while (!_isAtEnd && !_peek().isWhiteSpace) {
        _advance();
      }
      _pushToken(.word);
    }
  }

  void _pushToken(TokenKind kind) {
    final newLocation = _location.copyWith(column: _location.column - (_current - _start));
    tokens.add(Token(kind, _source.substring(_start, _current), newLocation));
  }
  
  String _advance() {
    if (_isAtEnd) return "";
    final cur = _source[_current];

    if (cur == '\n') {
      _location.line++;
      _location.column = 1;
    } else {
      _location.column++;
    }
    
    _current++;
    return cur;
  }
  
  String _peek() => _source[_current];
  String _prev() => _source[_current-1];
  
  void _skipWhitespaces() {
    while (!_isAtEnd && _peek().isWhiteSpace) {
      _advance();
    }
  }
  
  bool _match(String s) {
    if (_isAtEnd) return false;
    if (_peek() == s) {
      _advance();
      return true;
    }
    return false;
  }
  
}

class Token {
  final TokenKind kind;
  final String lexeme;
  final Location location;

  const Token(this.kind, this.lexeme, this.location);
  
  @override
  String toString() => "$kind[$location:$lexeme]";
}

class SyntaxErrorException implements Exception {
  final Location location;
  final String? message;

  SyntaxErrorException(this.location, [this.message]);

  @override
  String toString() => "$location: $message";
}

class Parser {
  final Map<String, Macro> macros = {};

  Parser();


  List<Op> _tokensToOps(List<Token> tokens) {
    return tokens.map((token) {
      Op op(OpCode code, [dynamic operand]) => Op(code, token, operand);
      
      switch (token.kind) {
        case TokenKind.word:
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
              throw SyntaxErrorException(token.location, "unknown word '${token.lexeme}'.");
          }
        case TokenKind.number:
          return op(.pushNum, int.parse(token.lexeme));
        case TokenKind.string:
          final str = unescape(token.lexeme.substring(1, token.lexeme.length-1));
          return op(.pushStr, str);
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
        case .pushNum:
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
        case .pushStr:
          break;
      }
    }

    if (stack.canPop()) {
      final op = ops[stack.pop()];
      throw SyntaxErrorException(op.location, "`${op.token.lexeme}` block has not been closed.");
    }

    return ops;
  }
  
  List<Op> parse(String code, [Uri? filepath]) {
    final lexer = Lexer(code, filepath?.path);
    List<Token> tokens = lexer.tokens;
    tokens = _preprocess(tokens);
    var ops = _tokensToOps(tokens);
    return _crossreferenceBlocks(ops);
  }
  
  List<Token> _preprocess(List<Token> tokens) {
    final List<Token> output = _parseMacros(tokens);
    return _expandMacros(output);
  }
  
  List<Token> _parseMacros(List<Token> tokens) {
    final List<Token> output = [];
    int i =0 ;
    while (i < tokens.length) {
      final token = tokens[i];
      if (token.kind == .word && token.lexeme == "macro") {
        if (i+1 == tokens.length) {
          throw SyntaxErrorException(token.location, "tokens stream ended without finishing macro definition.");
        }
        i++;
        final name = tokens[i];
        if (macros.containsKey(name.lexeme)) {
          throw SyntaxErrorException(token.location, "redefintion of a macro with the name `${name.lexeme}`.");
        }
        if (_builtinWords.contains(name.lexeme)) {
          throw SyntaxErrorException(token.location, "macro can't have a name that is reserved for builtin words.");
        }
        final macro = Macro(token.location, <Token>[]);
        i++;
        int requiredEnds = 1;
        while (true) {
          if (i >= tokens.length) {
            throw SyntaxErrorException(token.location, "tokens stream ended without ending macro `${name.lexeme}` definition.");
          }
          final macroToken = tokens[i];
          i++;
          if (macroToken.kind == .word && macroToken.lexeme == "end") {
            requiredEnds--;
            if (requiredEnds == 0) break;
          }
          if (macroToken.kind == .word && ["macro", "while", "if"].contains(macroToken.lexeme)) {
            requiredEnds++;
          }
          macro.body.add(macroToken);
        }
        macros[name.lexeme] = macro;
      } else {
        output.add(token);
        i++;
      }
    }
    return output;
  }
  
  static final List<String> _builtinWords = [ 
    "dump",
    "dup",
    "2dup",
    '+',
    '-',
    '=',
    "!=",
    '>',
    ">=",
    '<',
    "<=",
    "if",
    "end",
    "else",
    "while",
    "do",
    "mem",
    '.',
    ',',
    "syscall0",
    "syscall1",
    "syscall2",
    "syscall3",
    "syscall4",
    "syscall5",
    "syscall6",
    "drop",
    "shr",
    "shl",
    "bor",
    "band",
    "swap",
    "over",
  ];

  List<Token> _expandMacros(List<Token> tokens) {
    final List<Token> output = [];
    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      if (token.kind == .word && !_builtinWords.contains(token.lexeme) && macros.containsKey(token.lexeme)) {
        final macro = macros[token.lexeme]!;
        output.addAll(_preprocess(macro.body));
      } else {
        output.add(token);
      }
    }
    return output;
  }
}

class Macro {
  final Location location;
  final List<Token> body;

  Macro(this.location, this.body);
}

List<Op> parseProgram(String source, [Uri? filepath]) {
  return Parser().parse(source, filepath);
}

Future<List<Op>> parseFile(Uri filepath) async {
  final source = await File(filepath.path).readAsString();
  return parseProgram(source, filepath);
}