execute if entity @a[team=runners,tag=!manhunt_died,tag=!manhunt_wait_respawn,limit=1] run gamemode survival @s
execute if entity @a[team=runners,tag=!manhunt_died,tag=!manhunt_wait_respawn,limit=1] run tp @s @a[team=runners,tag=!manhunt_died,tag=!manhunt_wait_respawn,sort=random,limit=1]
execute if entity @a[team=runners,tag=!manhunt_died,tag=!manhunt_wait_respawn,limit=1] run tag @s remove manhunt_died
execute if entity @a[team=runners,tag=!manhunt_died,tag=!manhunt_wait_respawn,limit=1] run tag @s remove manhunt_wait_respawn
execute if entity @a[team=runners,tag=!manhunt_died,tag=!manhunt_wait_respawn,limit=1] run scoreboard players reset @s manhunt_respawn_time

execute unless entity @a[team=runners,tag=!manhunt_died,tag=!manhunt_wait_respawn,limit=1] run tag @s remove manhunt_wait_respawn
execute unless entity @a[team=runners,tag=!manhunt_died,tag=!manhunt_wait_respawn,limit=1] run scoreboard players reset @s manhunt_respawn_time
