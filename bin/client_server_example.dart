import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:socket_io_client/socket_io_client.dart' as socket_io_client;
import 'package:socket_io/socket_io.dart';

void main(List<String> args) {
  _initStreamSubscription();

  _initClient();
}

List<String> clientsId = []; // el único que no tiene id es el server
String? myId;

Server? _server;
socket_io_client.Socket? _client;

Future<void> _initServer() async {
  _server = Server();

  _server!.on('connection', (client) {
    // cuando un cliente se conecta pasa por aquí

    final id = client.id;
    clientsId.add(id);
    _server!.emit('updateIds', json.encode({"clientsId": clientsId}));

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
      clientsId.remove(id);
      _server!.emit('updateIds', json.encode({"clientsId": clientsId}));
    });

    Timer(Duration(seconds: 5), () {
      // client.emit('msg', 'Hi!, from server');
      // así también se puede envia un mensaje privado
      _server!.to(id).emit('msg', 'Hola desde el servidor');
    });
  });

  await _server!.listen(3000);
}

void _initStreamSubscription() {
  readlineServer().listen((String line) {
    if (_server != null) {
      _server!.emit('msg', line);
    }
    if (_client != null) {
      _client!.emit('stream', line);
    }
  });
}

void _setupClient() {
  _client = socket_io_client.io(
      'http://localhost:3000',
      socket_io_client.OptionBuilder()
          .setTransports(['websocket']) // for Flutter or Dart VM
          .disableAutoConnect() // disable auto-connection
          .build());
}

Future<void> _initClient() async {
  _setupClient();
  // cuando se ejecuta ésta istrucción él se queda esperando hasta conectarse

  _client!.connect();

  _client!.onConnect((_) {
    print('Connected');

    myId = _client!.id;
  });

  _client!.onDisconnect((_) async {
    print('Se ha desconectado del servidor');

    final firstClient = clientsId.first;
    if (firstClient == myId) {
      // print('Sí soy el primer clientId');
      clientsId.clear(); // para que registre nuevos clientesIds

      _client!.dispose();
      _client = null;

      _initServer();
    } else {
      // no hace nada aquí
    }
  });

  _client!.on('msg', (data) => _printFromServer(data));

  _client!.on('updateIds', (data) {
    // actualiza la lista de ids
    final result = json.decode(data)['clientsId'];
    clientsId = List<String>.from(result);
    print('Actualicé mi lista de ids');
    print(clientsId);
  });
  setupOtrosListeners();
}

void setupOtrosListeners() {
  _client!.on('connect_error', (data) {
    if (clientsId.isEmpty) {
      // entonces está iniciando la app
      _client!.dispose();
      _client = null;

      _initServer();
    } else {
      // todo
      // ya había clientes conectados antes de mí, no soy el primero
      // entonces tengo que ir rotando entre las diferentes direcciones ip
      // para volverme a reconectar
      // en éste caso de localhost no espero que pase por aqui, pero sí en el caso
      // que sean dispositivos diferntes conectados a una misma red lan
      print('connect_error: $data');
    }
  });
  _client!.on('connect_timeout', (data) => print('connect_timeout: $data'));
  _client!.on('error', (data) => print('error: $data'));
  _client!.on('reconnect_attempt', (data) {
    if (data == 1) {
      print('Primera reconexión');
    } else {
      print('Intento de reconexión nro: $data');
    }
    //print('reconnect_attempt: $data');
  });
  // _client!.on('reconnecting', (data) => print('reconnecting: $data'));
  _client!.on('reconnect_error', (data) => print('reconnect_error: $data'));
  _client!.on('reconnect_failed', (data) => print('reconnect_failed: $data'));
}

Stream<String> readlineServer() =>
    stdin.transform(latin1.decoder).transform(const LineSplitter());

// Stream<String> readline() =>
//     stdin.transform(utf8.decoder).transform(const LineSplitter());

void _printFromServer(String message) => print('server: $message');
