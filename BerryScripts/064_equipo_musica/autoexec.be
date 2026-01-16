def ir_power(value)
    if value == 1
        tasmota.cmd('IRSend {"Protocol":"NEC","Bits":32,"Data":"0x4FBE817","DataLSB":"0x20DF17E8","Repeat":0}')
    end
end

def ir_cd(value)
    if value == 1
        tasmota.cmd('IRSend {"Protocol":"NEC","Bits":32,"Data":"0x4FB8877","DataLSB":"0x20DF11EE","Repeat":0}')
    end
end

def ir_vol_up(value)
    if value == 1
        tasmota.cmd('IRSend {"Protocol":"NEC","Bits":32,"Data":"0x4FB609F","DataLSB":"0x20DF06F9","Repeat":0}')
    end
end

def ir_vol_down(value)
    if value == 1
        tasmota.cmd('IRSend {"Protocol":"NEC","Bits":32,"Data":"0x4FB40BF","DataLSB":"0x20DF02FD","Repeat":0}')
    end
end

def ir_mute(value)
    tasmota.cmd('IRSend {"Protocol":"NEC","Bits":32,"Data":"0x4FB50AF","DataLSB":"0x20DF0AF5","Repeat":0}')
end

def power_on(value)
    if value == 1
        tasmota.delay(1000)
        ir_power(1)
        tasmota.delay(1000)
        ir_cd(1)
        
        for i:0..9
            tasmota.delay(200)
            ir_vol_up(1)
        end
    elif value == 0
        tasmota.set_power(5, false)
    end
end

tasmota.add_rule("Power1#state", power_on)
tasmota.add_rule("Power2#state", ir_power)
tasmota.add_rule("Power3#state", ir_cd)
tasmota.add_rule("Power4#state", ir_vol_up)
tasmota.add_rule("Power5#state", ir_vol_down)
tasmota.add_rule("Power6#state", ir_mute)

tasmota.set_power(0, false)
tasmota.delay(400)
tasmota.set_power(0, true)