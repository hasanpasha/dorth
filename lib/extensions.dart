
extension CharExtension on String {
  bool get isWhiteSpace => ['\n', '\t', '\r', ' ', '\f'].contains(this);
  bool get isDigit => ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'].contains(this);
}