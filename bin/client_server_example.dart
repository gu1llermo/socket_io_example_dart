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

List<String> clientsId = []; // el único que no tiene id es el server
String? myId;

Future<void> auto() async {
  try {
    await _initServer();
    Timer(Duration(seconds: 1), () => print('Soy el server'));
  } on SocketException {
    await _initClient();
    Timer(Duration(seconds: 1), () => print('Soy Cliente!!!'));
  }
}

StreamSubscription<String>? _streamSubscription;
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

  _initStreamSubscription();

  // _streamSubscription =
  //     readlineServer().listen((String line) => _server!.emit('msg', line));
  // puedo hacer esto porque lo está utilizando un solo subscritor a la vez
  // pero en caso que el mismo stream lo necesiten dos susbcritores a la vez
  // allí creo que puede originar un error, y se necesiatn stremController
  // el tema es que la entrada del teclado me genera es un stream, entonces
  // en éste caso en específico sería así
  // porque
}

void _initStreamSubscription() {
  if (_server != null) {
    _streamSubscription =
        readlineServer().listen((String line) => _server!.emit('msg', line));
  }
  if (_client != null) {
    _streamSubscription =
        readlineServer().listen((String line) => _client!.emit('stream', line));
  }
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

    _initStreamSubscription();

    // _streamSubscription =
    //     readlineServer().listen((String line) => _client!.emit('stream', line));
  });

  _client!.onDisconnect((_) async {
    print('Se ha desconectado del servidor');
    await _streamSubscription?.cancel();
    _client!.dispose();

    final firstClient = clientsId.first;
    //print('firstClientId= $firstClient');
    if (firstClient == myId) {
      print('Sí soy el primer clientId');
      clientsId.clear();
      myId = null;
      _client!.dispose();

      print('Uno');
      await _streamSubscription?.cancel();
      print('Dos');

      Timer(Duration(seconds: 1), () {
        auto();
      });
    } else {
      //Timer(Duration(seconds: 3), () => auto);
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
}

Stream<String> readlineServer() =>
    stdin.transform(latin1.decoder).transform(const LineSplitter());
// Stream<String> readlineClient() =>
//     stdin.transform(latin1.decoder).transform(const LineSplitter());

// Stream<String> readline() =>
//     stdin.transform(utf8.decoder).transform(const LineSplitter());

void _printFromServer(String message) => print('server: $message');
