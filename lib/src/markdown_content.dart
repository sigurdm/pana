// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:markdown/markdown.dart';
import 'package:meta/meta.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';

import 'model.dart';

/// The extracted content of a markdown file.
class ExctractedMarkdownContent {
  final List<_Link> images;
  final List<_Link> links;

  ExctractedMarkdownContent({this.images, this.links});

  Map<String, dynamic> toJson() => <String, dynamic>{
        'images': images,
        'links': links,
      };
}

List<T> unique<T>(Iterable<T> l) => [
      ...{...l}
    ];

class _Link {
  final String url;
  final SourceSpan span;
  _Link(this.url, this.span);
}

/// Scans a markdown text and extracts its content.
ExctractedMarkdownContent scanMarkdownText(String text, Uri sourceUrl) {
  final htmlText = markdownToHtml(text);
  final html =
      html_parser.parseFragment(htmlText, sourceUrl: sourceUrl.toString());
  return ExctractedMarkdownContent(
      images: unique(html
          .querySelectorAll('img')
          .where((e) => e.attributes.containsKey('src'))
          .map((e) => _Link(e.attributes['src'], e.sourceSpan))),
      links: unique(html
          .querySelectorAll('a')
          .where((e) => e.attributes.containsKey('href'))
          .map((e) => _Link(e.attributes['src'], e.sourceSpan))));
}

/// Scans a markdown file and extracts its content.
Future<ExctractedMarkdownContent> scanMarkdownFileContent(File file) async {
  final text = await file.readAsString();
  return scanMarkdownText(text, file.uri);
}

/// Analyze a markdown file and return suggestions.
Future<List<Issue>> analyzeMarkdownFile(File file) async {
  final issues = <Issue>[];
  final filename = p.basename(file.path);
  final analysis = await scanMarkdownFileContent(file);
  final checked = await _checkLinks(analysis.images);
  // TODO: warn about relative image URLs
  // TODO: warn about insecure links
  // TODO: warn about relative links
  // TODO: consider checking whether the URL exists and returns HTTP 200.

  if (checked.unparsed.isNotEmpty) {
    final count = checked.unparsed.length;
    final first = checked.unparsed.first;
    final s = count == 1 ? '' : 's';
    issues.add(Issue(
        'Links in $filename should be well formed '
        'Unable to parse $count image links$s.',
        span: first.span));
  }
  if (checked.insecure.isNotEmpty) {
    final count = checked.insecure.length;
    final first = checked.insecure.first;
    final pluralize = count == 1 ? 'link is' : 'links are';
    issues.add(Issue(
        'Links in $filename should be secure. $count image $pluralize insecure.',
        suggestion: 'Use `https` URLs instead.',
        span: first.span));
  }
  return issues;
}

Future<_Links> _checkLinks(List<_Link> links) async {
  final unparsed = <_Link>[];
  final parsed = <_Link>[];
  final insecure = <_Link>[];

  for (var link in links) {
    final uri = Uri.tryParse(link.url);
    if (uri == null) {
      unparsed.add(link);
      continue;
    }
    parsed.add(link);
    if (uri.scheme != null && uri.scheme.isNotEmpty && uri.scheme != 'https') {
      insecure.add(link);
    }
  }
  return _Links(unparsed: unparsed, parsed: parsed, insecure: insecure);
}

class _Links {
  final List<_Link> unparsed;
  final List<_Link> parsed;
  final List<_Link> insecure;

  _Links({
    @required this.unparsed,
    @required this.parsed,
    @required this.insecure,
  });
}
