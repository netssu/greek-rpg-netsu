#Hunter respawn - phase 1: kill to respawn at bed/default spawn
tag @s remove manhunt_died
tag @s add manhunt_respawning
scoreboard players set @s manhunt_spec_timer -1

#Enable autorespawn and hide death message
gamerule doImmediateRespawn true
gamerule showDeathMessages false

#Kill to force respawn at bed/default spawn point
#Phase 2 (gamemode survival, restore gamerules) happens in tick.mcfunction next tick
kill @s
