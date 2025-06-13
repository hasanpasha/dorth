import 'package:dorth/parser.dart';
import 'package:dorth/x86_64_codegen.dart';

enum Target {
  // ignore: constant_identifier_names
  x86_64_linux_none,
}

abstract class CodeGen {
  @override
  String toString() => throw UnimplementedError();
  
  void push(Object operand);
  
  void pop(String reg);
  
  void add(String reg1, String reg2); 
  
  void sub(String reg1, String reg2); 

  void defineDump();
    
  void comment(String comment);

  static String gen(List<Op> program, {int? memoryCapacity, Target target = .x86_64_linux_none}) {
    late CodeGen generator; 

    switch (target) {
      case Target.x86_64_linux_none:
        generator = X8664Codegen(ops: program, bssCapacity: memoryCapacity);
        break;
    }

    final generatedCode = generator.toString();
    return generatedCode;
  }
}