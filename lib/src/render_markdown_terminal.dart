import 'dart:convert';

import 'package:markdown/markdown.dart';
import 'package:meta/meta.dart';

String markdownInTerminal(String markdown,
    {int indentation = 0, int lineWidth = 80}) {
  // Replace windows line endings with unix line endings, and split.
  var lines = markdown.replaceAll('\r\n', '\n').split('\n');

  final nodes = Document().parseLines(lines);
  final buffer = StringBuffer();
  for (final n in nodes) {
    n.accept(
        _RenderVisitor(buffer, indentation: indentation, lineWidth: lineWidth));
  }
  return buffer.toString();
}

class _RenderVisitor extends NodeVisitor {
  final StringBuffer _buffer;
  final int indentation;
  final int lineWidth;
  final String indentationText;
  int _position = 0;

  _RenderVisitor(this._buffer,
      {@required this.indentation, @required this.lineWidth})
      : indentationText = ' ' * indentation;

  @override
  void visitElementAfter(Element element) {
    if (const ['h1', 'h2', 'h3', 'h4', 'h5', 'h6'].contains(element.tag)) {
      _buffer.writeln();
      _buffer.writeln();
    }
    if (element.tag == 'p') {
      _newline();
    }
  }

  @override
  bool visitElementBefore(Element element) {
    print('visiting <${element.tag} ${element.attributes}');
    if (element.tag == 'code') {
      _newline();
      _buffer.write(indentationText);
      _buffer.write((element.children.single as Text)
          .text
          .replaceAll('\n', '\n$indentationText'));
      return false;
    } else if (element.tag == 'a') {
    } else if (element.tag == 'p') {
      _indent();
    } else if (const ['h1', 'h2', 'h3', 'h4', 'h5', 'h6']
        .contains(element.tag)) {
      _newline();
      _indent();
      _writeBlock('#' * int.parse(element.tag.substring(1)));
    }
    return true;
  }

  @override
  void visitText(Text text) {
    print('visiting `${text.text}`');
    _writeParagraph(text.text);
  }

  void _writeBlock(String s) {
    if (_position + s.length > lineWidth) {
      _newline();
      _indent();
    }
    _buffer.write(s);
    _position += s.length;
  }

  void _newline() {
    _buffer.writeln();
    _position = 0;
  }

  void _indent() {
    _writeBlock(indentationText);
  }

  void _writeParagraph(String s) {
    for (final line in LineSplitter.split(s)) {
      if (line == '') {
        _buffer.writeln();
        continue;
      }
      var first = true;
      for (final word in line.split(RegExp('\\s+'))) {
        _buffer.write(first ? word : ' $word');
        first = false;
      }
    }
  }
}
