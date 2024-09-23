import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:socket_io_client/socket_io_client.dart' as socket_io_client;
import 'package:socket_io/socket_io.dart';

void main(List<String> args) {
  // if (args.isEmpty) {
  //   print("No args passed");
  //   print("Usage:");
  //   print("Server: dart bin/client_server_example.dart s");
  //   print("Client: dart bin/client_server_example.dart c");
  //   return;
  // }
  // if (args.first == "s") _server();
  // if (args.first == "c") _client();
  auto();
}

Future<void> auto() async {
  try {
    await _server();
    Timer(Duration(seconds: 1), () => print('Soy el server'));
  } on SocketException {
    await _client();
    Timer(Duration(seconds: 1), () => print('Soy Cliente!!!'));
  }
}

StreamSubscription<String>? _streamSubscription;

Future<void> _server() async {
  final server = Server();

  server.on('connection', (client) {
    // cuando un cliente se conecta pasa por aquí

    final id = client.id.toString();
    print('Connected id: $id');
    client.broadcast.emit("msg", 'El id: $id se ha unido a la sala');

    client.on('stream', (data) {
      print('$id: $data');
    });

    client.on(
        'disconnect', // el canal disconnect es cuando se desconecta el cliente del servidor
        (_) {
      print('El cliente $id se ha desconectado del server');
      client.broadcast.emit("msg", 'El id: $id se a ido!');
    });

    Timer(Duration(seconds: 5), () {
      client.emit('msg', 'Hi!, from server');
    });
  });
  await server.listen(3000);

  _streamSubscription =
      readline().listen((String line) => server.emit('msg', line));
  // puedo hacer esto porque lo está utilizando un solo subscritor a la vez
  // pero en caso que el mismo stream lo necesiten dos susbcritores a la vez
  // allí creo que puede originar un error, y se necesiatn stremController
  // el tema es que la entrada del teclado me genera es un stream, entonces
  // en éste caso en específico sería así
  // porque
}

Future<void> _client() async {
  final client = socket_io_client.io('http://localhost:3000', <String, dynamic>{
    'transports': ['websocket'],
  });
  // cuando se ejecuta ésta istrucción él se queda esperando hasta conectarse

  client.onConnect((_) {
    print('Connected');

    _streamSubscription = readline().listen((String line) {
      client.emit('stream', line);
    });
  });

  client.onDisconnect((_) {
    print('Se ha desconectado del servidor');

    _streamSubscription?.cancel();
    client.dispose();
  });

  client.on('msg', (data) => _printFromServer(data));
}

Stream<String> readline() =>
    stdin.transform(latin1.decoder).transform(const LineSplitter());

// Stream<String> readline() =>
//     stdin.transform(utf8.decoder).transform(const LineSplitter());

void _printFromServer(String message) => print('server: $message');
