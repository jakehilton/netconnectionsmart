package com.gearsandcogs.utils
{
    public class NetConnectionType
    {
        public var connection:PortConnection;
        public var port:String;
        public var protocol:String;
        public var security:String;

        public function NetConnectionType(protocol:String, port:String, security:String = "")
        {
            this.port = port;
            this.protocol = protocol;
            this.security = security;
        }

        public function get full_protocol():String
        {
            return protocol + security;
        }
    }
}