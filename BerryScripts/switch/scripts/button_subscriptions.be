import json
import mqtt
import string

class ButtonSubscription
    var topic
    var button
    var action
    var power
    
    def init(topic, button, action, power)
        self.topic = topic
        self.button = button
        self.action = action
        self.power = power
    end
    
    def to_map()
        return {"topic": self.topic, "button": self.button, "action": self.action, "power": self.power}
    end

    static def from_json(json_payload)
        return ButtonSubscription(json_payload["topic"], json_payload["button"], json_payload["action"], json_payload["power"])
    end
end

class ButtonSubscriptions
    var subscriptions
    
    def init()
        self.subscriptions = []

        try
            var file = open('BtnSubs.json', 'r')
            var data = json.load(file.read())
            if data.find("buttonSubscriptions")
                for item : data["buttonSubscriptions"]
                    self.subscriptions.push(ButtonSubscription.from_json(item))
                end
            end
        except ..
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

        var file = open('BtnSubs.json', 'w')
        file.write(json.dump({'buttonSubscriptions': data}))
        file.close()
    end
    
    def add(topic, button, action, power)
        var formatted_button = string.toupper(button[0]) + string.tolower(button[1..])
        self.subscriptions.push(ButtonSubscription("stat/" + topic + "/RESULT", formatted_button, string.toupper(action), string.toupper(power)))
        self.save()
    end
    
    def delete(index)
        self.subscriptions.remove(index - 1)
        self.save()
    end
    
    def print()
        log("---- Button subscriptions (" + str(self.size()) + ") ----")
        if self.size() == 0
            log("No subscriptions configured")
        else
            for i:0..self.size()-1
                var sub = self.subscriptions[i]
                log(str(i+1) + ". " + sub.topic + " " + sub.button + " " + sub.action + " " + sub.power)
            end
        end
        log("------------------------")
    end

    def create_rules()
        for i:0..self.size()-1
            var subscription = self.subscriptions[i]

            mqtt.subscribe(subscription.topic, def(topic, idx, payload)
                var message = json.load(payload)
                var button = message.find(subscription.button)
                if (button)
                    var action = button.find("Action")
                    if (action == subscription.action)
                        tasmota.cmd(subscription.power + " 2")
                    end
                end
            end)

            log("QARL: added button subscription for topic: " + subscription.topic + " " + subscription.button + " " + subscription.action + " " + subscription.power)
        end
    end
end

var button_subscriptions = module("button_subscriptions")

button_subscriptions.create_rules = def()
    ButtonSubscriptions().create_rules()
end

button_subscriptions.add_commands = def()
    tasmota.add_cmd("BtnSubs", def()
        ButtonSubscriptions().print()
        tasmota.resp_cmnd_done()
    end)
    
    tasmota.add_cmd("AddBtnSub", def(cmd, idx, param)
        if param == ""
            tasmota.resp_cmnd_str("AddBtnSub <topic> <Button1|Button2|...> <SINGLE|HOLD> <POWER1|POWER2|...>");
        else
            var subscriptions = ButtonSubscriptions()
            var parts = string.split(param, " ")
            subscriptions.add(parts[0], parts[1], parts[2], parts[3])
            subscriptions.print()
            tasmota.resp_cmnd_done()
        end
    end)
    
    tasmota.add_cmd("DelBtnSub", def(cmd, idx, param)
        if param == ""
            tasmota.resp_cmnd_str("DelBtnSub <subscription_index>");
        else
            var subscriptions = ButtonSubscriptions()
            subscriptions.delete(int(param))
            subscriptions.print()
            tasmota.resp_cmnd_done()
        end
    end)
end

return button_subscriptions;