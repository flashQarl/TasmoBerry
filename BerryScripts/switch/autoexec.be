tasmota.cmd("so20 0") # Forze LED power ON
tasmota.cmd("Color FFFFFF") # White
tasmota.cmd("so20 1")

def on_wifi_connected()
    log("QRL: wifi connected")
    tasmota.cmd("Color FF0000") # Red
end

def on_wifi_disconnected()
    log("QRL: wifi disconnected")
    tasmota.cmd("Color FF9900") # Orange
end

def set_blue_color()
    tasmota.cmd("Color 0000FF") # Blue
end

def on_mqtt_connecting()
    log("QRL: mqtt connecting...")
    tasmota.cmd("Color FF00FF") # Magenta
    tasmota.set_timer(500, set_blue_color) # Blue after 300 ms
end

def on_mqtt_disconnected()
    log("QRL: mqtt disconnected")
    tasmota.cmd("Color FF00FF") # Magenta
end

tasmota.add_rule("Wifi#Connected", on_wifi_connected)
tasmota.add_rule("Wifi#Disconnected", on_wifi_disconnected)
tasmota.add_rule("Mqtt#Connected", on_mqtt_connecting)
tasmota.add_rule("Mqtt#Disconnected", on_mqtt_disconnected)

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
            tasmota.cmd("Color 00FF00")
        elif value == 'OFF'
            tasmota.cmd("Color 0000FF")
        else
            tasmota.cmd("Color FF00FF")
            log("Unknown state: " + value)
        end
    end

    var full_topic = "stat/" + config["topic"] + "/RESULT"
    log("QRL: subscribing to: " + full_topic)
    log("QRL: with power: " + power)
    
    mqtt.subscribe(full_topic, handle_message)

    log("QRL: subscribed!")
end