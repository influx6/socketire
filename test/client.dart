library socketire.spec;

import 'dart:async';
import 'dart:html';
import 'package:socketire/client.dart';

void main(){

	// var socket = SocketireClient.create('ws://127.0.0.1:3000');

	// socket.space('ws',(mesg){
	// 	print('receving: $mesg.data');
	// 	return true;
	// }).whenOpen.on((_){

	// 	print('ready to rumble: $_:${_.socket}');
	// 	_.send('hi');
	// 	print('sending');

	// });

	// socket.enableReconnect();

	// socket.stream('ws').on((req){
	// 	print(req);
	// 	//req.send('worth it');
	// 	print('running!');

	// 	if(req.message.data == '0') req.send('data');
	// 	if(req.message.data == '1') req.send('thanks');
	// });

	// socket.errors.on((e){
	// 	//e.error.listen((n){ print(n); });
	// 	print('socket errors');
	// });

	// socket.connect('ws');

	var socket = new WebSocket('ws://127.0.0.1:3000/ws');

	socket.onOpen.listen((e){
		print('opened!');
		socket.send('hi from dart');
	});

	socket.onError.listen((e){
		print('errored!');
	});

	socket.onMessage.listen((e){

		var data = e.data;
		
		print('recieved: $data');
		print('running!');
	});

}