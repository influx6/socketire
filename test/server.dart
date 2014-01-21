library socketire.spec;

import 'dart:async';
import 'package:socketire/socketire-server.dart';

void main(){

	var socket = Socketire.createServer(HttpServer.bind('127.0.0.1',3000));
}