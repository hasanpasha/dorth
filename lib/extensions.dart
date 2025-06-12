
extension CharExtension on String {
  bool get isWhiteSpace => ['\n', '\t', '\r', ' ', '\f'].contains(this);
}