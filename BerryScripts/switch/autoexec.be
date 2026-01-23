log("------------------------------------------------------------")
log("QARL: version 6")
log("------------------------------------------------------------")

import indicator
import power_rules
import startup_rules
import power_subscriptions
import button_subscriptions

indicator.set_startup_color()
startup_rules.create_startup_rules()
power_rules.create_power_rules()
power_subscriptions.create_rules()
power_subscriptions.add_commands()
button_subscriptions.create_rules()
button_subscriptions.add_commands()