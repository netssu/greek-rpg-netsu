clear @a[team=hunters] minecraft:compass
title @a title {"text":"Game over","bold":true,"color":"gold"}
scoreboard players set Temp manhunt_enabled 0
scoreboard players set Starts: manhunt_display 0

#Clean up respawn timers and effects
scoreboard players reset @a manhunt_spec_timer
effect clear @a minecraft:glowing
gamemode spectator @a[tag=manhunt_died]