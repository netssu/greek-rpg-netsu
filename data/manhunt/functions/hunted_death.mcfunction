execute store result score @s manhunt_respawn_x run data get entity @s Pos[0]
execute store result score @s manhunt_respawn_y run data get entity @s Pos[1]
execute store result score @s manhunt_respawn_z run data get entity @s Pos[2]

scoreboard players operation @s manhunt_respawn_time = HunterRespawnSeconds manhunt_config
scoreboard players set @s manhunt_deaths 0

tag @s add manhunt_wait_respawn

gamemode spectator @s
