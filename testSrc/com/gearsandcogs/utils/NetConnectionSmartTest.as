/**
 * Created by jhilton on 12/8/13.
 */
package com.gearsandcogs.utils
{
    import com.gearsandcogs.utils.NetConnectionSmart;

    import flash.events.NetStatusEvent;

    import org.flexunit.assertThat;

    import org.flexunit.asserts.assertEquals;
    import org.flexunit.asserts.assertNotNull;
    import org.flexunit.asserts.assertTrue;
    import org.flexunit.async.Async;

    public class NetConnectionSmartTest extends NetConnectionSmart
    {
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

        [Test(async, timeout="60000")]
        public function testConnectFail():void
        {
            Async.handleEvent(this, this, NetStatusEvent.NET_STATUS, handleNetStatus, 60000, this);
            function handleNetStatus(e:NetStatusEvent, test:NetConnectionSmartTest):void
            {
                assertEquals(e.info.code, NETCONNECTION_CONNECT_FAILED);
            }

            connect("1.com/no_app/");
        }

        [Test]
        public function testConnectSuccessNull():void
        {
            connect(null);
        }

        [Test]
        public function testCloseNoCrash():void
        {
            close();
        }

        [Test(expects="Error")]
        public function testIncompatibleSecureForceTunneling():void
        {
            secure = true;
            force_tunneling = true;
            connect("wowzaec2demo.streamlock.net/vod/");
        }

        [Test(expects="Error")]
        public function testIncompatibleSkipTunnelingForceTunneling():void
        {
            skip_tunneling = true;
            force_tunneling = true;
            connect("wowzaec2demo.streamlock.net/vod/");
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

            connect("1.com/no_app/");
        }

        [Test(expects="Error")]
        public function testInvalidPathConnect():void
        {
            connect("invalidpath.com");
        }

        [Test]
        public function testPortArray():void
        {
            assertNotNull(portArray);
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

        [Test]
        public function testProxyType():void
        {
            assertEquals(proxyType, "none");
        }
    }
}
