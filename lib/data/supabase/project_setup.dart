import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:postgres/postgres.dart';

/// Everything the first-launch setup needs to take an empty Supabase project
/// to a working ¡Twins! backend: checking what's there, installing the
/// schema, and deploying the edge functions.

/// Schema version this build of the app expects; must match the number
/// returned by `twins_schema_version()` in the newest migration.
const requiredSchemaVersion = 20;

const edgeFunctions = ['resolve-link', 'suggest-tags', 'name-chat', 'notify'];

/// The shared push relay every project's `notify` function forwards to (see
/// supabase/relay/push-relay). Baked in at build time from supabase/.env by
/// the build scripts; when empty, projects are set up without push.
const _relayUrl = String.fromEnvironment('TWINS_RELAY_URL');
const _relayKey = String.fromEnvironment('TWINS_RELAY_KEY');

class ProjectStatus {
  final int schemaVersion;
  final List<String> missingFunctions;

  const ProjectStatus({required this.schemaVersion, required this.missingFunctions});

  bool get schemaReady => schemaVersion >= requiredSchemaVersion;
}

class SetupException implements Exception {
  final String message;
  const SetupException(this.message);

  @override
  String toString() => message;
}

String projectRefFromUrl(String url) => Uri.parse(url).host.split('.').first;

/// Talks to the project with only its URL and publishable key, so it works
/// before anything is installed.
Future<ProjectStatus> probeProject(String url, String publishableKey) async {
  final headers = {'apikey': publishableKey, 'Authorization': 'Bearer $publishableKey', 'Content-Type': 'application/json'};

  final http.Response versionResponse;
  try {
    versionResponse = await http
        .post(Uri.parse('$url/rest/v1/rpc/twins_schema_version'), headers: headers, body: '{}')
        .timeout(const Duration(seconds: 15));
  } catch (_) {
    throw const SetupException("Couldn't reach that project. Double-check the URL.");
  }
  if (versionResponse.statusCode == 401 || versionResponse.statusCode == 403) {
    throw const SetupException('The project rejected that key. Use the publishable (anon) key.');
  }

  final int schemaVersion;
  if (versionResponse.statusCode == 200) {
    schemaVersion = int.tryParse(versionResponse.body.trim()) ?? 0;
  } else if (versionResponse.statusCode == 404) {
    // PostgREST answers 404 for an unknown RPC: nothing installed yet, or a
    // schema older than the version function itself.
    schemaVersion = 0;
  } else {
    throw SetupException('Unexpected answer from the project (${versionResponse.statusCode}).');
  }

  final missing = <String>[];
  for (final name in edgeFunctions) {
    final response = await http
        .post(Uri.parse('$url/functions/v1/$name'), headers: headers, body: '{}')
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 404 && response.body.contains('NOT_FOUND')) missing.add(name);
  }

  return ProjectStatus(schemaVersion: schemaVersion, missingFunctions: missing);
}

/// Applies every bundled migration the database doesn't have yet, each in
/// its own transaction, and records it where the Supabase CLI looks
/// (`supabase_migrations.schema_migrations`) so `supabase db push` and this
/// installer never disagree. The connection string is used for this call
/// only and never stored.
Future<void> installSchema(String connectionString, {void Function(String step)? onStep}) async {
  final Endpoint endpoint;
  try {
    endpoint = _endpointFromConnectionString(connectionString);
  } catch (_) {
    throw const SetupException('That doesn\'t look like a connection string (postgresql://…).');
  }

  final Connection connection;
  try {
    connection = await Connection.open(endpoint, settings: const ConnectionSettings(sslMode: SslMode.require));
  } catch (e) {
    final text = e.toString();
    if (text.contains('password authentication failed') || text.contains('28P01')) {
      throw const SetupException('Wrong database password in the connection string.');
    }
    throw const SetupException("Couldn't connect to the database. Use the Session pooler string from Connect → Session pooler.");
  }

  try {
    await connection.execute(
      'create schema if not exists supabase_migrations; '
      'create table if not exists supabase_migrations.schema_migrations (version text primary key, statements text[], name text);',
      queryMode: QueryMode.simple,
    );
    final applied = (await connection.execute('select version from supabase_migrations.schema_migrations'))
        .map((row) => row[0] as String)
        .toSet();

    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final migrations = manifest.listAssets().where((a) => a.startsWith('supabase/migrations/') && a.endsWith('.sql')).toList()..sort();

    for (final asset in migrations) {
      final fileName = asset.split('/').last.replaceAll('.sql', '');
      final separator = fileName.indexOf('_');
      final version = fileName.substring(0, separator);
      final name = fileName.substring(separator + 1);
      if (applied.contains(version)) continue;

      onStep?.call(name.replaceAll('_', ' '));
      final sql = await rootBundle.loadString(asset);
      try {
        await connection.runTx((tx) async {
          await tx.execute(sql, queryMode: QueryMode.simple);
          await tx.execute(
            Sql.named('insert into supabase_migrations.schema_migrations (version, name) values (@version, @name)'),
            parameters: {'version': version, 'name': name},
          );
        });
      } on ServerException catch (e) {
        throw SetupException('Setting up "$name" failed: ${e.message}');
      }
    }
  } finally {
    await connection.close();
  }
}

Endpoint _endpointFromConnectionString(String connectionString) {
  final uri = Uri.parse(connectionString.trim());
  if (uri.scheme != 'postgres' && uri.scheme != 'postgresql') throw const FormatException();
  final userInfo = uri.userInfo.split(':');
  return Endpoint(
    host: uri.host,
    port: uri.hasPort ? uri.port : 5432,
    database: uri.pathSegments.isEmpty ? 'postgres' : uri.pathSegments.first,
    username: Uri.decodeComponent(userInfo.first),
    password: userInfo.length > 1 ? Uri.decodeComponent(userInfo.sublist(1).join(':')) : null,
  );
}

/// Deploys the bundled edge functions and the Groq secret through the
/// Supabase Management API, which needs a personal access token
/// (supabase.com/dashboard/account/tokens). Neither value is stored.
/// Returns each function's new version number, as Supabase reports it.
Future<Map<String, int?>> deployEdgeFunctions({
  required String projectUrl,
  required String accessToken,
  String? groqApiKey,
  void Function(String step)? onStep,
}) async {
  final ref = projectRefFromUrl(projectUrl);
  final base = 'https://api.supabase.com/v1/projects/$ref';
  final auth = {'Authorization': 'Bearer ${accessToken.trim()}'};

  final versions = <String, int?>{};
  for (final name in edgeFunctions) {
    onStep?.call(name);
    final source = await rootBundle.loadString('supabase/functions/$name/index.ts');
    final request = http.MultipartRequest('POST', Uri.parse('$base/functions/deploy?slug=$name'))
      ..headers.addAll(auth)
      ..fields['metadata'] = jsonEncode({'entrypoint_path': 'index.ts', 'name': name, 'verify_jwt': true})
      ..files.add(http.MultipartFile.fromString('file', source, filename: 'index.ts'));
    final response = await http.Response.fromStream(await request.send());
    if (response.statusCode == 401) {
      throw const SetupException('Supabase rejected that access token.');
    }
    if (response.statusCode >= 300) {
      throw SetupException('Deploying $name failed (${response.statusCode}): ${response.body}');
    }
    final body = jsonDecode(response.body);
    versions[name] = body is Map ? (body['version'] as num?)?.toInt() : null;
  }

  final groq = groqApiKey?.trim() ?? '';
  final secrets = [
    if (groq.isNotEmpty) {'name': 'GROQ_API_KEY', 'value': groq},
    // Lets this project's notify function reach the push relay.
    if (_relayUrl.isNotEmpty && _relayKey.isNotEmpty) ...[
      {'name': 'TWINS_RELAY_URL', 'value': _relayUrl},
      {'name': 'TWINS_RELAY_KEY', 'value': _relayKey},
    ],
  ];
  if (secrets.isNotEmpty) {
    onStep?.call('settings');
    final response = await http.post(
      Uri.parse('$base/secrets'),
      headers: {...auth, 'Content-Type': 'application/json'},
      body: jsonEncode(secrets),
    );
    if (response.statusCode >= 300) {
      throw SetupException('Saving function settings failed (${response.statusCode}): ${response.body}');
    }
  }
  return versions;
}
