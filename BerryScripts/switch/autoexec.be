log("------------------------------------------------------------")
log("QARL: version 5")
log("------------------------------------------------------------")

import indicator
import power_rules
import startup_rules
import power_subscriptions

indicator.set_startup_color()
startup_rules.create_startup_rules()
power_rules.create_power_rules()
power_subscriptions.create_rules()