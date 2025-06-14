import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:dorth/parser.dart';
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
  final Interpreter interpreter;
  final int syscallNumber;

  SyscallEmulation(this.op, this.interpreter) : syscallNumber = interpreter.stack.pop();

  Stack<int> get stack => interpreter.stack;
  Uint8List get memory => interpreter.memory;
  int get syscallArgsNumber => op.operand;
  Location get location => op.location;

  Map<int, int Function()> get syscallsServer => {
    0: _read,
    1: _write, 
    60: _exit, 
  };
  
  int _read() {
    if (syscallArgsNumber != 3) throw SyscallException(location, "`write` syscall requires 3 arguments");

    final fd = stack.pop();
    final addr = stack.pop();
    final count = stack.pop();

    int bytesRead = 1;
    switch (fd) {
      case 0:
        final str = stdin.readLineSync(encoding: Encoding.getByName('utf-8')!, retainNewlines: false);
        if (str != null) {
          final bytes = utf8.encode(str);
          for (var i = 0; i < bytes.length && i < count; i++) {
            memory[addr+i] = bytes[i];
            bytesRead++;
          }
        } else {
          bytesRead = -1;
        }
      case 1:
        throw UnimplementedError("reading from `stdout` is not implemented yet in the interpreter.");
      case 2:
        throw UnimplementedError("reading from `stderr` is not implemented yet in the interpreter..");
      default:
        throw UnimplementedError("reading from arbitrary file descriptor is not implemented yet in the interpreter.");
    }

    return bytesRead;
  }

  int _write() {
    if (syscallArgsNumber != 3) throw SyscallException(location, "`write` syscall requires 3 arguments");
    final fd = stack.pop();
    final addr = stack.pop();
    final count = stack.pop();

    final string = utf8.decode(memory.sublist(addr, addr+count));
    
    switch (fd) {
      case 0:
        throw UnimplementedError("writing to `stdin` is not implemented yet in the interpreter.");
      case 1:
        stdout.write(string);
      case 2:
        stderr.write(string);
      default:
        throw UnimplementedError("writing to arbitrary file descriptor is not implemented yet in the interpreter.");
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