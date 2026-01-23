import json
import mqtt
import string
import indicator

class PowerSubscription
    var topic
    var power
    var indicator
    
    def init(topic, power, indicator)
        self.topic = topic
        self.power = power
        self.indicator = indicator
    end
    
    def to_map()
        return {"topic": self.topic, "power": self.power, "indicator": self.indicator}
    end

    static def from_json(json_payload)
        return PowerSubscription(json_payload["topic"], json_payload["power"], json_payload["indicator"])
    end
end

class PowerSubscriptions
    var subscriptions
    
    def init()
        self.subscriptions = []
        
        var mem1 = tasmota.cmd("Mem1")["Mem1"]
        if mem1 != ""
            var data = json.load(mem1)
            if data.find("powerSubscriptions")
                for item : data["powerSubscriptions"]
                    self.subscriptions.push(PowerSubscription.from_json(item))
                end
            end
        end
    end
    
    def size()
        return size(self.subscriptions)
    end
    
    def save()
        var data = []
        for i:0..self.size()-1
            data.push(self.subscriptions[i].to_map())
        end
        var json_payload = json.dump({'powerSubscriptions': data})
        tasmota.cmd("Mem1 " + json_payload)
    end
    
    def add(topic, power, indicator)
        self.subscriptions.push(PowerSubscription("stat/" + topic + "/RESULT", string.toupper(power), string.toupper(indicator) == "SECONDARY" ? "SECONDARY" : "PRIMARY"))
        self.save()
    end
    
    def delete(index)
        self.subscriptions.remove(index - 1)
        self.save()
    end
    
    def print()
        log("---- Power subscriptions (" + str(self.size()) + ") ----")
        if self.size() == 0
            log("No subscriptions configured")
        else
            for i:0..self.size()-1
                var sub = self.subscriptions[i]
                log(str(i+1) + ". " + sub.topic + " " + sub.power + " " + sub.indicator)
            end
        end
        log("------------------------")
    end

    def create_rules()
        for i:0..self.size()-1
            var subscription = self.subscriptions[i]

            mqtt.subscribe(subscription.topic, def(topic, idx, payload)
                var message = json.load(payload)
                
                var value = message.find(subscription.power)
                if value != nil
                    if value == "ON"
                        if subscription.indicator == "SECONDARY"
                            indicator.set_secondary_color()
                        else
                            indicator.set_primary_color()
                        end
                    elif value == "OFF"
                        indicator.set_cleared_color()
                    else
                        indicator.set_error_color()
                        log("QARL: unknown state: " + value)
                    end
                end
            end)

            log("QARL: added power subscription for topic: " + subscription.topic + " " + subscription.power + " " + subscription.indicator)
        end
    end
end

var power_subscriptions = module("power_subscriptions")

power_subscriptions.create_rules = def()
    PowerSubscriptions().create_rules()
end

power_subscriptions.add_commands = def()
    tasmota.add_cmd("PwrSubs", def()
        PowerSubscriptions().print()
    end)
    
    tasmota.add_cmd("AddPwrSub", def(cmd, idx, param)
        if param == ""
            log("HELP: AddPwrSub <topic> <POWER1|POWER2|...> [PRIMARY|SECONDARY]")
        else
            var subscriptions = PowerSubscriptions()
            var parts = string.split(param, " ")
            subscriptions.add(parts[0], parts[1], parts[2])
            subscriptions.print()
        end
    end)
    
    tasmota.add_cmd("DelPwrSub", def(cmd, idx, param)
        if param == ""
            log("HELP: DelPwrSub <subscription_index>")
        else
            var subscriptions = PowerSubscriptions()
            subscriptions.delete(int(param))
            subscriptions.print()
        end
    end)
end

return power_subscriptions;