import 'package:flutter_test/flutter_test.dart';
import 'package:tagihan_vendra/data/sync/sync_credential_store.dart';
import 'package:tagihan_vendra/data/sync/sync_http.dart';

void main() {
  test('lookup menghapus delimiter newline dan clear tidak menaruh secret di argumen', () async {
    final commands = <List<String>>[];
    final store = LinuxKeyringCredentialStore(
      command: (args, input) async {
        commands.add(args);
        expect(input, isNull);
        return SecretToolResult(
          0,
          args.first == 'lookup' ? 'secret\n' : '',
          '',
        );
      },
    );
    expect(await store.read('pairing', 'device'), 'secret');
    await store.delete('pairing', 'device');
    expect(commands.last.first, 'clear');
    expect(commands.last, isNot(contains('secret')));
  });

  test(
    'keyring adapter mengirim token melalui stdin dan memisahkan identitas',
    () async {
      const credential = 'fixture-secret';
      final store = LinuxKeyringCredentialStore(
        command: (arguments, input) async {
          expect(arguments, isNot(contains(credential)));
          expect(
            arguments,
            containsAll([
              'application',
              'tagihan-vendra',
              'service',
              'http://127.0.0.1:8787',
              'device_id',
              'device-a',
            ]),
          );
          if (arguments.first == 'store') {
            expect(input, credential);
            return const SecretToolResult(0, '', '');
          }
          expect(input, isNull);
          return const SecretToolResult(0, credential, '');
        },
      );
      await store.write('http://127.0.0.1:8787', 'device-a', credential);
      expect(await store.read('http://127.0.0.1:8787', 'device-a'), credential);
    },
  );

  test('credential belum ada berbeda dari kegagalan keyring', () async {
    final missing = LinuxKeyringCredentialStore(
      command: (_, _) async => const SecretToolResult(1, '', ''),
    );
    expect(await missing.read('local', 'id'), isNull);
    final failed = LinuxKeyringCredentialStore(
      command: (_, _) async =>
          const SecretToolResult(1, '', 'keyring locked: sensitive details'),
    );
    await expectLater(
      failed.read('local', 'id'),
      throwsA(
        isA<SyncAuthorizationException>().having(
          (error) => error.message,
          'redacted error',
          isNot(contains('sensitive details')),
        ),
      ),
    );
    await expectLater(
      failed.write('local', 'id', 'token'),
      throwsA(isA<SyncAuthorizationException>()),
    );
  });
}
