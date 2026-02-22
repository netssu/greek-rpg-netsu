tag @s add manhunt_died

gamemode spectator @s

#If there are other alive runners, set up respawn timer (60 seconds)
execute if entity @e[team=runners,tag=!manhunt_died] run scoreboard players set @s manhunt_spec_timer 60
execute if entity @e[team=runners,tag=!manhunt_died] run tellraw @s [{"text":"[Manhunt] ","color":"gold"},{"text":"Você morreu! Voltando em 60 segundos se ainda houver runners vivos...","color":"yellow"}]

#Give glowing effect to alive runners for 2 minutes (120 seconds)
execute if entity @e[team=runners,tag=!manhunt_died] as @e[team=runners,tag=!manhunt_died] run effect give @s minecraft:glowing 120 0

#Notify alive runners
execute if entity @e[team=runners,tag=!manhunt_died] run tellraw @e[team=runners,tag=!manhunt_died] [{"text":"[Manhunt] ","color":"gold"},{"selector":"@s","color":"red"},{"text":" morreu! Vocês estão com glowing por 2 minutos.","color":"yellow"}]
