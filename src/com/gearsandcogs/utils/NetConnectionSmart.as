/*
<AUTHOR: Jake Hilton, jake@gearsandcogs.com
Copyright (C) 2010, Gears and Cogs.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

VERSION: 0.9.0
DATE: 6/22/2012
ACTIONSCRIPT VERSION: 3.0
DESCRIPTION:
Used to connect quickly through firewalls by trying a NetConnection via a shotgun connection approach or an incremental connection approach. 
It does have a few properties like force_tunneling, encrypted, debug, connection_rate, and shotgun_connect that can be set before the connect call is made.

force_tunneling: used if you don't ever want to attempt rtmp connections
enctyped: used if you want to force the use of an encrypted connection (rtmp(t)e)
debug: if you want to see debug messages via your trace panel
connection_rate: only applicable if using a non-shotgun approach. Sets the rate that connections are tried. By default this is 200ms
shotgun_connect: a boolean to enable or disable the shotgun approach. By default it is enabled.

It also has an event,MSG_EVT, that fires each time an event is updated.

USAGE:
It's a simple use case really.. just use it as you would the built in NetConnection class. Just specify rtmp as the protocol and let
the class handle the rest whether to use rtmpt or rtmp. In the case of encrypted still only pass in rtmp and it will resolve to rtmpe or rtmpte.
The only caveat is that for netstreams you'd need to pass in a reference to the connection and not the main class.

For example:

var client_obj:Object = new Object();
client_obj.serverMethod = function(e:Object):void
{
trace("server can call this");
}

var ncs:NetConnectionSmart = new NetConnectionSmart();
ncs.client = client_obj;
ncs.encrypted = true; //if this isn't specified it will default to rtmp/rtmpt.. if true it will try rtmpe/rtmpte
ncs.connect("rtmp://myserver.com/application");

ncs.addEventListener(NetStatusEvent.NET_STATUS,function(e:NetStatusEvent):void
{
trace("connection status: "+e.info.code);
trace(ncs.uri);
trace(ncs.protocol);
});

var ns:NetStream = new NetStream(ncs.connection);

*/

package com.gearsandcogs.utils
{
	import flash.events.AsyncErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.NetStatusEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.net.NetConnection;
	import flash.net.ObjectEncoding;
	import flash.net.Responder;
	import flash.utils.Timer;
	import flash.utils.setTimeout;
	
	public class NetConnectionSmart extends EventDispatcher
	{
		public static const MSG_EVT				:String = "NetConnectionSmartMsgEvent";
		public static const VERSION				:String = "NetConnectionSmart v 0.9.0";
		
		private static const RTMP				:String = "rtmp";
		private static const RTMPT				:String = "rtmpt";
		
		public var force_tunneling				:Boolean;
		public var encrypted					:Boolean;
		public var secure						:Boolean;
		public var default_port_only			:Boolean;
		public var debug						:Boolean;
		public var shotgun_connect				:Boolean = true;
		
		public var connection_rate				:uint = 200;

		private var connect_params				:Array;
		private var _nc_types					:Array;
		
		private var _is_connecting				:Boolean;
		
		private var _nc_client					:Object;
		
		private var _nc							:PortConnection;
		
		private var app_string					:String;
		private var connect_string				:String;
		private var encrypted_secure_string		:String;
		private var server_string				:String;
		
		private var connect_timer				:Timer;
		
		private var object_encoding				:uint = ObjectEncoding.AMF3;
		
		public function NetConnectionSmart()
		{
			if(debug)
				log(VERSION);
			
			_nc_client = new Object();
			initConnectionTypes();
		}
		
		/**
		 * 
		 *public method callable like the netconnection ones 
		 * 
		 */		
		
		public function get connection():NetConnection
		{
			return _nc;
		}
		
		public function call(command:String,responder:Responder=null,...parameters):void
		{
			_nc.call.apply(null,[command,responder].concat(parameters));
		}
		
		public function connect(command:String, ...parameters):void
		{
			if(_is_connecting)
				return;
			
			_is_connecting = true;
			
			connect_string = command.indexOf("://")>-1?command.substr(command.indexOf("://")+3):command;
			connect_params = parameters;
			server_string = connect_string.substr(0,connect_string.indexOf("/"));
			app_string = connect_string.substr(connect_string.indexOf("/"));
			encrypted_secure_string = encrypted?"e":secure?"s":"";
			
			initPortConnections();
			
			if(shotgun_connect)
			{
				if(!force_tunneling){
					for(var i:String in _nc_types){
						if(_nc_types[i].protocol == RTMP)
						{
							initializeConnection(_nc_types[i].connection,_nc_types[i].protocol,_nc_types[i].port,connect_params);
						}
					}
				}
				
				//delay rtmpt attempts by 1 second unless tunneling 
				setTimeout(function():void
				{
					if(!connected){
						for(var i:String in _nc_types)
						{
							if(_nc_types[i].protocol == RTMPT)
							{
								initializeConnection(_nc_types[i].connection,_nc_types[i].protocol,_nc_types[i].port,connect_params);
							}
						}
						
					}
				},force_tunneling?10:1000);
			} else {
				initializeTimers();
			}
		}
		
		public function get connected():Boolean
		{
			try{
				return _nc.connected;
			} catch(e:Error){}
			
			return false;
		}
		
		public function set client(obj:Object):void
		{
			_nc_client = obj;
		}
		
		public function close():void
		{
			if(_nc)
				_nc.close();
		}
		
		public function get objectEncoding():uint
		{
			return _nc?_nc.objectEncoding:object_encoding;
		}
		
		public function set objectEncoding(encoding:uint):void
		{
			object_encoding = encoding;
			if(_nc)
				_nc.objectEncoding = encoding;
		}
		
		public function get protocol():String
		{
			return _nc.uri.substr(0,_nc.uri.indexOf("://"));
		}
		
		public function get proxyType():String
		{
			return _nc.proxyType;
		}
		
		public function get connectedProxyType():String
		{
			return _nc.connectedProxyType;
		}
		
		public function get uri():String
		{
			return _nc.uri;
		}
		
		public function get usingTLS():Boolean
		{
			return _nc.usingTLS;
		}
		
		/**
		 * 
		 * private methods used to push things up the stack for listeners
		 * and to manage net connections
		 * 
		 */	
		
		private function acceptNc(portConnection:PortConnection):void
		{
			_nc = portConnection;
			
			_nc.removeEventListener(PortConnection.STATUS_UPDATE,checkNetStatus);
			_nc.removeHandlers();
			
			_nc.addEventListener(AsyncErrorEvent.ASYNC_ERROR,handleAsyncError);
			_nc.addEventListener(IOErrorEvent.IO_ERROR,handleIoError);
			_nc.addEventListener(NetStatusEvent.NET_STATUS,handleNetStatus);
			_nc.addEventListener(SecurityErrorEvent.SECURITY_ERROR,handleSecurityError);
			
			_nc.client = _nc_client;
			
			try {
				connect_timer.stop();
			}catch(e:Error){}
			
			closeExtraNc();
		}
		
		private function closeExtraNc():void
		{
			for each(var n:Object in _nc_types){
				var portConnection:PortConnection = n.connection as PortConnection;
				if(portConnection && portConnection != _nc)
					closeDownNc(portConnection);
			}
		}
		
		private function closeDownNc(pc:PortConnection):void
		{
			if(debug)
				trace("Closing down NetConnection: "+pc.label);
			
			pc.removeEventListener(PortConnection.STATUS_UPDATE,checkNetStatus);
			pc.addEventListener(NetStatusEvent.NET_STATUS,nullHandleNetStatus);
			pc.close();
			
			//cleanup listener
			pc.removeHandlers();
		}
		
		/**
		 * 
		 * @param netconnection
		 * @param protocol
		 * @param port
		 * @param parameters
		 * 
		 */		
		
		private function initializeConnection(connection:NetConnection,protocol:String,port:String, parameters:Array):void
		{
			if(default_port_only && port != "default")
				return;
			
			var portpass:String = port!="default"?":"+port:"";
			
			if(debug) 
				log("connecting to: "+protocol+encrypted_secure_string+"://"+server_string+portpass+app_string);
			
			connection.connect.apply(null,[protocol+encrypted_secure_string+"://"+
				server_string+portpass+app_string].concat(parameters));
		}
		
		private function initConnectionTypes():void
		{
			_nc_types = new Array();
			_nc_types.push({protocol:RTMP,port:"443"});
			_nc_types.push({protocol:RTMP,port:"1935"});
			_nc_types.push({protocol:RTMP,port:"80"});
//			_nc_types.push({protocol:RTMP,port:"default"});
			
			_nc_types.push({protocol:RTMPT,port:"443"});
			_nc_types.push({protocol:RTMPT,port:"80"});
			_nc_types.push({protocol:RTMPT,port:"1935"});
//			_nc_types.push({protocol:RTMPT,port:"default"});
		}
		
		private function initPortConnections():void
		{
			var encrypted_secure_identifier:String = encrypted?"Encrypted/Secure ":" "; 
			for(var i:String in _nc_types)
			{
				var port_label:String = encrypted_secure_identifier+_nc_types[i].protocol+" "+_nc_types[i].port;
				var curr_pc:PortConnection = new PortConnection(parseInt(i),port_label,debug);
				curr_pc.objectEncoding = object_encoding;
				
				if(force_tunneling && _nc_types[i].protocol == RTMP)
					curr_pc.status = new NetStatusEvent("skipped");
				
				curr_pc.client = _nc_client;
				curr_pc.addEventListener(PortConnection.STATUS_UPDATE,checkNetStatus);
				_nc_types[i].connection = curr_pc;
			}
		}
		
		private function initializeTimers():void
		{
			if(debug)
				log("Shotgun disabled. Connecting sequentially at a rate of: "+connection_rate);
			
			connect_timer = new Timer(connection_rate);
			connect_timer.addEventListener(TimerEvent.TIMER,function(e:TimerEvent):void
			{
				var curr_count:uint = force_tunneling?connect_timer.currentCount+4:connect_timer.currentCount;
				
				var curr_connect_obj:Object = _nc_types[curr_count-1];
				if(!force_tunneling || (force_tunneling && curr_connect_obj.protocol == RTMPT) )
					initializeConnection(curr_connect_obj.connection,curr_connect_obj.protocol,curr_connect_obj.port,connect_params);
				
				if(curr_count == _nc_types.length)
				{
					//all connection attempts have been tried
					connect_timer.stop();
				}
			});
			
			connect_timer.start();
		}
		
		private function checkNetStatus(e:Event):void
		{
			var target_connection:PortConnection = e.target as PortConnection;
			
			if(debug)
				log(target_connection.label+": "+target_connection.status.info.code);
			
			var status_count:uint;
			var rejected_connection:PortConnection;
			
			for each(var i:Object in _nc_types)
			{
				var curr_connection:PortConnection = i.connection as PortConnection;
				
				if(curr_connection.status)
					status_count++;
				
				if(!connected && curr_connection.connected)
				{
					acceptNc(curr_connection);
					dispatchEvent(curr_connection.status);
					_is_connecting = false;
					return;
				} else if(curr_connection.rejected)
					rejected_connection = curr_connection;
			}
			
			//if no success at all return the first rejected message or
			//return the status of the last connection in the array
			if(!connected && status_count == _nc_types.length)
			{
				if(!rejected_connection)
					dispatchEvent(_nc_types[_nc_types.length-1].connection.status);
				else
					dispatchEvent(rejected_connection.status);
				
				_is_connecting = false;
			}
		}
		
		private function handleAsyncError(e:AsyncErrorEvent):void
		{
			if(debug) 
				log(e.error.toString());
			dispatchEvent(e);
		}
		
		private function handleIoError(e:IOErrorEvent):void
		{
			if(debug) 
				log(e.text);
			dispatchEvent(e);
		}
		
		private function nullHandleNetStatus(e:NetStatusEvent):void
		{
			if(debug) 
				log("null handler: "+e.info.code);
		}
		
		private function handleNetStatus(e:NetStatusEvent):void
		{
			if(debug) 
				log(e.info.code);
			dispatchEvent(e);
		}
		
		private function handleSecurityError(e:SecurityErrorEvent):void
		{
			if(debug) 
				log(e.text);
			dispatchEvent(e);
		}
		
		private function log(msg:String):void
		{
			if(debug) 
				trace("NetConnectionSmart: "+msg);
			
			dispatchEvent(new MsgEvent(MSG_EVT,false,false,msg));
		}
		
	}
}

import flash.events.AsyncErrorEvent;
import flash.events.Event;
import flash.events.NetStatusEvent;
import flash.net.NetConnection;

//custom port connection class to wrap netconnection
class PortConnection extends NetConnection
{
	public static const STATUS_UPDATE	:String = "status_update";
	
	public var debug					:Boolean;
	public var id						:int;
	public var status					:NetStatusEvent;
	public var label					:String;
	
	public function PortConnection(id:int,label:String,debug:Boolean=false)
	{
		super();
		this.debug = debug;
		this.id = id;
		this.label = label;
		addHandlers();
	}
	
	public function addHandlers():void
	{
		addEventListener(AsyncErrorEvent.ASYNC_ERROR,handleAsyncError);
		addEventListener(NetStatusEvent.NET_STATUS,handleNetStatus);
	}
	
	private function handleNetStatus(e:NetStatusEvent):void
	{
		//if rejected connection came in we want to preserve that message
		if(!status || (status && status.info.code != "NetConnection.Connect.Rejected")){
			if(debug) 
				trace("PortConnection: "+e.info.code);
			status = e;
			dispatchEvent(new Event(STATUS_UPDATE));
		}
	}
	
	private function handleAsyncError(e:AsyncErrorEvent):void
	{
		if(debug)
			trace("PortConnection: "+e.toString());
	}
	
	public function removeHandlers():void
	{
		removeEventListener(AsyncErrorEvent.ASYNC_ERROR,handleAsyncError);
		removeEventListener(NetStatusEvent.NET_STATUS,handleNetStatus);
	}
	
	public function onBWDone():void
	{
		//don't do anything
	}
	
	public function getProtocol():String
	{
		return uri.substr(0,uri.indexOf("://"));
	}
	
	public function get rejected():Boolean
	{
		try{
			return status.info.code == "NetConnection.Connect.Rejected";
		}catch(e:Error){}
		
		return false;
	}
}