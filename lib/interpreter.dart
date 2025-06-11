

import 'dart:typed_data';

import 'package:dorth/dorth.dart';
import 'package:dorth/stack.dart';
import 'package:dorth/syscall_emulations.dart';

typedef ExitCallback = void Function (int code);

class Interpreter {
  final Stack<int> stack = Stack();
  final Uint8List memory;
  final List<ExitCallback> exitCallbacks = [];

  Interpreter({int memoryCapacity = 65_000}) : memory = Uint8List(memoryCapacity);

  void interpret(List<Op> program) {
    for (int ip = 0; ip < program.length; ip++) {
      Op op = program[ip];
      switch (op.code) {
        case .push:
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
          stack.push(0);
          break;
        case .store:
          final byte = stack.pop();
          final offset = stack.pop();
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
      }
    }
  }

  void registerExitCallback(void Function(int code) callback) {
    exitCallbacks.add(callback);
  }
}