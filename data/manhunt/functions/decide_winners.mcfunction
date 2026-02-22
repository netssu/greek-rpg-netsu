execute if entity @e[team=runners,tag=!manhunt_died] run tellraw @a {"text":"The runners have won!","bold":true,"color":"red"}
execute unless entity @e[team=runners,tag=!manhunt_died] if entity @e[team=hunters] run tellraw @a {"text":"The hunters have won!","bold":true,"color":"blue"}

function manhunt:game_over