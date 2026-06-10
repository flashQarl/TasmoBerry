var indicator = module("indicator")

def set_color(color)
    tasmota.cmd("Color " + color)
end

def set_cleared_color()
    set_color("0000AA") # Blue
end

def set_primary_color()
    set_color("00AA00") # Green
end

def set_secondary_color()
    set_color("AA7700") # Orange
end

indicator.init = def(m)

    class IndicatorManager
        var power_count
        var primary_enabled
        var secondary_enabled
        var locked_state

        def init()
            self.power_count = size(tasmota.get_power())
            self.primary_enabled = false
            self.secondary_enabled = false
            self.locked_state = false
            self.set_startup_color()
        end
        
        def set_startup_color()
            set_color("FFFFFF") # White
            self.locked_state = true
        end
        
        def set_wifi_connected_color()
            set_color("FFFF00") # Yellow
            self.locked_state = true
        end

        def set_wifi_disconnected_color()
            set_color("FF0000") # Red
            self.locked_state = true
        end

        def set_mqtt_connecting_color()
            set_color("FF00FF") # Magenta
            self.locked_state = true
        end

        def set_mqtt_disconnected_color()
            set_color("FF00FF") # Magenta
            self.locked_state = true
        end

        def set_error_color()
            set_color("000020") # Dark Blue
            self.locked_state = true
        end

        def sync_color_with_power()
            self.locked_state = false

            if self.power_count > 3
                self.set_error_color()
                return 
            end

            if self.power_count == 1
                self.primary_enabled = false
                self.secondary_enabled = false
                self.update_color()
                return 
            end

            if tasmota.get_power()[0]
                self.set_primary(true)
            elif tasmota.get_power()[1] && self.power_count == 3
                self.set_secondary(true)
            else
                self.update_color()
            end
        end
        
        def set_primary(enabled)
            self.primary_enabled = enabled
            self.update_color()
        end

        def set_secondary(enabled)
            self.secondary_enabled = enabled
            self.update_color()
        end

        def update_color()
            if self.locked_state == false
                if self.primary_enabled
                    set_primary_color()
                elif self.secondary_enabled
                    set_secondary_color()
                else
                    set_cleared_color()
                end
            end
        end
    end

    return IndicatorManager()
end

return indicator;