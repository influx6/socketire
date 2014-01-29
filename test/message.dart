library socketire.spec;

import 'dart:async';
import 'dart:html';
import 'package:socketire/postmessage.dart';

void main(){

	var socket = SocketirePostMessage.create(window);

	print(socket.root);
}