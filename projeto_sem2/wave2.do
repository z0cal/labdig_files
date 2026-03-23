onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -height 35 /tb_fd/clock
add wave -noupdate -height 35 /tb_fd/uuct/db_estado
add wave -noupdate -height 35 /tb_fd/botoes_raw
add wave -noupdate -height 35 /tb_fd/jogada_feita
add wave -noupdate -height 35 /tb_fd/start_pulso
add wave -noupdate -height 35 /tb_fd/uuct/registraR
add wave -noupdate -height 35 /tb_fd/uuct/fim_contagem
add wave -noupdate -height 35 /tb_fd/uuct/fim_tempo
add wave -noupdate -height 35 /tb_fd/uuct/perdeu
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {29300 us} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
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
configure wave -timelineunits sec
update
WaveRestoreZoom {0 us} {399 ms}
