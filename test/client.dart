library socketire.spec;

import 'dart:async';
import 'dart:html';
import 'package:socketire/socketire-client.dart';

void main(){

	var socket = Socketire.create('ws://127.0.0.1:3000');

	socket.space('ws',(mesg){
		print('receving: $mesg');
		return true;
	}).whenOpen.on((_){

		print('ready to rumble: $_:${_.socket}');
		_.send('sucker');
		_.send('alex:booter');
		_.send('alex2');
		print('sending');

	});

	socket.enableReconnect();

	socket.stream('ws').on((req){
		print(req);
		//req.send('worth it');
		print('running!');
	});

	socket.errors.on((e){
		//e.error.listen((n){ print(n); });
		print('socket errors');
	});

	socket.connect('ws');


}