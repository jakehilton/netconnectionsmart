netconnectionsmart
==================

A replacement class for the standard NetConnection actionscript class. This easily enables multiple port attempts to resolve at the best functioning port and protocol. 

Used to connect quickly through firewalls by trying a NetConnection via a shotgun connection approach or an incremental connection approach.

Possible protocol attempts: rtmp,rtmpt,rtmpe,rtmpte,rtmps, and rtmfp.

It does have a few properties listed below that can be set before the connect call is made.

* append_guid: a boolean to enable a unique GUID be placed at the end of the parameters argument passed into the connect method. 
This can be used to identify which connection requests are coming from the same client and can be ignored if a connection is already being processed. By default it is false.
* recreate_guid: a boolean to enable the recreation of the GUID each time the main connect method is called. By default this is false.
* auto_reconnect: a boolean to enable or disable automatic reconnect attempts. By default this is set to false. 
* connection_rate: only applicable if using a non-shotgun approach. Sets the rate that connections are tried. By default this is 200ms 
* connection_timeout: the number of seconds to wait for a connection to succeed before it's deemmed faulty.
* debug: if you want to see debug messages via your trace panel.
* enable_rtmfp: puts rtmfp into the list of attempted protocols. By default this is set to false because it can cause slow timeouts when used with sequential connect
* encrypted: used if you want to force the use of an encrypted connection (rtmp(t)e)
* secure: used if you want to force the use of an SSL connection (rtmps). Not compatible with force_tunneling.
* force_tunneling: used if you don't ever want to attempt rtmp connections 
* skip_tunneling: used if you don't ever want to attempt rtmpt connections
* reconnect_count_limit: specify the max amount of reconnect attempts are made. If set to 0 reconnect attempts will occur indefinitely. Default is 10.
* reconnect_max_time_wait: specify the max amount of time to pass between reconnect attempts. The reconnect logic employs an exponential back-off algorithm so it delays each successive attempt exponentially with a cap at the max set here plus a random seed. Default is 10.
* sequential_connect: a boolean to enable or disable the sequential connect approach. By default it is disabled. This will try a connection one at a time and wait for a failure prior to trying the next type in the sequence. 
* shotgun_connect: a boolean to enable or disable the shotgun approach. By default it is enabled. 
* portArray: an array containing port numbers or NetConnectionTypes in the order they should be tried. By default is it [443,80,1935]. Added in 1.8.0 is the ability to pass in NetConnectionTypes so as to specify an exact protocol/port/proxy connect order.
* port_test: a boolean specifying whether to only run a port test for all available protocols over the specified ports in the portArray. It will fire events for updates and when it completes.

It has an event,PARAM_EVT, that fires to notify the user of an event in the class. It has a param value which is an object which should be case to a string to read.

If you are experiencing issues with proxies you can try setting the proxyType="best" as this will attempt to use a different connect method if normal attempts fail.

If you are using this in a mobile IOS Air project I would highly suggest enabling sequential_connect.

USAGE:
It's a simple use case really.. just use it as you would the built in NetConnection class. Just specify rtmp as the protocol and let
the class handle the rest whether to use rtmpt or rtmp. In the case of encrypted still only pass in rtmp and it will resolve to rtmpe or rtmpte.
The only caveat is that for netstreams you'd need to pass in a reference to the connection and not the main class.

It also supports rtmfp. Using this library will support auto-reconnect if needed as well as
some other hooks this lib buys. It would also be possible to switch between protocols using the same netconnectionsmart connection class.

For example:

```ActionScript
var client_obj:Object = new Object();
client_obj.serverMethod = function(e:Object):void{
    trace("server can call this");
}

var ncs:NetConnectionSmart = new NetConnectionSmart();
ncs.client = client_obj;
ncs.encrypted = true; //if this isn't specified it will default to rtmp/rtmpt.. if true it will try rtmpe/rtmpte

ncs.addEventListener(NetStatusEvent.NET_STATUS,function(e:NetStatusEvent):void{
    trace("connection status: "+e.info.code);
    trace(ncs.uri);
    trace(ncs.protocol);
    
    switch (e.info.code){
        case NetConnectionSmart.NETCONNECTION_CONNECT_SUCCESS:
            var ns:NetStream = new NetStream(ncs.connection);
            //do other netstream actions
            break;
    }
});

ncs.connect("rtmp://myserver.com/application");

```

 Port array examples

 ```ActionScript
 ncs.portArray = [443,80,1935];

 //Alternate usage showing a mix of numbers with NetConnectionTypes. The order will be honored in the connection attempts
 ncs.portArray = [
     new NetConnectionType(NetConnectionSmart.RTMP, "1935", "", NetConnectionSmart.PROXYTYPE_NONE),
     new NetConnectionType(NetConnectionSmart.RTMP, "443", "s", NetConnectionSmart.PROXYTYPE_BEST),
     new NetConnectionType(NetConnectionSmart.RTMFP, "443"),
     443,
     new NetConnectionType(NetConnectionSmart.RTMPT, "80", "", NetConnectionSmart.PROXYTYPE_HTTP),
     new NetConnectionType(NetConnectionSmart.RTMP, "80", "e", NetConnectionSmart.PROXYTYPE_CONNECT),
     new NetConnectionType(NetConnectionSmart.RTMP, "80", "", NetConnectionSmart.PROXYTYPE_CONNECTONLY),
     80,
     1935
 ];
 ```