import mqtt
import indicator

var startup_rules = module("startup_rules")

def on_wifi_connected()
    log("QARL: wifi connected")
    indicator.set_wifi_connected_color()
end

def on_wifi_disconnected()
    log("QARL: wifi disconnected")
    indicator.set_wifi_disconnected_color()
end

def on_mqtt_connecting()
    log("QARL: mqtt connecting...")
    indicator.set_mqtt_connecting_color()
    tasmota.set_timer(500, def()
        if mqtt.connected()
            indicator.sync_color_with_power()
        end
    end)
end

def on_mqtt_disconnected()
    log("QARL: mqtt disconnected")
    indicator.set_mqtt_disconnected_color()
end

startup_rules.create_startup_rules = def()
    tasmota.add_rule("Wifi#Connected", on_wifi_connected)
    tasmota.add_rule("Wifi#Disconnected", on_wifi_disconnected)
    tasmota.add_rule("Mqtt#Connected", on_mqtt_connecting)
    tasmota.add_rule("Mqtt#Disconnected", on_mqtt_disconnected)
end

return startup_rules