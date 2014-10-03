package com.gearsandcogs.utils
{
    import flash.events.Event;
    
    public class ParamEvent extends Event
    {
        public var param        :Object;
        public function ParamEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false,param:Object="")
        {
            super(type, bubbles, cancelable);
            this.param = param;
        }
    }
}
