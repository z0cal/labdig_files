onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -height 35 /teste/clock
add wave -noupdate -height 35 -radix unsigned /teste/UC/db_estado
add wave -noupdate -color Aquamarine -height 35 /teste/inicial
add wave -noupdate -color Aquamarine -height 35 /teste/jogar
add wave -noupdate -color {Orange Red} -height 35 /teste/FD/jogada_feita
add wave -noupdate -color {Orange Red} -height 35 /teste/UC/registraR
add wave -noupdate -color White -height 35 /teste/configuracao
add wave -noupdate -color White -height 35 /teste/FD/db_configuracao
add wave -noupdate -height 35 -radix unsigned /teste/FD/db_contagem
add wave -noupdate -height 35 -radix unsigned /teste/FD/db_jogada
add wave -noupdate -height 35 -radix unsigned /teste/FD/db_memoria
add wave -noupdate -color {Medium Aquamarine} -height 35 /teste/FD/fimL
add wave -noupdate -height 35 -radix unsigned /teste/FD/leds
add wave -noupdate -color Red -height 35 /teste/UC/timeout
add wave -noupdate -color {Medium Aquamarine} -height 35 /teste/pronto
add wave -noupdate -color Blue -height 35 /teste/ganhou
add wave -noupdate -color Red -height 35 /teste/perdeu
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {97400 us} 0}
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
WaveRestoreZoom {0 us} {468300 us}
