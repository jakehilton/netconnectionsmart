netconnectionsmart
==================

A replacement class for the standard NetConnection actionscript class. This easily enables multiple port attempts to resolve at the best functioning port. 

Used to connect quickly through firewalls by trying a NetConnection via a shotgun connection approach or an incremental connection approach.

Possible protocol attempts: rtmp,rtmpt,rtmpe,rtmpte,rtmps.

It does have a few properties listed below that can be set before the connect call is made.

* append_guid: a boolean to enable a unique GUID be placed at the end of the parameters argument passed into the connect method. 
This can be used to identify which connection requests are coming from the same client and can be ignored if a connection is already being processed. By default it is false.
* recreate_guid: a boolean to enable the recreation of the GUID each time the main connect method is called. By default this is false.
* auto_reconnect: a boolean to enable or dispable automatic reconnect attempts. By default this is set to false. 
* connection_rate: only applicable if using a non-shotgun approach. Sets the rate that connections are tried. By default this is 200ms 
* debug: if you want to see debug messages via your trace panel.
* enctyped: used if you want to force the use of an encrypted connection (rtmp(t)e) 
* force_tunneling: used if you don't ever want to attempt rtmp connections 
* reconnect_count_limit: specify the max amount of reconnect attempts are made. Default is 10. 
* shotgun_connect: a boolean to enable or disable the shotgun approach. By default it is enabled. 
* portArray: an array containing ports in the order they should be tried. By default is it [443,80,1935]

It has an event,MSG_EVT, that fires to notify the user of an event in the class.

If you are experiencing issues with proxies you can try setting the proxyType="best" as this will attempt to use a different connect method if normal attempts fail.
