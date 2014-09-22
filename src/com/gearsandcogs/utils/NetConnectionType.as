package com.gearsandcogs.utils
{
    /**
     * Container object for managing a netconnection
     */
    public class NetConnectionType
    {
        public var connection:PortConnection;
        public var port:String;
        public var protocol:String;
        public var proxyType:String;
        public var security:String;

        /**
         *
         * @param protocol Raw value of rtmp, rtmpt, or rtmfp
         * @param port String representation of the port to be tried
         * @param security Pass in an "e" for encryped or an "s" for secure. RTMPE vs RTMPS
         * @param proxyType Proxy type to be applied to this netconnection
         */
        public function NetConnectionType(protocol:String, port:String, security:String = "", proxyType:String = "none")
        {
            this.port = port;
            this.protocol = protocol;
            this.proxyType = proxyType;
            this.security = security;
        }

        public function get full_protocol():String
        {
            return protocol + security;
        }
    }
}