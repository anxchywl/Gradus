import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import '../domain/errors.dart';
import '../domain/repositories.dart';
import '../domain/syllabus.dart';

// refuse a file this size before reading it into memory; the server caps it
// again, because a client-side limit protects the device rather than the server
const int maximumSyllabusBytes = 4 * 1024 * 1024;

const int _maximumCodeLength = 24;
const int _maximumTitleLength = 120;
const int _maximumUnitLength = 16;
const int _maximumTermLength = 60;
const int _maximumNameLength = 80;
const int _maximumAssessments = 40;

class HttpSyllabusImporter implements SyllabusImporter {
  HttpSyllabusImporter({
    required this.baseUri,
    required this.accessToken,
    http.Client? client,
    Future<List<int>?> Function()? pickFile,
  }) : _client = client ?? http.Client(),
       _pickFile = pickFile ?? _pickWithPlatformPicker;

  final Uri baseUri;
  final String accessToken;
  final http.Client _client;
  final Future<List<int>?> Function() _pickFile;

  @override
  Future<SyllabusDraft?> importFromFile() async {
    final bytes = await _pickFile();
    if (bytes == null) return null;
    if (bytes.length > maximumSyllabusBytes) {
      throw const SyllabusImportFailure(SyllabusImportProblem.tooLarge);
    }
    // checked here as well so an obvious mistake costs no request at all
    final contentType = _contentTypeOf(bytes);
    if (contentType == null) {
      throw const SyllabusImportFailure(SyllabusImportProblem.unsupportedType);
    }

    final http.Response response;
    try {
      response = await _client.post(
        baseUri.resolve('api/v1/syllabus-extractions'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': contentType,
          'Idempotency-Key': _idempotencyKey(),
        },
        body: bytes,
      );
    } on http.ClientException {
      throw const SyllabusImportFailure(SyllabusImportProblem.network);
    } on SocketException {
      throw const SyllabusImportFailure(SyllabusImportProblem.network);
    }

    if (response.statusCode != 200) {
      throw SyllabusImportFailure(_problemOf(response));
    }
    return _draftFrom(response.body);
  }

  // the key must differ per document but repeat on a retry of the same one
  String _idempotencyKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  // the extension the picker filtered on is a claim about the file; the bytes
  // are what the server will judge it by, so they decide here too
  String? _contentTypeOf(List<int> bytes) {
    const pdf = [0x25, 0x50, 0x44, 0x46, 0x2d];
    const zip = [0x50, 0x4b, 0x03, 0x04];
    if (_startsWith(bytes, pdf)) return 'application/pdf';
    if (_startsWith(bytes, zip)) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    return null;
  }

  bool _startsWith(List<int> bytes, List<int> magic) {
    if (bytes.length < magic.length) return false;
    for (var index = 0; index < magic.length; index++) {
      if (bytes[index] != magic[index]) return false;
    }
    return true;
  }

  SyllabusImportProblem _problemOf(http.Response response) {
    if (response.statusCode == 429) return SyllabusImportProblem.rateLimited;
    if (response.statusCode == 413) return SyllabusImportProblem.tooLarge;
    final code = _errorCodeOf(response.body);
    return switch (code) {
      'document_unsupported_type' => SyllabusImportProblem.unsupportedType,
      'document_too_large' => SyllabusImportProblem.tooLarge,
      'document_encrypted' => SyllabusImportProblem.encrypted,
      'document_has_no_text' => SyllabusImportProblem.noText,
      _ => SyllabusImportProblem.unavailable,
    };
  }

  String? _errorCodeOf(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return null;
      final error = decoded['error'];
      if (error is! Map<String, dynamic>) return null;
      final code = error['code'];
      return code is String ? code : null;
    } on FormatException {
      return null;
    }
  }

  SyllabusDraft _draftFrom(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const SyllabusImportFailure(SyllabusImportProblem.unavailable);
    }
    if (decoded is! Map<String, dynamic>) {
      throw const SyllabusImportFailure(SyllabusImportProblem.unavailable);
    }
    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw const SyllabusImportFailure(SyllabusImportProblem.unavailable);
    }

    final assessments = <SyllabusAssessment>[];
    final entries = data['assessments'];
    if (entries is List) {
      for (final entry in entries.take(_maximumAssessments)) {
        if (entry is! Map<String, dynamic>) continue;
        final name = sanitizeImported(
          entry['name'] is String ? entry['name'] as String : null,
          limit: _maximumNameLength,
        );
        final weight = sanitizeWeight(_doubleOf(entry['weight']));
        // an entry missing either half would be a name with no weight, which
        // is what a schedule row looks like
        if (name == null || weight == null) continue;
        assessments.add(SyllabusAssessment(name: name, weight: weight));
      }
    }

    final draft = SyllabusDraft(
      code: sanitizeImported(
        _stringOf(data['code']),
        limit: _maximumCodeLength,
      ),
      title: sanitizeImported(
        _stringOf(data['title']),
        limit: _maximumTitleLength,
      ),
      credits: sanitizeCredits(_doubleOf(data['credits'])),
      creditUnit: sanitizeImported(
        _stringOf(data['creditUnit']),
        limit: _maximumUnitLength,
      ),
      term: sanitizeImported(
        _stringOf(data['term']),
        limit: _maximumTermLength,
      ),
      assessments: assessments,
    );

    if (draft.isEmpty) {
      throw const SyllabusImportFailure(SyllabusImportProblem.nothingFound);
    }
    return draft;
  }

  String? _stringOf(Object? value) => value is String ? value : null;

  double? _doubleOf(Object? value) => value is num ? value.toDouble() : null;
}

Future<List<int>?> _pickWithPlatformPicker() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['pdf', 'docx'],
    withData: true,
  );
  final bytes = result?.files.singleOrNull?.bytes;
  return bytes;
}
