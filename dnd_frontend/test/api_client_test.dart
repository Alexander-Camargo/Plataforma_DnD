import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dnd_frontend/core/api/api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiClient.onUnauthorized = null;
  });
  tearDown(() => ApiClient.onUnauthorized = null);

  test('GET envía el token y decodifica español UTF-8', () async {
    SharedPreferences.setMockInitialValues({'access_token': 'token-prueba'});
    await http.runWithClient(() async {
      final data = await ApiClient().get('/characters/me');
      expect(data['name'], 'Lía, maga del océano');
    },
        () => MockClient((request) async {
              expect(request.headers['Authorization'], 'Bearer token-prueba');
              expect(request.url.path, '/api/v1/characters/me');
              return http.Response.bytes(
                  utf8.encode(jsonEncode({'name': 'Lía, maga del océano'})),
                  200);
            }));
  });
  for (final method in ['POST', 'PATCH', 'DELETE']) {
    test('$method usa el método y cuerpo correctos', () async {
      await http.runWithClient(() async {
        final api = ApiClient();
        if (method == 'POST') await api.post('/characters/', {'name': 'Lina'});
        if (method == 'PATCH') {
          await api.patch('/characters/p1', {'version': 3});
        }
        if (method == 'DELETE') {
          expect(await api.delete('/characters/p1'), isNull);
        }
      },
          () => MockClient((request) async {
                expect(request.method, method);
                if (method == 'POST') {
                  expect(jsonDecode(request.body), {'name': 'Lina'});
                }
                if (method == 'PATCH') {
                  expect(jsonDecode(request.body), {'version': 3});
                }
                expect(request.headers['Content-Type'],
                    contains('application/json'));
                return http.Response(method == 'DELETE' ? '' : '{}',
                    method == 'DELETE' ? 204 : 200);
              }));
    });
  }
  for (final example in [
    (409, '{"detail":"Recarga la página"}', 'Recarga la página'),
    (
      422,
      '{"detail":[{"loc":["body","level"],"msg":"Fuera de rango"}]}',
      'level: Fuera de rango'
    ),
    (503, '<html>Unavailable</html>', 'Error 503'),
  ]) {
    test('Error ${example.$1} conserva código y mensaje', () async {
      await http.runWithClient(() async {
        await expectLater(
            ApiClient().get('/test'),
            throwsA(isA<ApiException>()
                .having((error) => error.statusCode, 'código', example.$1)
                .having((error) => error.message, 'mensaje', example.$3)));
      },
          () => MockClient((_) async => http.Response(example.$2, example.$1,
              headers: {'content-type': 'application/json; charset=utf-8'})));
    });
  }
  test('Fallo de red se convierte en mensaje legible', () async {
    await http.runWithClient(() async {
      await expectLater(
          ApiClient().get('/test'),
          throwsA(isA<ApiException>()
              .having((error) => error.statusCode, 'código', 0)));
    }, () => MockClient((_) async => throw http.ClientException('offline')));
  });
  for (final signedIn in [true, false]) {
    test('401 notifica expiración solo si hay sesión: $signedIn', () async {
      SharedPreferences.setMockInitialValues(
          signedIn ? {'access_token': 'token'} : {});
      var notifications = 0;
      ApiClient.onUnauthorized = () => notifications++;
      await http.runWithClient(() async {
        await expectLater(
            ApiClient().get('/auth/me'), throwsA(isA<ApiException>()));
        await Future<void>.delayed(Duration.zero);
      },
          () => MockClient(
              (_) async => http.Response('{"detail":"No autorizado"}', 401)));
      expect(notifications, signedIn ? 1 : 0);
    });
  }
}
