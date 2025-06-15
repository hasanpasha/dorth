
extension CharExtension on String {
  bool get isWhiteSpace => ['\n', '\t', '\r', ' ', '\f'].contains(this);
  bool get isDigit => ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'].contains(this);
}

extension UriPathExtension on Uri {
  String baseFilename() {
    return pathSegments.last;
  }

  String baseFilenameWithoutExtension() {
    final parts = baseFilename().split('.');
    if (parts.length == 1) return parts.first;
    parts.removeLast();
    return parts.join();
  }

  Uri replaceExtension(String newExtension) {
    final newFilenamem = "${baseFilenameWithoutExtension()}$newExtension";
    final pathSegms = pathSegments.toList();
    pathSegms.removeLast();
    pathSegms.add(newFilenamem);
    final newPath = replace(pathSegments: pathSegms);
    return newPath;
  }
}