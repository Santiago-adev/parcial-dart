import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';  // Asegúrate de tener este paquete en pubspec.yaml

void main() async {
  final server = await HttpServer.bind('localhost', 8080);
  print('Servidor escuchando en ${server.address.address}:${server.port}');

  final clients = <String, WebSocket>{};  // Mapa para almacenar los clientes con su ID

  await for (HttpRequest request in server) {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      final socket = await WebSocketTransformer.upgrade(request);
      final clientId = Uuid().v4();  // Asignar un ID único al cliente
      clients[clientId] = socket;
      print('Cliente conectado: $clientId');

      handleClient(socket, clientId, clients);
    }
  }
}

void handleClient(WebSocket socket, String clientId, Map<String, WebSocket> clients) {
  socket.listen(
    (message) async {
      final data = jsonDecode(message);

      if (data['type'] == 'text') {
        // Enviar mensaje de texto a todos los clientes
        broadcast(clients, jsonEncode({
          'type': 'text',
          'message': data['message'],
          'from': clientId
        }));

      } else if (data['type'] == 'file') {
        final filename = data['filename'];
        final content = base64Decode(data['content']);

        print('Recibiendo archivo: $filename de cliente: $clientId');

        // Guardar archivo en el servidor
        final savedPath = await saveFile(filename, content);

        // Enviar el archivo a todos los clientes, excepto al remitente
        broadcastExcept(clients, socket, jsonEncode({
          'type': 'file',
          'filename': filename,
          'content': base64Encode(content),
          'from': clientId
        }));

        // Confirmación al cliente que envió el archivo
        socket.add(jsonEncode({
          'type': 'notification',
          'message': 'Archivo $filename recibido y guardado en $savedPath y enviado a otros clientes.'
        }));
      }
    },
    onDone: () {
      clients.remove(clientId);
      print('Cliente desconectado: $clientId');
    },
  );
}

Future<String> saveFile(String filename, List<int> content) async {
  final uploadDir = Directory('uploads');
  if (!await uploadDir.exists()) {
    await uploadDir.create(recursive: true);
  }

  final file = File(path.join(uploadDir.path, filename));
  await file.writeAsBytes(content);
  print('Archivo guardado en: ${file.path}');
  return file.path;
}

void broadcast(Map<String, WebSocket> clients, String message) {
  for (final client in clients.values) {
    client.add(message);
  }
}

void broadcastExcept(Map<String, WebSocket> clients, WebSocket exclude, String message) {
  for (final client in clients.values) {
    if (client != exclude) {
      client.add(message);
    }
  }
}
