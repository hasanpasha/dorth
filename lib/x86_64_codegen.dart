import 'package:dorth/code_gen.dart';
import 'package:dorth/parser.dart';

enum AssemblySection {
  top,
  code,
  data,
  bss,
}

class X8664Codegen extends CodeGen {
  final StringBuffer output = StringBuffer();
  final List<Op> ops;
  final int bssCapacity;

  final Map<AssemblySection, StringBuffer> sections = {
    .top: StringBuffer(),
    .code: StringBuffer(), 
    .data: StringBuffer(), 
    .bss: StringBuffer(),
  };

  X8664Codegen({required this.ops, int? bssCapacity}) 
    : bssCapacity = bssCapacity ?? 65000;

  void writeln(String str, [AssemblySection section = .code]) {
    sections[section]!.writeln(str);
  }

  void writeAll(List<Object> objs, [AssemblySection section = .code]) {
    for (var obj in objs) {
      writeln(obj.toString(), section);
    }
  }

  @override
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

  String finish() {
    output.writeln(".intel_syntax noprefix");
    output.writeln(sections[AssemblySection.top].toString());
    output.writeln(".section .bss");
    output.writeln(sections[AssemblySection.bss].toString());
    output.writeln(".section .data");
    output.writeln(sections[AssemblySection.data].toString());
    output.writeln(".section .text");
    output.writeln(sections[AssemblySection.code].toString());
    return output.toString();
  }

  @override
  void comment(String comment) => writeln("// $comment");
  
  @override
  void add(String reg1, String reg2) => writeln("add $reg1, $reg2");

  @override
  void sub(String reg1, String reg2) => writeln("sub $reg1, $reg2");

  @override
  void push(Object operand) => writeln("push $operand");
  
  @override
  void pop(String reg) => writeln("pop $reg");
  
  @override
  String generate() {
    defineDump();
    
    writeln(".comm mem, $bssCapacity", .bss);

    writeAll([
      ".global _start",
      "_start:",
    ]);

    for (int ip = 0; ip < ops.length; ip++) {
      final op = ops[ip];
      switch (op.code) {
        case .push:
          comment("push ${op.operand}");
          push(op.operand);
          break;
        case .plus:
          comment("plus");
          pop("rdi");
          pop("rax");
          add("rax", "rdi");
          push("rax");
          break;
        case .minus:
          comment("minus");
          pop("rdi");
          pop("rax");
          sub("rax", "rdi");
          push("rax");
          break;
        case .equal:
          comment("equal");
          writeln("mov rcx, 1");
          pop("rdi");
          pop("rax");
          writeln("cmp rax, rdi");
          writeln("mov rax, 0");
          writeln("cmove rax, rcx");
          push("rax");
          break;
        case .neq:
          comment("equal");
          writeln("mov rcx, 1");
          pop("rdi");
          pop("rax");
          writeln("cmp rax, rdi");
          writeln("mov rax, 0");
          writeln("cmovne rax, rcx");
          push("rax");
          break;
        case .gt:
          comment("gt");
          writeln("mov rcx, 1");
          pop("rdi");
          pop("rax");
          writeln("cmp rax, rdi");
          writeln("mov rax, 0");
          writeln("cmovg rax, rcx");
          push("rax");
          break;
        case .ge:
          comment("ge");
          writeln("mov rcx, 1");
          pop("rdi");
          pop("rax");
          writeln("cmp rax, rdi");
          writeln("mov rax, 0");
          writeln("cmovge rax, rcx");
          push("rax");
          break;
        case .lt:
          comment("lt");
          writeln("mov rcx, 1");
          pop("rdi");
          pop("rax");
          writeln("cmp rax, rdi");
          writeln("mov rax, 0");
          writeln("cmovl rax, rcx");
          push("rax");
          break;
        case .le:
          comment("ge");
          writeln("mov rcx, 1");
          pop("rdi");
          pop("rax");
          writeln("cmp rax, rdi");
          writeln("mov rax, 0");
          writeln("cmovle rax, rcx");
          push("rax");
          break;
        case .dump:
          comment("dump");
          pop("rdi");
          writeln("call dump");
          break;
        case .dup:
          pop("rax");
          push("rax");
          push("rax");
          break;
        case .if_:
          comment("if");
          pop("rax");
          writeln("test rax, rax");
          writeln("jz .label_${op.operand}");
          break;
        case .end:
          comment("end");
          writeln("jmp .label_${op.operand}");
          writeln(".label_$ip:");
          break;
        case .else_:
          comment("else");
          writeln("jmp .label_${op.operand}");
          writeln(".label_$ip:");
          break;
        case .while_:
          comment("while");
          writeln(".label_$ip:");
          break;
        case .do_:
          comment("do");
          pop("rax");
          writeln("test rax, rax");
          writeln("jz .label_${op.operand}");
          break;
        case .mem:
          comment("mem");
          writeln("lea rax, mem[rip]");
          push("rax");
          break;
        case .store:
          comment("store");
          pop("rbx");
          pop("rax");
          writeln("movb [rax], bl");
          break;
        case .load:
          comment("load");
          pop("rax");
          writeln("xor rbx, rbx");
          writeln("mov bl, [rax]");
          push("rbx");
          break;
        case .syscall:
          final registers = ["rdi", "rsi", "rdx", "r10", "r8", "r9"];
          comment("syscall");
          pop("rax"); // syscall number
          final int amount = op.operand;
          for (int i = 0; i < amount && i < registers.length; i++) {
            pop(registers[i]);
          }
          writeln("syscall");
          push("rax");
          comment("done syscall");
          break;
        case .dup2:
          comment("2dup");
          pop("rax");
          pop("rbx");
          push("rbx");
          push("rax");
          push("rbx");
          push("rax");
          break;
        case .drop:
          comment("drop");
          pop("rax");
          break;
        case .shr:
          comment(">>");
          pop("rcx");
          pop("rax");
          writeln("shr rax, cl");
          push("rax");
          break;
        case .shl:
          comment("<<");
          pop("rcx");
          pop("rax");
          writeln("shl rax, cl");
          push("rax");
          break;
        case .bitOr:
          comment("|");
          pop("rcx");
          pop("rax");
          writeln("or rax, rcx");
          push("rax");
          break;
        case .bitAnd:
          comment("&");
          pop("rcx");
          pop("rax");
          writeln("and rax, rcx");
          push("rax");
          break;
        case .swap:
          comment("swap");
          pop("rax");
          pop("rbx");
          push("rax");
          push("rbx");
          break;
        case .over:
          comment("over");
          pop("rax"); // x2
          pop("rbx"); // x1
          push("rbx");// x1
          push("rax"); // x2
          push("rbx"); // x3
          break;
      }
    }

    writeAll([
      "mov rax, 60",
      "mov rdi, 0",
      "syscall",
    ]);

    return finish();
  }
}