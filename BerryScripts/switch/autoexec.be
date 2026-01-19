log("------------------------------------------------------------")
log("QARL: version 4")
log("------------------------------------------------------------")

import json
import mqtt
import string

def set_color(color)
    tasmota.cmd("Color " + color)
end

def set_primary_indicator()
    set_color("00FF00")
end

def set_secondary_indicator()
    set_color("FF9900")
end

def set_released_indicator()
    set_color("0000FF")
end

def set_error_indicator()
    set_color("000020")
end

class subscription
    var topic
    var power
    var primary
    
    def init(topic, power, primary)
        self.topic = topic
        self.power = power
        self.primary = primary
    end
    
    def to_map()
        return {"topic": self.topic, "power": self.power, "primary": self.primary}
    end
    
    static def from(data)
        return subscription(data["topic"], data["power"], data["primary"])
    end
end

class subscriptions
    var list
    
    def init()
        self.list = []
        
        var mem1 = tasmota.cmd("Mem1")["Mem1"]
        if mem1 && mem1 != ""
            var data = json.load(mem1)
            if data.find("subscriptions")
                for item : data["subscriptions"]
                    self.list.push(subscription.from(item))
                end
            end
        end
    end
    
    def size()
        return size(self.list)
    end
    
    def save()
        var data = []
        for i:0..self.size()-1
            data.push(self.list[i].to_map())
        end
        var json_data = json.dump({'subscriptions': data})
        tasmota.cmd("Mem1 " + json_data)
    end
    
    def add(topic, power, primary)
        self.list.push(subscription("stat/" + topic + "/RESULT", int(power), !(primary == "false")))
        self.save()
    end
    
    def delete(index)
        self.list.remove(index - 1)
        self.save()
    end
    
    def print()
        log("---- Subscriptions (" + str(self.size()) + ") ----")
        for i:0..self.size()-1
            var sub = self.list[i]
            log(str(i+1) + ". " + sub.topic + " POWER" + str(sub.power) + " " + str(sub.primary ? "primary" : "secondary"))
        end
        if self.size() == 0
            log("No subscriptions configured")
        end
        log("------------------------")
    end

    def initialize_subscriptions()
        for i:0..self.size()-1
            var subscription = self.list[i]

            mqtt.subscribe(subscription.topic, def(topic, idx, payload)
                var message = json.load(payload)
                
                var powerKey = "POWER";
                var powerKeyN = "POWER" + str(subscription.power);

                var value = nil
                if message.contains(powerKeyN)
                    value = message[powerKeyN]
                elif subscription.power == 1 && message.contains(powerKey)
                    value = message[powerKey]
                end

                if value != nil
                    if value == "ON"
                        if subscription.primary
                            set_primary_indicator()
                        else
                            set_secondary_indicator()
                        end
                    elif value == "OFF"
                        set_released_indicator()
                    else
                        set_error_indicator()
                        log("QARL: unknown state: " + value)
                    end
                end
            end)

            log("QARL: added subscription for topic: " + subscription.topic + " POWER" + str(subscription.power) + " " + (subscription.primary ? "primary" : "secondary"))
        end
    end
end

var power_count = size(tasmota.get_power())
set_color("FFFFFF")

def initialize_indicator()
    if power_count > 1 && tasmota.get_power()[0]
        set_primary_indicator()
    elif power_count == 3 && tasmota.get_power()[1]
        set_secondary_indicator()
    else
        set_released_indicator()
    end
end

def power_off_indicator()
    tasmota.set_power(power_count - 1, false)
end

def on_wifi_connected()
    log("QARL: wifi connected")
    set_color("FF9900") # Orange
end

def on_wifi_disconnected()
    log("QARL: wifi disconnected")
    set_color("FF0000") # Red
end

def on_mqtt_connecting()
    log("QARL: mqtt connecting...")
    set_color("FF00FF") # Magenta
    tasmota.set_timer(500, def()
        if mqtt.connected()
            initialize_indicator()
        end
    end)
end

def on_mqtt_disconnected()
    log("QARL: mqtt disconnected")
    set_color("FF00FF") # Magenta
end

tasmota.add_rule("Wifi#Connected", on_wifi_connected)
tasmota.add_rule("Wifi#Disconnected", on_wifi_disconnected)
tasmota.add_rule("Mqtt#Connected", on_mqtt_connecting)
tasmota.add_rule("Mqtt#Disconnected", on_mqtt_disconnected)

def single_power1_changed(value)
    if value == 1
        set_primary_indicator()
    else
        set_released_indicator()
    end
end

def double_power1_changed(value)
    if value == 1
        set_primary_indicator()
    elif tasmota.get_power()[1]
        set_secondary_indicator()
    else
        set_released_indicator()
    end
end

def double_power2_changed(value)
    if tasmota.get_power()[0]
        set_primary_indicator()
    elif value == 1
        set_secondary_indicator()
    else
        set_released_indicator()
    end
end

if power_count == 1 # only LED
    log("QARL: powers configured: 1")
elif power_count == 2 # x1 relay + LED
    tasmota.add_rule("Power1#State", single_power1_changed)
    log("QARL: powers configured: 1")
elif power_count == 3 # x2 relay + LED
    tasmota.add_rule("Power1#State", double_power1_changed)
    tasmota.add_rule("Power2#State", double_power2_changed)
    log("QARL: powers configured: 2")
else
    log("QARL: invalid power_count configured: " + str(power_count))
    set_error_indicator()
end

tasmota.add_cmd("Subs", def()
    var subscriptions = subscriptions()
    subscriptions.print()
end)

tasmota.add_cmd("AddSub", def(cmd, idx, param)
    if param == ""
        log("HELP: AddSub <topic> <power_number> [<primary:true|false>]")
    else
        var subscriptions = subscriptions()
        var parts = string.split(param, " ")
        subscriptions.add(parts[0], parts[1], parts[2])
        subscriptions.print()
    end
end)

tasmota.add_cmd("DelSub", def(cmd, idx, param)
    if param == ""
        log("HELP: DelSub <subscription_index>")
    else
        var subscriptions = subscriptions()
        subscriptions.delete(int(param))
        subscriptions.print()
    end
end)

var subs = subscriptions()
subs.initialize_subscriptions()