#Hunter respawn - returns to survival at their spawn point (bed or default)
tag @s remove manhunt_died
gamemode survival @s
scoreboard players set @s manhunt_spec_timer -1

tellraw @s [{"text":"[Manhunt] ","color":"gold"},{"text":"Você respawnou!","color":"green"}]
title @s title {"text":"Respawnado!","color":"green","bold":true}
title @s subtitle {"text":"Boa sorte, hunter!","color":"yellow"}
