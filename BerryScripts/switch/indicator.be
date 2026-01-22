var indicator = module("indicator")

def set_color(color)
    tasmota.cmd("Color " + color)
end

indicator.set_startup_color = def()
    set_color("FFFFFF") # White
end

indicator.set_wifi_connected_color = def()
    set_color("FFFF00") # Yellow
end

indicator.set_wifi_disconnected_color = def()
    set_color("FF0000") # Red
end

indicator.set_mqtt_connecting_color = def()
    set_color("FF00FF") # Magenta
end

indicator.set_mqtt_disconnected_color = def()
    set_color("FF00FF") # Magenta
end

indicator.set_primary_color = def()
    set_color("00FF00") # Green
end

indicator.set_secondary_color = def()
    set_color("FF9900") # Orange
end

indicator.set_cleared_color = def()
    set_color("0000FF") # Blue
end

indicator.set_error_color = def()
    set_color("000020") # Dark Blue
end

indicator.sync_color_with_power = def()
    var power_count = size(tasmota.get_power())

    if power_count > 1
        if tasmota.get_power()[0]
            indicator.set_primary_color()
        elif power_count == 3 && tasmota.get_power()[1]
            indicator.set_secondary_color()
        else
            indicator.set_error_color()
        end
    else
        indicator.set_cleared_color()
    end
end

return indicator;