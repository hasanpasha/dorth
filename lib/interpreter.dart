

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dorth/parser.dart';
import 'package:dorth/stack.dart';
import 'package:dorth/syscall_emulations.dart';

typedef ExitCallback = void Function (int code);

class Interpreter {
  final Map<String, int> staticStrings = {};
  int stringMemoryPtr = 0;
  final int strCapacity;
  final int memoryCapacity;

  final Stack<int> stack = Stack();
  final Uint8List memory;
  final List<ExitCallback> exitCallbacks = [];

  Interpreter({this.strCapacity = 65_000, this.memoryCapacity = 65_000}) : memory = Uint8List(strCapacity + memoryCapacity);

  void interpret(List<Op> program) {
    for (int ip = 0; ip < program.length; ip++) {
      Op op = program[ip];
      switch (op.code) {
        case .pushNum:
          stack.push(op.operand);
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
        case .equal:
          final b = stack.pop();
          final a = stack.pop();
          stack.push(a == b ? 1 : 0);
          break;
        case .neq:
          final b = stack.pop();
          final a = stack.pop();
          stack.push(a != b ? 1 : 0);
          break;
        case .gt:
          final b = stack.pop();
          final a = stack.pop();
          stack.push(a > b ? 1 : 0);
          break;
        case .ge:
          final b = stack.pop();
          final a = stack.pop();
          stack.push(a >= b ? 1 : 0);
          break;
        case .lt:
          final b = stack.pop();
          final a = stack.pop();
          stack.push(a < b ? 1 : 0);
          break;
        case .le:
          final b = stack.pop();
          final a = stack.pop();
          stack.push(a <= b ? 1 : 0);
          break;
        case .if_:
          final x = stack.pop();
          if (x == 0) {
            ip = op.operand;
          }
          break;
        case .end:
          ip = op.operand;
          break;
        case .else_:
          ip = op.operand;
          break;
        case .dump:
          final x = stack.pop();
          print(x);
          break;
        case .dup:
          final x = stack.pop();
          stack.push(x);
          stack.push(x);
          break;
        case .while_:
          break;
        case .do_:
          final x = stack.pop();
          if (x == 0) {
            ip = op.operand;
          } 
          break;
        case .mem:
          stack.push(strCapacity);
          break;
        case .store:
          final byte = stack.pop();
          final offset = stack.pop();
          if (offset >= memory.length) throw MemoryOverflowError("can't store in this addr: $offset");
          memory[offset] = byte;
          break;
        case .load:
          final offset = stack.pop();
          final byte = memory[offset];
          stack.push(byte);
          break;
        case .syscall:
          final int result = SyscallEmulation.emulate(op, this);
          stack.push(result);
          break;
        case .dup2:
          final a = stack.pop();
          final b = stack.pop();
          stack.push(b);
          stack.push(a);
          stack.push(b);
          stack.push(a);
          break;
        case .drop:
          stack.pop();
          break;
        case .shr:
          final b = stack.pop();
          final a = stack.pop();
          final x = a >> b;
          stack.push(x);
          break;
        case .shl:
          final b = stack.pop();
          final a = stack.pop();
          final x = a << b;
          stack.push(x);
          break;
        case .bitOr:
          final b = stack.pop();
          final a = stack.pop();
          final x = a | b;
          stack.push(x);
          break;
        case .bitAnd:
          final b = stack.pop();
          final a = stack.pop();
          final x = a & b;
          stack.push(x);
          break;
        case .swap:
          final a = stack.pop();
          final b = stack.pop();
          stack.push(a);
          stack.push(b);
          break;
        case .over:
          final a = stack.pop();
          final b = stack.pop();
          stack.push(b);
          stack.push(a);
          stack.push(b);
          break;
        case .pushStr:
          final str = op.operand as String;
          final strEncoded = utf8.encode(str);
          final strEncodedLen = strEncoded.length;
          stack.push(strEncodedLen);
          if (staticStrings.containsKey(str)) {
            stack.push(staticStrings[str]!);
          } else {
            final addr = stringMemoryPtr;
            for (int i = 0; i < strEncodedLen; i++) {
              final idx = stringMemoryPtr+i;
              if (idx > strCapacity) throw MemoryOverflowError("string buffer overflow.");
              memory[idx] = strEncoded[i];
            }
            stringMemoryPtr += strEncodedLen;
            staticStrings[str] = addr;
            stack.push(addr);
          }
          break;
      }
    }
  }

  void registerExitCallback(void Function(int code) callback) {
    exitCallbacks.add(callback);
  }
}

class MemoryOverflowError implements Exception {
  final String message;

  MemoryOverflowError(this.message);
}