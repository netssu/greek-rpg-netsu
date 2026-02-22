tag @s add manhunt_died

gamemode spectator @s

#Set spectator timer from configured value
scoreboard players operation @s manhunt_spec_timer = Temp manhunt_hunter_spec

tellraw @s [{"text":"[Manhunt] ","color":"gold"},{"text":"Você morreu! Voltando em ","color":"yellow"},{"score":{"name":"Temp","objective":"manhunt_hunter_spec"},"color":"red"},{"text":" segundos...","color":"yellow"}]
