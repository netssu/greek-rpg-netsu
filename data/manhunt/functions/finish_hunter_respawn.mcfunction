gamemode survival @s
execute store result entity @s Pos[0] double 1 run scoreboard players get @s manhunt_respawn_x
execute store result entity @s Pos[1] double 1 run scoreboard players get @s manhunt_respawn_y
execute store result entity @s Pos[2] double 1 run scoreboard players get @s manhunt_respawn_z

tag @s remove manhunt_wait_respawn
scoreboard players reset @s manhunt_respawn_time
