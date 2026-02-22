#Check if there are alive runners to teleport to
execute if entity @e[team=runners,tag=!manhunt_died] run tag @s add manhunt_can_respawn

#Teleport to a random alive runner's position
execute if entity @s[tag=manhunt_can_respawn] at @e[team=runners,tag=!manhunt_died,limit=1,sort=random] run tp @s ~ ~ ~

#Set back to survival
execute if entity @s[tag=manhunt_can_respawn] run tag @s remove manhunt_died
execute if entity @s[tag=manhunt_can_respawn] run gamemode survival @s
execute if entity @s[tag=manhunt_can_respawn] run scoreboard players set @s manhunt_spec_timer -1

#Give glowing for remaining time (60 seconds = 1 minute remaining from the original 2 minutes)
execute if entity @s[tag=manhunt_can_respawn] run effect give @s minecraft:glowing 60 0

#Notify the respawned runner
execute if entity @s[tag=manhunt_can_respawn] run tellraw @s [{"text":"[Manhunt] ","color":"gold"},{"text":"Você respawnou ao lado de um runner!","color":"green"}]
execute if entity @s[tag=manhunt_can_respawn] run title @s title {"text":"Respawnado!","color":"green","bold":true}
execute if entity @s[tag=manhunt_can_respawn] run title @s subtitle {"text":"Você tem glowing por 1 minuto!","color":"yellow"}

tag @s remove manhunt_can_respawn

#If no alive runners remain, stay in spectator
execute if entity @s[tag=manhunt_died] run tellraw @s [{"text":"[Manhunt] ","color":"gold"},{"text":"Nenhum runner vivo encontrado. Permanecendo como espectador.","color":"red"}]
execute if entity @s[tag=manhunt_died] run scoreboard players set @s manhunt_spec_timer -1
