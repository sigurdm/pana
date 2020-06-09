// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:pana/src/download_utils.dart';
import 'package:pana/src/maintenance.dart';
import 'package:pana/src/model.dart';
import 'package:pana/src/package_analyzer.dart' show InspectOptions;
import 'package:pana/src/pubspec.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

const _withIssuesJson = {
  'missingChangelog': true,
  'missingExample': true,
  'missingReadme': true,
  'missingAnalysisOptions': true,
  'oldAnalysisOptions': false,
  'strongModeEnabled': true,
  'isExperimentalVersion': true,
  'isPreReleaseVersion': true,
  'dartdocSuccessful': false,
  'suggestions': [
    {
      'code': 'pubspec.sdk.missing',
      'level': 'error',
      'title': 'Add an `sdk` field to `pubspec.yaml`.',
      'description':
          'For information about setting the SDK constraint, see [https://www.dartlang.org/tools/pub/pubspec#sdk-constraints](https://www.dartlang.org/tools/pub/pubspec#sdk-constraints).',
      'score': 50.0
    },
    {
      'code': 'pubspec.sdk.devOnly',
      'level': 'error',
      'title': 'Support future stable Dart 2 SDKs in `pubspec.yaml`.',
      'description':
          'The SDK constraint in `pubspec.yaml` doesn\'t allow future stable Dart 2.x SDK releases.',
      'score': 20.0
    },
    {
      'code': 'sdk.missing',
      'level': 'error',
      'title': 'No valid SDK.',
      'description':
          'The analysis could not detect a valid SDK that can use this package.',
      'score': 20.0,
    },
    {
      'code': 'dartdoc.aborted',
      'level': 'error',
      'title':
          'Make sure `dartdoc` successfully runs on your package\'s source files.',
      'description': 'Running `dartdoc` failed with the following output:\n'
          '\n'
          '```\n'
          '\n'
          '```\n'
          '',
      'score': 10.0
    },
    {
      'code': 'readme.missing',
      'level': 'warning',
      'title': 'Provide a file named `README.md`.',
      'description':
          'The `README.md` file should inform others about your project, what it does, and how they can use it. See the [example](https://raw.githubusercontent.com/dart-lang/stagehand/master/templates/package-simple/README.md) generated by `stagehand`.',
      'score': 30.0
    },
    {
      'code': 'changelog.missing',
      'level': 'warning',
      'title': 'Provide a file named `CHANGELOG.md`.',
      'description':
          'Changelog entries help developers follow the progress of your package. See the [example](https://raw.githubusercontent.com/dart-lang/stagehand/master/templates/package-simple/CHANGELOG.md) generated by `stagehand`.',
      'score': 20.0
    },
    {
      'code': 'pubspec.dependencies.unconstrained',
      'level': 'warning',
      'title': 'Use constrained dependencies.',
      'description':
          'The `pubspec.yaml` contains 1 dependency without version constraints. Specify version ranges for the following dependencies: `foo`.',
      'score': 20.0
    },
    {
      'code': 'pubspec.description.tooShort',
      'level': 'warning',
      'title': 'Add `description` in `pubspec.yaml`.',
      'description':
          'The description gives users information about the features of your package and why it is relevant to their query. We recommend a description length of 60 to 180 characters.',
      'score': 20.0
    },
    {
      'code': 'pubspec.homepage.isNotHelpful',
      'level': 'warning',
      'title': 'Homepage URL isn\'t helpful.',
      'description':
          'Update the `homepage` field from `pubspec.yaml`: link to a website about the package or use the source repository URL.',
      'score': 10.0
    },
    {
      'code': 'packageVersion.preV01',
      'level': 'hint',
      'title': 'Package is pre-v0.1 release.',
      'description':
          'While nothing is inherently wrong with versions of `0.0.*`, it might mean that the author is still experimenting with the general direction of the API.',
      'score': 10.0
    },
    {
      'code': 'packageVersion.preRelease',
      'level': 'hint',
      'title': 'Package is pre-release.',
      'description':
          'Pre-release versions should be used with caution; their API can change in breaking ways.',
      'score': 5.0
    }
  ]
};

final _perfect = Maintenance(
  missingChangelog: false,
  missingReadme: false,
  missingExample: false,
  missingAnalysisOptions: false,
  oldAnalysisOptions: false,
  strongModeEnabled: true,
  isExperimentalVersion: false,
  isPreReleaseVersion: false,
  dartdocSuccessful: true,
);

final _withIssues = Maintenance.fromJson(_withIssuesJson);

void main() {
  group('detectMaintenance', () {
    test('empty directory', () async {
      final pkgResolution = PkgResolution([
        PkgDependency(
          package: 'foo',
          dependencyType: 'direct',
          constraintType: 'empty',
          constraint: null,
          resolved: null,
          available: null,
          errors: null,
        ),
      ]);
      final maintenance = await detectMaintenance(
        InspectOptions(),
        UrlChecker(),
        d.sandbox,
        Pubspec.fromJson({'name': 'sandbox', 'version': '0.0.1-alpha'}),
        null,
        dartdocSuccessful: false,
        pkgResolution: pkgResolution,
        tags: [],
      );

      expect(json.decode(json.encode(maintenance.toJson())), _withIssuesJson);
    });
  });

  group('Old Flutter plugin format', () {
    test('old flutter plugin format gets suggestion', () async {
      final maintenance = await detectMaintenance(
        InspectOptions(),
        UrlChecker(),
        d.sandbox,
        Pubspec.fromJson({
          'name': 'example',
          'description': 'A description of example that contains '
              ' just exactly a bit more than 60 characters.',
          'version': '1.0.0',
          'environment': {'sdk': '>=2.3.0 <3.0.0'},
          'flutter': {
            'plugin': {'androidPackage': 'pkg'}
          }
        }),
        null,
        tags: [],
        dartdocSuccessful: false,
        pkgResolution: PkgResolution([]),
      );
      expect(
          maintenance.suggestion,
          contains(predicate((Suggestion suggestion) =>
              suggestion.code ==
              SuggestionCode.pubspecUsesOldFlutterPluginFormat)));
    });
    test('new flutter plugin format gets no suggestion', () async {
      final maintenance = await detectMaintenance(
        InspectOptions(),
        UrlChecker(),
        d.sandbox,
        Pubspec.fromJson({
          'name': 'example',
          'description': 'A description of example that contains '
              ' just exactly a bit more than 60 characters.',
          'version': '1.0.0',
          'environment': {'sdk': '>=2.3.0 <3.0.0'},
          'flutter': {
            'plugin': {
              'platforms': {'ios': {}}
            }
          }
        }),
        null,
        tags: [],
        dartdocSuccessful: false,
        pkgResolution: PkgResolution([]),
      );
      expect(
          maintenance.suggestion.where((s) =>
              s.code == SuggestionCode.pubspecUsesOldFlutterPluginFormat),
          isEmpty);
    });
  });

  group('getMaintenanceScore', () {
    test('with issues', () {
      expect(calculateMaintenanceScore(_withIssues), 0.0);
    });

    test('perfect', () {
      expect(calculateMaintenanceScore(_perfect), 1.0);
    });

    group('publish date affects score', () {
      final expectedScores = {
        -1: 1.0, // possible for time issues to be off – treated as 'now'
        0: 1.0,
        1: 1.0,
        365: 1.0,
        (365 * 1.5).toInt(): 0.50,
        365 * 2: 0.0
      };

      for (var offset in expectedScores.keys) {
        test('from $offset days ago', () {
          final age = offset == null ? null : Duration(days: offset);
          final expectedScore = expectedScores[offset];

          Matcher matcher;
          if (expectedScore == expectedScore.toInt().toDouble()) {
            // we expect an exact match
            matcher = equals(expectedScore);
          } else {
            // we expect a close match
            matcher = closeTo(expectedScore, 0.01);
          }

          expect(calculateMaintenanceScore(_perfect, age: age), matcher);
        });
      }
    });
  });

  group('Age-based suggestion', () {
    test('young package', () {
      expect(getAgeSuggestion(const Duration(days: 10)), isNull);
    });

    test('age: one and half years', () {
      final suggestion = getAgeSuggestion(const Duration(days: 555));
      expect(suggestion, isNotNull);
      expect(suggestion.title, 'Package is getting outdated.');
      expect(suggestion.level, 'hint');
      expect(suggestion.score, closeTo(52.05, 0.01));
    });

    test('age: two and half years', () {
      final suggestion = getAgeSuggestion(const Duration(days: 910));
      expect(suggestion, isNotNull);
      expect(suggestion.title, 'Package is too old.');
      expect(suggestion.level, 'warning');
      expect(suggestion.score, 100.0);
    });
  });
}
