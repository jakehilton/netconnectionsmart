/**
 * Created by jhilton on 12/8/13.
 */
package com.gearsandcogs.utils
{
    import flash.events.NetStatusEvent;

    import org.flexunit.assertThat;
    import org.flexunit.asserts.assertEquals;
    import org.flexunit.asserts.assertNotNull;
    import org.flexunit.asserts.assertTrue;
    import org.flexunit.async.Async;

    public class NetConnectionSmartTest extends NetConnectionSmart
    {
        private var valid_server:String = "wowzaec2demo.streamlock.net/vod/";
        private var invalid_server:String = "1.com/no_app/";

        public function NetConnectionSmartTest()
        {
            super();
        }

        [Before]
        public function setUp():void
        {
        }

        [After]
        public function tearDown():void
        {

        }

        [Test]
        public function testCloseNoCrash():void
        {
            close();
        }

        [Test]
        public function testComplexPortArray():void
        {
            portArray = [
                new NetConnectionType(NetConnectionSmart.RTMP, "1935", "", NetConnectionSmart.PROXYTYPE_NONE),
                new NetConnectionType(NetConnectionSmart.RTMP, "443", "s", NetConnectionSmart.PROXYTYPE_BEST),
                new NetConnectionType(NetConnectionSmart.RTMFP, "443"),
                new NetConnectionType(NetConnectionSmart.RTMPT, "80", "", NetConnectionSmart.PROXYTYPE_HTTP),
                new NetConnectionType(NetConnectionSmart.RTMP, "80", "e", NetConnectionSmart.PROXYTYPE_CONNECT),
                new NetConnectionType(NetConnectionSmart.RTMP, "80", "", NetConnectionSmart.PROXYTYPE_CONNECTONLY),
                443,
                80,
                1935
            ];
            assertNotNull(netConnections);
            assertTrue(portArray[2] is NetConnectionType);
            assertTrue(portArray[2].protocol == NetConnectionSmart.RTMFP);
            assertThat(netConnections.length > 0);
        }

        [Test(async, timeout="60000")]
        public function testConnectFail():void
        {
            Async.handleEvent(this, this, NetStatusEvent.NET_STATUS, handleNetStatus, 60000, this);
            function handleNetStatus(e:NetStatusEvent, test:NetConnectionSmartTest):void
            {
                assertEquals(e.info.code, NETCONNECTION_CONNECT_FAILED);
            }

            connect(invalid_server);
        }

        [Test]
        public function testConnectSuccessNull():void
        {
            connect(null);
        }

        [Test(expects="Error")]
        public function testIncompatibleSecureForceTunneling():void
        {
            secure = true;
            force_tunneling = true;
            connect(valid_server);
        }

        [Test(expects="Error")]
        public function testIncompatibleSkipTunnelingForceTunneling():void
        {
            skip_tunneling = true;
            force_tunneling = true;
            connect(valid_server);
        }

        [Test]
        public function testInitConnectionTypes():void
        {
            initConnectionTypes();
            assertNotNull(_ncTypes);
            assertTrue(_ncTypes.length > 0);
        }

        [Test]
        public function testInitPortConnection():void
        {
            initConnectionTypes();
            assertTrue(initPortConnection(0) is NetConnectionType);
        }

        [Test(expects="Error")]
        public function testInvalidPathConnect():void
        {
            connect("invalidpath.com");
        }

        [Test(async, timeout="60000")]
        public function testNetConnectionInfoValid():void
        {
            Async.handleEvent(this, this, NetStatusEvent.NET_STATUS, handleNetStatus, 60000, this);
            function handleNetStatus(e:NetStatusEvent, test:NetConnectionSmartTest):void
            {
                var values:Vector.<Object> = netConnectionsInfo;
                var connectionToTest:Object = values[0];
                assertTrue(connectionToTest.hasOwnProperty("port"));
                assertTrue(connectionToTest.hasOwnProperty("protocol"));
                assertTrue(connectionToTest.hasOwnProperty("proxyType"));
                assertTrue(connectionToTest.hasOwnProperty("connection"));
                assertTrue(connectionToTest.connection.hasOwnProperty("connection_timeout"));
                assertTrue(connectionToTest.connection.hasOwnProperty("id"));
                assertTrue(connectionToTest.connection.hasOwnProperty("label"));
                assertTrue(connectionToTest.connection.hasOwnProperty("proxyType"));
                assertTrue(connectionToTest.connection.hasOwnProperty("response_time"));
                assertTrue(connectionToTest.connection.hasOwnProperty("was_connected"));
                assertTrue(connectionToTest.connection.hasOwnProperty("status"));
            }

            connect(invalid_server);
        }

        [Test(async, timeout="60000")]
        public function testNetConnectionResponseTime():void
        {
            var connect_init_time:Number = new Date().getTime();

            Async.handleEvent(this, this, NetStatusEvent.NET_STATUS, handleNetStatus, 60000, this);
            function handleNetStatus(e:NetStatusEvent, test:NetConnectionSmartTest):void
            {
                assertEquals(e.info.code, NETCONNECTION_CONNECT_SUCCESS);

                //round the numbers slightly so if we're 1ms off we don't blow up
                var calculated_response:uint = Math.floor((new Date().getTime() - connect_init_time) / 10) * 10;
                var internal_response:uint = Math.floor(response_time / 10) * 10;
                assertEquals(calculated_response, internal_response);
            }

            connect(valid_server);
        }

        [Test]
        public function testPortArray():void
        {
            assertNotNull(portArray);
        }

        [Test]
        public function testProxyType():void
        {
            assertEquals(proxyType, "none");
        }
    }
}
