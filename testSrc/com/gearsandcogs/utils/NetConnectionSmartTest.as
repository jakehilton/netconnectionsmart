/**
 * Created by jhilton on 12/8/13.
 */
package com.gearsandcogs.utils
{
    import flash.events.NetStatusEvent;

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
            testInitConnectionTypes();
            assertTrue(initPortConnection(0) is NetConnectionType);
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
        public function testProxyType():void
        {
            assertEquals(proxyType, "none");
        }
    }
}
