scoreboard objectives add reg_1 dummy

scoreboard objectives add manhunt_rid dummy
scoreboard objectives add manhunt_tid dummy

scoreboard objectives add manhunt_ticks dummy
scoreboard objectives add manhunt_enabled dummy
scoreboard objectives add manhunt_end dummy

scoreboard objectives add manhunt_display dummy
scoreboard objectives modify manhunt_display displayname ""
scoreboard objectives add manhunt_tab_hp dummy

scoreboard objectives add manhunt_deaths deathCount
scoreboard objectives add manhunt_lead dummy

scoreboard objectives add manhunt_x dummy
scoreboard objectives add manhunt_y dummy
scoreboard objectives add manhunt_z dummy

scoreboard objectives add manhunt_x_o dummy
scoreboard objectives add manhunt_y_o dummy
scoreboard objectives add manhunt_z_o dummy

scoreboard objectives add manhunt_x_n dummy
scoreboard objectives add manhunt_y_n dummy
scoreboard objectives add manhunt_z_n dummy

scoreboard objectives add manhunt_dst dummy
scoreboard objectives add manhunt_min_dst dummy
scoreboard objectives add manhunt_respawn_time dummy
scoreboard objectives add manhunt_respawn_x dummy
scoreboard objectives add manhunt_respawn_y dummy
scoreboard objectives add manhunt_respawn_z dummy
scoreboard objectives add manhunt_config dummy

execute unless score Temp manhunt_lead matches -2147483647.. run scoreboard players set Temp manhunt_lead 45
execute unless score HunterRespawnSeconds manhunt_config matches -2147483647.. run scoreboard players set HunterRespawnSeconds manhunt_config 5
execute unless score Temp manhunt_runner_glow matches -2147483647.. run scoreboard players set Temp manhunt_runner_glow 0

team add hunters "hunters"
team add runners "runners"
team modify hunters nametagVisibility hideForOtherTeams
team modify runners nametagVisibility hideForOtherTeams

scoreboard objectives add manhunt_prev dummy
execute unless score Temp manhunt_prev matches -2147483647.. run function manhunt:first_load

scoreboard objectives setdisplay list manhunt_tab_hp

tellraw @a {"text":"Manhunt (1.17.x, 1.18.x, 1.19.x, 1.20.x, 1.21.x)-13 Loaded","bold":true,"color":"gold"}
