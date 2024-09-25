# Add signals to the waveform
set sig_list [list]
lappend sig_list "sda_o"
lappend sig_list "scl_o"
gtkwave::addSignalsFromList $sig_list

gtkwave::/File/Export/Write_VCD_File_As dump_pulseview.vcd
gtkwave::/File/Quit
