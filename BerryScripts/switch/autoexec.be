# Version 3

import json
import mqtt

# def OnWifiConnected()
#     log("QARL: wifi connected")
#     tasmota.cmd("Color FF0000") # Red
# end

# def OnWifiDisconnected()
#     log("QARL: wifi disconnected")
#     tasmota.cmd("Color FF9900") # Orange
# end

# def OnMqttConnected()
#     tasmota.cmd("Color 0000FF")
#     log("QARL: mqtt connected")
# end

# def OnMqttConnecting()
#     log("QARL: mqtt connecting...")
#     tasmota.cmd("Color FF00FF") # Magenta
#     tasmota.set_timer(500, def()
#         if mqtt.connected()
#             OnMqttConnected()
#         end
#     end)
# end

# def OnMqttDisconnected()
#     log("QARL: mqtt disconnected")
#     tasmota.cmd("Color FF00FF") # Magenta
# end

# tasmota.add_rule("Wifi#Connected", OnWifiConnected)
# tasmota.add_rule("Wifi#Disconnected", OnWifiDisconnected)
# tasmota.add_rule("Mqtt#Connected", OnMqttConnecting)
# tasmota.add_rule("Mqtt#Disconnected", OnMqttDisconnected)

var powerCount = size(tasmota.get_power())
var leds = Leds(1, 21)

def SetColor(color)
    leds.clear_to(color, 255)
    leds.show()
end

def SetPrimaryOnIndicator()
    SetColor(0x00FF00)
end

def SetSecondaryOnIndicator()
    SetColor(0xFF9900)
end

def SetOffIndicator()
    SetColor(0x0000FF)
end

def SetErrorIndicator()
    SetColor(0x000020)
end

def PowerOnLed()
    if powerCount == 2
        if tasmota.get_power()[0]
            SetPrimaryOnIndicator()
            tasmota.resp_cmnd_str("Power1 indicator ON")
            return
        end
    elif powerCount == 3
        if tasmota.get_power()[0]
            SetPrimaryOnIndicator()
            tasmota.resp_cmnd_str("Power1 indicator ON")
            return
        elif tasmota.get_power()[1]
            SetSecondaryOnIndicator()
            tasmota.resp_cmnd_str("Power2 indicator ON")
            return
        end
    end
    SetOffIndicator()
    tasmota.resp_cmnd_str("Indicator released")
end

def PowerOffLed()
    leds.clear()
    leds.show()
    tasmota.resp_cmnd_str("Indicator power off")
end

tasmota.add_cmd("LedOn", PowerOnLed)
tasmota.add_cmd("LedOff", PowerOffLed)

def SinglePower1Changed(value)
    if value == 1
        SetPrimaryOnIndicator()
    else
        SetOffIndicator()
    end
end

def DoublePower1Changed(value)
    if value == 1
        SetPrimaryOnIndicator()
    elif tasmota.get_power()[1]
        SetSecondaryOnIndicator()
    else
        SetOffIndicator()
    end
end

def DoublePower2Changed(value)
    if tasmota.get_power()[0]
        SetPrimaryOnIndicator()
    elif value == 1
        SetSecondaryOnIndicator()
    else
        SetOffIndicator()
    end
end

if powerCount == 2 # x1 relay + LED
    tasmota.add_rule("Power1#State", SinglePower1Changed)
    log("QARL: powers configured: 1")
elif powerCount == 3 # x2 relay + LED
    tasmota.add_rule("Power1#State", DoublePower1Changed)
    tasmota.add_rule("Power2#State", DoublePower2Changed)
    log("QARL: powers configured: 2")
else
    log("QARL: invalid powerCount configured: " + powerCount)
    SetErrorIndicator()
end

# tasmota.add_rule("Power1#State", SetOnIndicator)
# tasmota.add_rule("Power1#State", SetOffIndicator) 

# stat/p2/luz_pasillo/RESULT
# {"topic":"estancia/interruptor", "power":"POWER1"}
# var mem1 = tasmota.cmd("Mem1")["Mem1"]
# log("Mem1: " + mem1)

# if mem1 != ""
#     var config = json.load(mem1)
#     var power = config["power"]
    
#     def handle_message(topic, idx, payload)
#         var message = json.load(payload)
#         var value = message[power]
        
#         if value == 'ON'
#             SetOnIndicator()
#         elif value == 'OFF'
#             SetOffIndicator()
#         else
#             SetErrorIndicator()
#             log("Unknown state: " + value)
#         end
#     end

#     var full_topic = "stat/" + config["topic"] + "/RESULT"
#     log("QARL: subscribing to: " + full_topic)
#     log("QARL: with power: " + power)
    
#     mqtt.subscribe(full_topic, handle_message)

#     log("QARL: subscribed!")
# end
