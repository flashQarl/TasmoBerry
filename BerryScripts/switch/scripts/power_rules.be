import indicator

var power_rules = module("power_rules")

def power1_changed(value)
    indicator.set_primary(value == 1)
end

def power2_changed(value)
    indicator.set_secondary(value == 1)
end

power_rules.create_power_rules = def()
    var power_count = size(tasmota.get_power())
    
    if power_count > 3
        log("QARL: invalid power_count configured: " + str(power_count))
        indicator.set_error_color()
        return 
    end

    if power_count == 0
        log("LED 0 | POWERS 0")
        return
    end

    if power_count == 1
        log("LED 1 | POWERS 0")
        return
    end

    tasmota.add_rule("Power1#State", power1_changed)
    
    if power_count == 3
        log("QARL: LED 1 | POWERS 2")
        tasmota.add_rule("Power2#State", power2_changed)
    end
    
    log("LED 1 | POWERS " + str(power_count - 1))
end

return power_rules