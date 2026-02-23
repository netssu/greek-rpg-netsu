execute store result score @s manhunt_respawn_x run data get entity @s Pos[0]
execute store result score @s manhunt_respawn_y run data get entity @s Pos[1]
execute store result score @s manhunt_respawn_z run data get entity @s Pos[2]

scoreboard players set @s manhunt_deaths 0

tag @s add manhunt_processing
execute if entity @a[team=runners,tag=!manhunt_died,tag=!manhunt_processing,limit=1] run function manhunt:runner_death_with_respawn
execute unless entity @a[team=runners,tag=!manhunt_died,tag=!manhunt_processing,limit=1] run function manhunt:runner_death_final
tag @s remove manhunt_processing
