import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;

void main() async {
  final socket = await WebSocket.connect('ws://localhost:8080');
  print('Conectado al servidor');

  // Escuchar mensajes del servidor
  socket.listen(
    (message) {
      final data = jsonDecode(message);
      if (data['type'] == 'text') {
        print('Mensaje recibido de ${data['from']}: ${data['message']}');
      } else if (data['type'] == 'file') {
        print('Archivo recibido de ${data['from']}: ${data['filename']}');
        // Aquí podrías guardar el archivo en el sistema de archivos si lo deseas
      } else if (data['type'] == 'notification') {
        print('Notificación del servidor: ${data['message']}');
      }
    },
    onDone: () {
      print('Desconectado del servidor');
      exit(0);
    },
  );

  while (true) {
    print('\nOpciones:');
    print('1. Enviar mensaje de texto');
    print('2. Enviar archivo al servidor');
    print('3. Enviar archivo a otros clientes');
    print('4. Salir');
    stdout.write('Elige una opción: ');
    final input = stdin.readLineSync();

    if (input == null) continue;

    switch (input) {
      case '1':
        stdout.write('Escribe tu mensaje: ');
        final message = stdin.readLineSync();
        if (message != null && message.isNotEmpty) {
          sendTextMessage(socket, message);
        }
        break;
      case '2':
        stdout.write('Ingresa la ruta del archivo a enviar al servidor: ');
        final serverFilePath = stdin.readLineSync();
        if (serverFilePath != null && serverFilePath.isNotEmpty) {
          await sendFileToServer(socket, serverFilePath);
        }
        break;
      case '3':
        stdout.write('Ingresa la ruta del archivo a enviar a otros clientes: ');
        final clientFilePath = stdin.readLineSync();
        if (clientFilePath != null && clientFilePath.isNotEmpty) {
          await sendFileToClients(socket, clientFilePath);
        }
        break;
      case '4':
        print('Cerrando conexión...');
        await socket.close();
        exit(0);
      default:
        print('Entrada no reconocida. Por favor, elige una opción válida.');
    }
  }
}

void sendTextMessage(WebSocket socket, String message) {
  socket.add(jsonEncode({
    'type': 'text',
    'message': message
  }));
  print('Mensaje de texto enviado.');
}

Future<void> sendFileToServer(WebSocket socket, String filePath) async {
  final file = File(filePath);
  if (!file.existsSync()) {
    print('El archivo especificado no existe.');
    return;
  }

  print('Enviando archivo al servidor...');
  final fileData = await file.readAsBytes();

  socket.add(jsonEncode({
    'type': 'file',
    'filename': path.basename(filePath),
    'content': base64Encode(fileData),
  }));

  print('Archivo enviado al servidor. Esperando confirmación...');
}

Future<void> sendFileToClients(WebSocket socket, String filePath) async {
  final file = File(filePath);
  if (!file.existsSync()) {
    print('El archivo especificado no existe.');
    return;
  }

  print('Enviando archivo a otros clientes...');
  final fileData = await file.readAsBytes();

  socket.add(jsonEncode({
    'type': 'file',
    'filename': path.basename(filePath),
    'content': base64Encode(fileData),
  }));

  print('Archivo enviado a otros clientes. Esperando confirmación...');
}
