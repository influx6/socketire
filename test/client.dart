library socketire.spec;

import 'dart:async';
import 'dart:html';
import 'package:socketire/client.dart';

void main(){

	var socket = SocketireClient.create();

	var ws = socket.space('ws','ws://127.0.0.1:3001/ws');

	ws.route('1');
	ws.route('2');
	ws.route('3');

	ws.whenOpen.on((_){

		print('ready to rumble: $_:${_.socket}');
		_.send('hi');
		print('sending');

	});

	ws.stream.on((n){

		print('recieving message: $n');
		if(n == '1') return ws.sendTo('1',n);
		if(n == '2') return ws.sendTo('2',n);
		if(n == '3') return ws.sendTo('3',n);

		return ws.sendTo('*',n);
	});

	socket.errors.on((e){
		print('socket errors');
	});

	socket.enableReconnect();

	socket.connect('ws');

	// var socket = new WebSocket('ws://127.0.0.1:3000/ws');

	// socket.onOpen.listen((e){
	// 	print('opened!');
	// 	socket.send('hi from dart');
	// });

	// socket.onError.listen((e){
	// 	print('errored!');
	// });

	// socket.onMessage.listen((e){

	// 	var data = e.data;
		
	// 	print('recieved: $data');
	// 	print('running!');
	// });

}