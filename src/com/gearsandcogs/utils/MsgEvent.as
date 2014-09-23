package com.gearsandcogs.utils
{
    import flash.events.Event;

    public class MsgEvent extends Event
    {
        public var msg:String;

        public function MsgEvent(typeIn:String, bubbles:Boolean = false, cancelable:Boolean = false, msg:String = "")
        {
            super(typeIn, bubbles, cancelable);
            this.msg = msg;
        }
    }
}