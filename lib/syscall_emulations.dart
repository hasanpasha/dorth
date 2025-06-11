import 'dart:typed_data';
import 'dart:io';

import 'package:dorth/dorth.dart';
import 'package:dorth/stack.dart';
import 'package:dorth/interpreter.dart';

class SyscallException implements Exception {
  final Location location;
  final String message;

  SyscallException(this.location, this.message);

  @override
  String toString() => "$location: $message";
}

class SyscallEmulation {
  final Op op;
  // final Stack<int> stack;
  // final Uint8List memory;
  final Interpreter interpreter;
  final int syscallNumber;

  SyscallEmulation(this.op, this.interpreter) : syscallNumber = interpreter.stack.pop();

  Stack<int> get stack => interpreter.stack;
  Uint8List get memory => interpreter.memory;
  int get syscallArgsNumber => op.operand;
  Location get location => op.location;

  Map<int, int Function()> get syscallsServer => {
    1: _write, 
    60: _exit, 
  };
  

  int _write() {
    if (syscallArgsNumber != 3) throw SyscallException(location, "`write` syscall requires 3 arguments");
    final fd = stack.pop();
    final addr = stack.pop();
    final count = stack.pop();

    final string = String.fromCharCodes(memory.sublist(addr, count));
    switch (fd) {
      case 0:
        throw UnsupportedError("writing to `stdin` is not supported in emulation.");
      case 1:
        stdout.write(string);
      case 2:
        stderr.write(string);
    }
    return count;
  }

  int _exit() {
    if (syscallArgsNumber != 1) throw SyscallException(location, "`exit` syscall requires 1 arguments");
    final code = stack.pop();

    for (final callback in interpreter.exitCallbacks) {
      callback(code);
    }

    exit(code);
  }

  static int emulate(Op op, Interpreter interpret) {
    final emulator = SyscallEmulation(op, interpret);

    final server = emulator.syscallsServer[emulator.syscallNumber];
    if (server == null) throw UnimplementedError("syscall with number ${emulator.syscallNumber} is not implemented yet.");
    return server();
  } 
}