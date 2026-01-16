# Version 2

if tasmota.cmd("so20")["SetOption20"] == "ON"
    tasmota.cmd("so20 0") # Forze LED power ON
    tasmota.cmd("Color FFFFFF") # White
    tasmota.cmd("so20 1")
end

def OnWifiConnected()
    log("QRL: wifi connected")
    tasmota.cmd("Color FF0000") # Red
end

def OnWifiDisconnected()
    log("QRL: wifi disconnected")
    tasmota.cmd("Color FF9900") # Orange
end

def SetBlueColor()
    tasmota.cmd("Color 0000FF") # Blue
end

def OnMqttConnecting()
    log("QRL: mqtt connecting...")
    tasmota.cmd("Color FF00FF") # Magenta
    tasmota.set_timer(500, SetBlueColor) # Blue after 300 ms
end

def OnMqttDisconnected()
    log("QRL: mqtt disconnected")
    tasmota.cmd("Color FF00FF") # Magenta
end

tasmota.add_rule("Wifi#Connected", OnWifiConnected)
tasmota.add_rule("Wifi#Disconnected", OnWifiDisconnected)
tasmota.add_rule("Mqtt#Connected", OnMqttConnecting)
tasmota.add_rule("Mqtt#Disconnected", OnMqttDisconnected)

def SetOnIndicator()
    tasmota.cmd("Color 00FF00")
end

def SetOffIndicator()
    tasmota.cmd("Color 0000FF")
end

def SetErrorIndicator()
    tasmota.cmd("Color 000070")
end

tasmota.add_rule("Power1#State=1", SetOnIndicator)
tasmota.add_rule("Power1#State=0", SetOffIndicator) 

# stat/p2/luz_pasillo/RESULT
# {"topic":"estancia/interruptor", "power":"POWER1"}
var mem1 = tasmota.cmd("Mem1")["Mem1"]
log("Mem1: " + mem1)

if mem1 != ""
    import json
    import mqtt
    
    var config = json.load(mem1)
    var power = config["power"]
    
    def handle_message(topic, idx, payload)
        var message = json.load(payload)
        var value = message[power]
        
        if value == 'ON'
            SetOnIndicator()
        elif value == 'OFF'
            SetOffIndicator()
        else
            SetErrorIndicator()
            log("Unknown state: " + value)
        end
    end

    var full_topic = "stat/" + config["topic"] + "/RESULT"
    log("QRL: subscribing to: " + full_topic)
    log("QRL: with power: " + power)
    
    mqtt.subscribe(full_topic, handle_message)

    log("QRL: subscribed!")
end