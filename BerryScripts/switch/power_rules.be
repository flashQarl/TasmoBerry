import indicator

var power_rules = module("power_rules")

def single_power1_changed(value)
    if value == 1
        indicator.set_primary_color()
    else
        indicator.set_cleared_color()
    end
end

def double_power1_changed(value)
    if value == 1
        indicator.set_primary_color()
    elif tasmota.get_power()[1]
        indicator.set_secondary_color()
    else
        indicator.set_cleared_color()
    end
end

def double_power2_changed(value)
    if tasmota.get_power()[0]
        indicator.set_primary_color()
    elif value == 1
        indicator.set_secondary_color()
    else
        indicator.set_cleared_color()
    end
end

power_rules.create_power_rules = def()
    var power_count = size(tasmota.get_power())

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
        indicator.set_error_color()
    end
end

return power_rules