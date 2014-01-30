library socketire;

import 'dart:html';
import 'package:hub/hub.dart';
import 'package:streamable/streamable.dart' as sm;

part 'helpers.dart';

class SocketirePostMessage{
	final MapDecorator options = Hub.createMapDecorator();
	sm.Streamable errMessages,outMessages,inMessages;
	dynamic root;
	// dynamic iframePortal;

	static create(m,[id]) => new SocketirePostMessage(m,id);

	SocketirePostMessage(this.root,[String iframeId,bool catchExceptions]){
		this.options.add('id',(iframeId == null ? 'networkFrame' : iframeId));
		this.options.add('catchExceptions',(catchExceptions == null ? false : catchExceptions));

		this.outMessages = sm.Streamable.create();
		this.inMessages = sm.Streamable.create();
		this.errMessages = sm.Streamable.create();
		// this.iframePortal = new IFrameElement();

		// if(iframeId != null) 
		// 	this.iframePortal.setAttribute('id',this.options.get('id'));
			
		this.init();
	}

	void send(payload,target,[List ports]){
		if(payload is Exception){
			var message = payload.toString();
			payload = { 'message': message };
		}

		this.outMessages.emit({'target': target, 'message': payload, 'ports': ports });
	}

	void bindOutStream(){
		this.outMessages.on((message){
			this.root.postMessage(message['data'],message['target'].href,message['ports']);
		});
	}

	void bindInStream(){
		this.root.addEventListener('message',(e){
			var message = e.data;

			print('messageInStream: $message : $e');
			this.inMessages.emit(message);
		});
	}

	void bindErrorStream(){
		this.root.addEventListener('error',(e){
			this.send(e.data,e);
		});
	}

	void init(){
		this.bindOutStream();
		this.bindInStream();
		if(!!this.options.get('catchExceptions')) this.bindErrorStream();
	}
}