library socketire;

import 'dart:io';
import 'dart:async';
import 'dart:html';

class Socketire{
	WebSocket ws;

	Socketire(String path,[Function n]){
		this.ws = new WebSocket(path);
	}

}