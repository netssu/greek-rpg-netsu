scoreboard players remove @a[tag=manhunt_wait_respawn,scores={manhunt_respawn_time=1..}] manhunt_respawn_time 1
execute as @a[tag=manhunt_wait_respawn,scores={manhunt_respawn_time=..0}] run function manhunt:finish_respawn
