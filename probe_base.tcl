
# GTKWAVE

# Add items to ctrl list for parsing. Final elements follow standard TCL regex. Avoid spaces
# Example - Add a comment:
#   lappend ctrl "comment my_testbench"

# Example - Add a single signal:
#   lappend ctrl "signal tb.dut.clk$"
#
#   **********************************************************************
#   *  Note that the periods are resolved as the typical regex '.',      *
#   *  so if you had a single called "dutaclk" it would get caught here. *
#   *  The $ is included to be even more specific incase there would be  *
#   *   a "tb.dut.clka" signal that you didn't want                      *
#   **********************************************************************

# Example - Add a comment:
#   lappend ctrl "comment my_comment"

# Example - Add multiple signals with a prefix:
#   lappend ctrl "signal tb.dut.avalon_bus_.*"

# Example - Add all signals recursively under a design unit:
#   lappend ctrl "signal tb.dut.*"

# Example - Add a grouping of signals:
#   lappend ctrl "group tb.dut.fifo.* group_name"


# Example - Full usage;
# set     ctrl [list]
# lappend ctrl "comment tesbench_signals"
# lappend ctrl "signal fifo_tb\.clk"
# lappend ctrl "group  fifo_tb\.wr_.* wr_fifo_grp"

# get list of facilities from gtkwave
# these are all the signals in the design
set nfacs [ gtkwave::getNumFacs ]
set facs [list]
for {set i 0} {$i < $nfacs } {incr i} {
    set facname [ gtkwave::getFacName $i]
    lappend facs "$facname"
}

#foreach fac $facs {
#    puts "debug, fac: $fac"
#}

# make vectors match without having to specify length, then sort uniques
# also patch out the stupid single-bit wire issue

#    debug, fac: tb.TESTPARAM   -> tb.TESTPARAM
#    debug, fac: tb.bb[3:0]     -> tb.bb
#    debug, fac: tb.c           -> tb.c
#    debug, fac: tb.clk         -> tb.clk
#    debug, fac: tb.dut.bb[0]   -> tb.dut.bb
#    debug, fac: tb.dut.bb[1]   -> 
#    debug, fac: tb.dut.bb[2]   -> 
#    debug, fac: tb.dut.bb[3]   -> 
#    debug, fac: tb.dut.c       -> tb.dut.c
#    debug, fac: tb.dut.clk     -> tb.dut.clk
#    debug, fac: tb.dut.xx[3:0] -> tb.dut.xx
#    debug, fac: tb.tt[3:0]     -> tb.tt
#    debug, fac: tb.xx[3:0]     -> tb.xx

for {set i 0} {$i < [llength $facs]} {incr i} {
    if {[regexp -all {(.*)(\[.*\])$} [lindex $facs $i] whole one two]} {
        #puts "subbed [lindex $facs $i] for $one"
        lset facs $i $one
    }
}

set facs [lsort -unique $facs]

#foreach fac $facs {
#    puts "debug, fac: $fac"
#}

set signal_cmds {
    "signal"
    "fixedpoint"
    "avalon"
    "ram"
}

set format_cmds {
    "format"
    "color"
    "fixedpoint"
}


# loop through the ctrl array and look for comments or signals
# perform the appropriate gtkwave tcl command based on the type
# if it's a signal type, do a wildcard match check before adding
set group_open 1

foreach item $ctrl {
    puts "Processing command: $item"
    # make gtkwave comment
    if {[lindex $item 0] == "comment"} {
        set comment [lindex $item 1]
        gtkwave::addCommentTracesFromList $comment
        continue
    }

    # change trace hierarchy
    if {[lindex $item 0] == "hier"} {
        gtkwave::/Edit/Set_Trace_Max_Hier [lindex $item 1]
        continue
    }

    # make groups auto open/close
    if {[lindex $item 0] == "close"} {
      set group_open = 0
      continue
    }
    if {[lindex $item 0] == "open"} {
      set group_open = 1
      continue
    }
 
    # add signals
    if {[lindex $item 0] in $signal_cmds} {
        gtkwave::/Edit/UnHighlight_All
        set myfacs {}
        # glob avalon or ram custom bundles
        if {([lindex $item 0] == "avalon") || ([lindex $item 0] == "ram")} {
            set prefix [lindex $item 1]
            # avalon
            if {[lindex $item 0] == "avalon"} {
                set values {
                    write read waitrequest 
                    address burstcount 
                    writedata byteenable readdata readdatavalid
                }
            # ram
            } else {
                set values {
                    we re addr d be q
                }
            }
            # glob signals
            foreach value $values {
                foreach signal $facs {
                    set rxp "${prefix}${value}\$"
                    if [ regexp $rxp $signal match ] {
                        lappend myfacs $signal
                    }
                }
            }
        # glob signals from regex, no bundle
        } else {
            set value [lindex $item 1]
            set rxp "^$value\$"
            # glob signals that match the regex
            foreach signal $facs {
                if [ regexp $rxp $signal match ] {
                    lappend myfacs $signal
                }
            }
        }
        # add signals if any regex hit
        if { [llength $myfacs] != 0 } {
            gtkwave::addSignalsFromList $myfacs
            # also keep track of in this group variable
        }
        if {[lindex $item 0] ni $format_cmds} {
            continue
        }
    }

    # format signals from previous addition
    if {([lindex $item 0] in $format_cmds) && ([llength $myfacs] != 0)} {
        # apply data format
        if {[lindex $item 0] == "format"} {
            gtkwave::/Edit/Data_Format/[lindex $item 1]
        # apply color format
        } elseif {[lindex $item 0] == "color"} {
            gtkwave::/Edit/Color_Format/[lindex $item 1]
        # apply fixed point shift
        } elseif {([lindex $item 0] == "fixedpoint") || ([lindex $item 0] == "fxp")} {
            gtkwave::/Edit/Data_Format/Fixed_Point_Shift/Specify [lindex $item 2]
            gtkwave::/Edit/Data_Format/Fixed_Point_Shift/On
            gtkwave::/Edit/Data_Format/Signed_Decimal
        }
        continue
    }

    # create groupings based on new addition
    if {[lindex $item 0] == "group"} {
        # add grouping from signals -- this currently doesn't work
        # would be nice if 'highlightSignalsFromList' worked the way the adder does'
        gtkwave::/Edit/Create_Group [lindex $item 1]
        if { $group_open == 0 } {
            gtkwave::/Edit/Toggle_Group_Open|Close
        }
        continue
    }

}

# Play around with these commands if adding groups in:

#gtkwave::/Edit/Set_Trace_Max_Hier 0
#gtkwave::addSignalsFromList {"top.fft.ready"}
#gtkwave::/Edit/UnHighlight_All
#gtkwave::/Edit/Highlight_Regexp "top.fft.u_fft_stage_control.addr(_next)\\\[.*\\\]"
#gtkwave::/Edit/Highlight_Regexp "top.fft.ready"
#gtkwave::/Edit/Set_Trace_Max_Hier 1

gtkwave::/Time/Zoom/Zoom_Full
gtkwave::/Edit/UnHighlight_All
