onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -height 35 /circuito_exp6_tb5_4/clock
add wave -noupdate -height 35 -radix unsigned /circuito_exp6_tb5_4/UC/db_estado
add wave -noupdate -color Aquamarine -height 35 /circuito_exp6_tb5_4/jogar
add wave -noupdate -color {Orange Red} -height 35 /circuito_exp6_tb5_4/FD/jogada_feita
add wave -noupdate -color {Orange Red} -height 35 /circuito_exp6_tb5_4/UC/registraR
add wave -noupdate -color White -height 35 /circuito_exp6_tb5_4/configuracao
add wave -noupdate -color White -height 35 /circuito_exp6_tb5_4/FD/db_configuracao
add wave -noupdate -height 35 -radix unsigned /circuito_exp6_tb5_4/FD/db_contagem
add wave -noupdate -height 35 -radix unsigned /circuito_exp6_tb5_4/FD/db_jogada
add wave -noupdate -height 35 -radix unsigned /circuito_exp6_tb5_4/FD/db_memoria
add wave -noupdate -color {Medium Aquamarine} -height 35 /circuito_exp6_tb5_4/FD/fimL
add wave -noupdate -height 35 -radix unsigned /circuito_exp6_tb5_4/FD/leds
add wave -noupdate -color Red -height 35 /circuito_exp6_tb5_4/UC/timeout
add wave -noupdate -color {Medium Aquamarine} -height 35 /circuito_exp6_tb5_4/pronto
add wave -noupdate -color Blue -height 35 /circuito_exp6_tb5_4/ganhou
add wave -noupdate -color Red -height 35 /circuito_exp6_tb5_4/perdeu
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {5480400 us} 0}
quietly wave cursor active 1
configure wave -namecolwidth 258
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 us} {5467400 us}
