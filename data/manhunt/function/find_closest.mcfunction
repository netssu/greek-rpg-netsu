execute if score Temp manhunt_dst > @s manhunt_dst run tag @e remove manhunt_closest
execute if score Temp manhunt_dst > @s manhunt_dst run tag @s add manhunt_closest
execute if score Temp manhunt_dst > @s manhunt_dst run scoreboard players operation Temp manhunt_dst = @s manhunt_dst