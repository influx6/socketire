library socketire.spec;

import 'package:socketire/socketire-client.dart';

void main(){

	var socket = Socketire.create('ws://127.0.0.1:3000');

	socket.space('ws',(mesg){
		print('receving: $mesg');
		return true;
	});

	socket.enableReconnect();

	socket.stream('ws').on((req){
		print(req);
		// req.send('worth it');
		print('running!');
	});

	socket.errors.on((e){
		print('socket errors: $e');
	});

	socket.spec('ws').whenOpen.on((_){

		print('ready to rumble: $_:${_.socket}');
		_.send('sucker');
		_.send('alex:booter');
		_.send('alex2');
		print('sending');

	});

	socket.connect('ws');
}