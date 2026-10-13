import 'dart:convert';
import 'dart:io';
import 'package:dnd_frontend/models/creation_catalog.dart';

CreationCatalog testCatalog() => CreationCatalog.fromJson(
    jsonDecode(File('test/fixtures/creation_catalog.json').readAsStringSync()));
