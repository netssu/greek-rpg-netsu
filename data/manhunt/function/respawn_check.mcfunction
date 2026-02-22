#Decrement spectator timer for dead players
execute as @a[scores={manhunt_spec_timer=1..},tag=manhunt_died] run scoreboard players remove @s manhunt_spec_timer 1

#Show countdown on actionbar
execute as @a[scores={manhunt_spec_timer=1..},tag=manhunt_died] run title @s actionbar [{"text":"Respawnando em ","color":"yellow"},{"score":{"name":"@s","objective":"manhunt_spec_timer"},"color":"red"},{"text":" segundos","color":"yellow"}]

#Hunter respawn when timer reaches 0
execute as @a[scores={manhunt_spec_timer=0},team=hunters,tag=manhunt_died] run function manhunt:hunter_respawn

#Runner respawn when timer reaches 0
execute as @a[scores={manhunt_spec_timer=0},team=runners,tag=manhunt_died] run function manhunt:runner_respawn
