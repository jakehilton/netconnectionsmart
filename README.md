netconnectionsmart
==================

A replacement class for the standard NetConnection actionscript class. This easily enables multiple port attempts to resolve at the best functioning port.

Used to connect quickly through firewalls by trying a NetConnection via a shotgun connection approach or an incremental connection approach.

It does have a few properties like force_tunneling, encrypted, debug, connection_rate, and shotgun_connect that can be set before the connect call is made.

force_tunneling: used if you don't ever want to attempt rtmp connections
enctyped: used if you want to force the use of an encrypted connection (rtmp(t)e)
debug: if you want to see debug messages via your trace panel
connection_rate: only applicable if using a non-shotgun approach. Sets the rate that connections are tried. By default this is 200ms
shotgun_connect: a boolean to enable or disable the shotgun approach. By default it is enabled.

It also has an event,INTERMEDIATE_EVT, that fires each time the event_msg is updated to notify the user that the message is ready for reading (event_msg). This is merly for convenience and will be depricated in favor of a better event model including the message.
