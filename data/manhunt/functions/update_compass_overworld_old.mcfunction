#say ucoo

tag @s add tracker_temp

#Distance calculation
execute as @e[team=runners] store result score @s manhunt_x run data get entity @e[tag=tracker_temp,limit=1] Pos[0]
execute as @e[team=runners] store result score @s manhunt_y run data get entity @e[tag=tracker_temp,limit=1] Pos[1]
execute as @e[team=runners] store result score @s manhunt_z run data get entity @e[tag=tracker_temp,limit=1] Pos[2]

execute as @e[team=runners] run scoreboard players operation @s manhunt_x -= @s manhunt_x_o
execute as @e[team=runners] run scoreboard players operation @s manhunt_y -= @s manhunt_y_o
execute as @e[team=runners] run scoreboard players operation @s manhunt_z -= @s manhunt_z_o

execute as @e[team=runners] run scoreboard players operation @s manhunt_x *= @s manhunt_x
execute as @e[team=runners] run scoreboard players operation @s manhunt_y *= @s manhunt_y
execute as @e[team=runners] run scoreboard players operation @s manhunt_z *= @s manhunt_z

execute as @e[team=runners] run scoreboard players set @s manhunt_dst 0
execute as @e[team=runners] run scoreboard players operation @s manhunt_dst += @s manhunt_x
execute as @e[team=runners] run scoreboard players operation @s manhunt_dst += @s manhunt_y
execute as @e[team=runners] run scoreboard players operation @s manhunt_dst += @s manhunt_z

scoreboard players set Temp manhunt_dst 2147483647

execute as @e[team=runners] run function manhunt:find_closest

execute unless score @s manhunt_tid = @e[tag=manhunt_closest,limit=1] manhunt_rid run tellraw @s [{"text":""},{"text":"Now tracking: ","bold":true,"color":"gold"},{"selector":"@e[tag=manhunt_closest]"}]
scoreboard players operation @s manhunt_tid = @e[tag=manhunt_closest,limit=1] manhunt_rid

execute store result storage manhunt:compass_data X int 1 run scoreboard players get @e[tag=manhunt_closest,limit=1] manhunt_x_o
execute store result storage manhunt:compass_data Y int 1 run scoreboard players get @e[tag=manhunt_closest,limit=1] manhunt_y_o
execute store result storage manhunt:compass_data Z int 1 run scoreboard players get @e[tag=manhunt_closest,limit=1] manhunt_z_o

#Should we set to nearest (1) or make it go mad (0)
scoreboard players set Temp reg_1 0

execute unless score Temp manhunt_min_dst matches -2147483647.. run scoreboard players set Temp reg_1 1
execute if score Temp manhunt_min_dst matches -2147483647.. if score Temp manhunt_dst >= Temp manhunt_min_dst run scoreboard players set Temp reg_1 1

execute unless data entity @s Inventory[{id:"minecraft:compass",tag:{LodestoneDimension:"minecraft:overworld"}}] run clear @s minecraft:compass
execute unless data entity @s Inventory[{id:"minecraft:compass",tag:{LodestoneDimension:"minecraft:overworld"}}] run give @s minecraft:compass{LodestoneDimension:"minecraft:overworld",LodestoneTracked:0b}

execute if score Temp reg_1 matches 1 run function manhunt:set_compass_overworld_old
execute if score Temp reg_1 matches 0 run function manhunt:go_mad_old
scoreboard players set Temp reg_1 0

tag @s remove tracker_temp