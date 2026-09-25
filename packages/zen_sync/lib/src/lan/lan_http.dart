/// §11.6.4. Turning hostile bytes into a request, and answers into a response.
///
/// Split out of `lan_server.dart` for §11.11's "files stay under roughly 400
/// lines", the same way D-M6-2 split `snapshot_json.dart` out of the codec:
/// what is left there reads as §11.6.4's three endpoints, and the plumbing that
/// makes each one refuse safely is here.
///
/// Not exported from `zen_sync.dart`. Nothing outside the server has a reason
/// to reach it.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:shelf/shelf.dart';

import 'lan_crypto.dart';

/// §11.6.4. Reads at most [max] bytes of [request], or `null` if it is larger.
///
/// "Bodies are capped **before they are read into memory**. Without a cap,
/// anyone on the network can make the desktop buffer a gigabyte before the
/// first decryption attempt."
///
/// `Content-Length` is checked first and the running total is checked as the
/// body streams, because a hostile client may understate the header or omit it
/// entirely — and a cap that trusts the sender's own declaration is not a cap.
Future<Uint8List?> readCapped(Request request, int max) async {
  final int? declared = request.contentLength;
  if (declared != null && declared > max) {
    return null;
  }
  final BytesBuilder builder = BytesBuilder(copy: false);
  await for (final List<int> chunk in request.read()) {
    if (builder.length + chunk.length > max) {
      return null;
    }
    builder.add(chunk);
  }
  return builder.takeBytes();
}

/// Decodes [body] as a JSON object, or returns `null`.
///
/// Null for anything that is not an object — an array, a bare string, invalid
/// UTF-8 — because each of those is something a caller can send and none is
/// something an endpoint here can use.
Map<String, Object?>? jsonObjectOrNull(Uint8List body) {
  try {
    final Object? parsed = jsonDecode(utf8.decode(body));
    return parsed is Map<String, Object?> ? parsed : null;
  } on FormatException {
    return null;
  }
}

/// A plain JSON response. `/hello` and `/pair` answer in the clear.
Response jsonResponse(int status, Map<String, Object?> body) => Response(
  status,
  body: jsonEncode(body),
  headers: <String, String>{'content-type': 'application/json'},
);

/// A refusal the caller could not have decrypted anyway, sent in the clear.
///
/// It says what went wrong and nothing about this device: §11.6.4 makes
/// `/hello` the only endpoint that reveals identity, so an unpaired caller
/// learns that it is unpaired and no more.
Response problemResponse(int status, String message) =>
    Response(status, body: message);

/// Seals [message] as a 200, under [cipher].
Future<Response> sealedResponse(LanCipher cipher, LanMessage message) =>
    _seal(cipher, 200, message.toBytes());

/// Seals a refusal the peer *is* entitled to read.
///
/// A refusal after a successful decryption goes back encrypted like everything
/// else on `/sync`, because the sender holds a key and because the copy is the
/// point — §11.6.4's clock-skew message is what stops a permanently failing
/// sync being a mystery.
Future<Response> sealedProblem(LanCipher cipher, int status, String problem) =>
    _seal(
      cipher,
      status,
      utf8.encode(jsonEncode(<String, Object?>{'problem': problem})),
    );

Future<Response> _seal(
  LanCipher cipher,
  int status,
  List<int> plaintext,
) async => Response(
  status,
  body: await cipher.seal(plaintext),
  headers: <String, String>{'content-type': 'application/octet-stream'},
);
