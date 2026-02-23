execute if score Temp manhunt_enabled matches 1.. as @a[scores={manhunt_deaths=1..},team=runners,tag=!manhunt_respawning] run function manhunt:runners_death
execute if score Temp manhunt_enabled matches 1.. as @a[scores={manhunt_deaths=1..},team=hunters,tag=!manhunt_respawning] run function manhunt:hunted_death
scoreboard players set @a manhunt_deaths 0

#Phase 2 of hunter respawn: after kill auto-respawn, set survival and restore gamerules
execute if entity @a[tag=manhunt_respawning] run gamerule doImmediateRespawn false
execute if entity @a[tag=manhunt_respawning] run gamerule showDeathMessages true
execute as @a[tag=manhunt_respawning] run gamemode survival @s
execute as @a[tag=manhunt_respawning] run tellraw @s [{"text":"[Manhunt] ","color":"gold"},{"text":"Você respawnou!","color":"green"}]
execute as @a[tag=manhunt_respawning] run title @s title {"text":"Respawnado!","color":"green","bold":true}
execute as @a[tag=manhunt_respawning] run title @s subtitle {"text":"Boa sorte, hunter!","color":"yellow"}
tag @a remove manhunt_respawning

#Enforce spectator for dead players every tick (safety net)
gamemode spectator @a[tag=manhunt_died,gamemode=!spectator]

scoreboard players add Temp manhunt_ticks 1
execute if score Temp manhunt_ticks matches 20.. run function manhunt:second
