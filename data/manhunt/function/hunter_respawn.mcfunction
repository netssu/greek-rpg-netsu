#Hunter respawn - kill to respawn at bed/default spawn
tag @s remove manhunt_died
tag @s add manhunt_respawning
scoreboard players set @s manhunt_spec_timer -1

#Enable autorespawn and hide death message
gamerule doImmediateRespawn true
gamerule showDeathMessages false

#Kill to force respawn at bed/default spawn point
kill @s

#Restore gamerules
gamerule doImmediateRespawn false
gamerule showDeathMessages true

#Set to survival (player is now at their spawn point)
gamemode survival @s

tellraw @s [{"text":"[Manhunt] ","color":"gold"},{"text":"Você respawnou!","color":"green"}]
title @s title {"text":"Respawnado!","color":"green","bold":true}
title @s subtitle {"text":"Boa sorte, hunter!","color":"yellow"}
