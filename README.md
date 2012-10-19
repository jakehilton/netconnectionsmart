netconnectionsmart
==================

A replacement class for the standard NetConnection actionscript class. This easily enables multiple port attempts to resolve at the best functioning port. 

Used to connect quickly through firewalls by trying a NetConnection via a shotgun connection approach or an incremental connection approach.

Possible protocol attempts: rtmp,rtmpt,rtmpe,rtmpte,rtmps,rtmpts.

It does have a few properties listed below that can be set before the connect call is made.

auto_reconnect: a boolean to enable or dispable automatic reconnect attempts. By default this is set to false. \n
connection_rate: only applicable if using a non-shotgun approach. Sets the rate that connections are tried. By default this is 200ms \n
debug: if you want to see debug messages via your trace panel \n
enctyped: used if you want to force the use of an encrypted connection (rtmp(t)e) \n
force_tunneling: used if you don't ever want to attempt rtmp connections \n
reconnect_count_limit: specify the max amount of reconnect attempts are made. Default is 10. \n
shotgun_connect: a boolean to enable or disable the shotgun approach. By default it is enabled. \n

It also has an event,MSG_EVT, that fires to notify the user of an event in the class.
