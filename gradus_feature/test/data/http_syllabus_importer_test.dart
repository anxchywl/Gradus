import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gradus_feature/src/data/http_syllabus_importer.dart';
import 'package:gradus_feature/src/domain/errors.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final Uri base = Uri.parse('https://gradus.example.test/');
final List<int> pdfBytes = utf8.encode('%PDF-1.4 a syllabus');

String body(Map<String, Object?> data) => jsonEncode({
  'data': data,
  'meta': {'request_id': 'r-1'},
});

String errorBody(String code) => jsonEncode({
  'error': {'code': code, 'message': 'no', 'request_id': 'r-1'},
});

HttpSyllabusImporter importerFor(
  MockClient client, {
  List<int>? picked = const [],
}) => HttpSyllabusImporter(
  baseUri: base,
  accessToken: 'a-token',
  client: client,
  pickFile: () async => picked != null && picked.isEmpty ? pdfBytes : picked,
);

void main() {
  test('a draft is read out of the response', () async {
    final importer = importerFor(
      MockClient(
        (request) async => http.Response(
          body({
            'code': 'MATH 273',
            'title': 'Linear Algebra',
            'credits': 8,
            'creditUnit': 'ECTS',
            'term': 'Fall 2026',
            'assessments': [
              {'name': 'Midterm', 'weight': 40},
            ],
          }),
          200,
        ),
      ),
    );

    final draft = await importer.importFromFile();

    expect(draft!.code, 'MATH 273');
    expect(draft.creditUnit, 'ECTS');
    expect(draft.assessments.single.name, 'Midterm');
  });

  test('the token and the document travel as the server expects', () async {
    late http.Request seen;
    final importer = importerFor(
      MockClient((request) async {
        seen = request;
        return http.Response(body({'code': 'MATH 273'}), 200);
      }),
    );

    await importer.importFromFile();

    expect(seen.headers['Authorization'], 'Bearer a-token');
    expect(seen.headers['Content-Type'], 'application/pdf');
    expect(seen.headers['Idempotency-Key']!.length, greaterThanOrEqualTo(16));
    expect(seen.url.path, '/api/v1/syllabus-extractions');
    expect(seen.bodyBytes, pdfBytes);
  });

  test('a cancelled picker is not a failure', () async {
    var called = false;
    final importer = importerFor(
      MockClient((request) async {
        called = true;
        return http.Response(body({}), 200);
      }),
      picked: null,
    );

    expect(await importer.importFromFile(), isNull);
    expect(called, isFalse);
  });

  test('a file that is not a pdf never reaches the network', () async {
    var called = false;
    final importer = importerFor(
      MockClient((request) async {
        called = true;
        return http.Response(body({}), 200);
      }),
      picked: utf8.encode('MZ an executable'),
    );

    await expectLater(
      importer.importFromFile(),
      throwsA(
        isA<SyllabusImportFailure>().having(
          (failure) => failure.problem,
          'problem',
          SyllabusImportProblem.notAPdf,
        ),
      ),
    );
    expect(called, isFalse);
  });

  test('an oversized file never reaches the network', () async {
    var called = false;
    final importer = importerFor(
      MockClient((request) async {
        called = true;
        return http.Response(body({}), 200);
      }),
      picked: List<int>.filled(maximumSyllabusBytes + 1, 0x25),
    );

    await expectLater(
      importer.importFromFile(),
      throwsA(isA<SyllabusImportFailure>()),
    );
    expect(called, isFalse);
  });

  test('a response with nothing usable in it is a failure', () async {
    final importer = importerFor(
      MockClient((request) async => http.Response(body({}), 200)),
    );

    await expectLater(
      importer.importFromFile(),
      throwsA(
        isA<SyllabusImportFailure>().having(
          (failure) => failure.problem,
          'problem',
          SyllabusImportProblem.nothingFound,
        ),
      ),
    );
  });

  test('an entry missing a name or a weight is dropped', () async {
    final importer = importerFor(
      MockClient(
        (request) async => http.Response(
          body({
            'code': 'MATH 273',
            'assessments': [
              {'name': 'Speech Due'},
              {'weight': 20},
              {'name': '   ', 'weight': 10},
              {'name': 'Final', 'weight': 60},
            ],
          }),
          200,
        ),
      ),
    );

    final draft = await importer.importFromFile();

    expect(draft!.assessments.map((entry) => entry.name), ['Final']);
  });

  test('a weight the domain would refuse is dropped', () async {
    final importer = importerFor(
      MockClient(
        (request) async => http.Response(
          body({
            'code': 'MATH 273',
            'credits': 9999,
            'assessments': [
              {'name': 'Midterm', 'weight': 4000},
              {'name': 'Final', 'weight': 60},
            ],
          }),
          200,
        ),
      ),
    );

    final draft = await importer.importFromFile();

    expect(draft!.credits, isNull);
    expect(draft.assessments.map((entry) => entry.name), ['Final']);
  });

  test('each refusal keeps its own meaning', () async {
    final cases = <String, SyllabusImportProblem>{
      'document_not_a_pdf': SyllabusImportProblem.notAPdf,
      'document_encrypted': SyllabusImportProblem.encrypted,
      'document_has_no_text': SyllabusImportProblem.noText,
      'extraction_unavailable': SyllabusImportProblem.unavailable,
    };
    for (final entry in cases.entries) {
      final importer = importerFor(
        MockClient((request) async => http.Response(errorBody(entry.key), 422)),
      );

      await expectLater(
        importer.importFromFile(),
        throwsA(
          isA<SyllabusImportFailure>().having(
            (failure) => failure.problem,
            entry.key,
            entry.value,
          ),
        ),
      );
    }
  });

  test('a refused rate limit is reported as one', () async {
    final importer = importerFor(
      MockClient(
        (request) async => http.Response(errorBody('rate_limited'), 429),
      ),
    );

    await expectLater(
      importer.importFromFile(),
      throwsA(
        isA<SyllabusImportFailure>().having(
          (failure) => failure.problem,
          'problem',
          SyllabusImportProblem.rateLimited,
        ),
      ),
    );
  });

  test('an unreachable server is reported as a connection problem', () async {
    final importer = importerFor(
      MockClient((request) async => throw http.ClientException('no route')),
    );

    await expectLater(
      importer.importFromFile(),
      throwsA(
        isA<SyllabusImportFailure>().having(
          (failure) => failure.problem,
          'problem',
          SyllabusImportProblem.network,
        ),
      ),
    );
  });
}
