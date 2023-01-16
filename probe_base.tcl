
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

# loop through the ctrl array and look for comments or signals
# perform the appropriate gtkwave tcl command based on the type
# if it's a signal type, do a wildcard match check before adding
set groups_open 1

foreach item $ctrl {
    if {[lindex $item 0] == "comment"} {
        set comment [lindex $item 1]
        # make gtkwave comment
        gtkwave::addCommentTracesFromList $comment
    } elseif {[lindex $item 0] == "signal"} {
        set value [lindex $item 1]
        # glob signals that match the regex
        set myfacs {}
        foreach signal $facs {
            if [ regexp $value $signal match ] {
                lappend myfacs $signal
            }
        }
        if { [llength $myfacs] != 0 } {
            gtkwave::addSignalsFromList $myfacs
        }
    } elseif {[lindex $item 0] == "group"} {
        set value [lindex $item 1]
        set name [lindex $item 2]
        # glob signals that match the regex
        set myfacs {}
        foreach signal $facs {
            if [ regexp $value $signal match ] {
                lappend myfacs $signal
            }
        }
        if { [llength $myfacs] != 0 } {
            # add grouping and signals
            gtkwave::highlightSignalsFromList $myfacs
            gtkwave::addSignalsFromList $myfacs
            gtkwave::/Edit/Create_Group $name
            if { $groups_open == 0 } {
                gtkwave::/Edit/Toggle_Group_Open|Close
            }
            gtkwave::/Edit/UnHighlight_All
        }
    } elseif {[lindex $item 0] == "avalon"} {
        set prefix [lindex $item 1]
        set values {write read waitrequest address burstcount writedata byteenable readdata readdatavalid}
        set myfacs {}
        foreach value $values {
            foreach signal $facs {
                if [ regexp ${prefix}${value} $signal match ] {
                    lappend myfacs $signal
                }
            }
        }
        set name [lindex $item 2]
        if { [llength $myfacs] != 0 } {
            # add grouping for avalon signals
            gtkwave::highlightSignalsFromList $myfacs
            gtkwave::addSignalsFromList $myfacs
            gtkwave::/Edit/Create_Group $name
            if { $groups_open == 0 } {
                gtkwave::/Edit/Toggle_Group_Open|Close
            }
            gtkwave::/Edit/UnHighlight_All
        }
    } elseif {[lindex $item 0] == "format" } {
        set type [lindex $item 1]
        if { [llength $myfacs] != 0 } {
            # apply data format to previous facs
            gtkwave::highlightSignalsFromList $myfacs
            gtkwave::/Edit/Data_Format/$type
            gtkwave::/Edit/UnHighlight_All
        }
    } elseif {[lindex $item 0] == "color" } {
        set type [lindex $item 1]
        if { [llength $myfacs] != 0 } {
            # apply data format to previous facs
            gtkwave::highlightSignalsFromList $myfacs
            gtkwave::/Edit/Color_Format/$type
            gtkwave::/Edit/UnHighlight_All
        }
    } elseif {[lindex $item 0] == "close" } {
        set groups_open 0
    } elseif {[lindex $item 0] == "open"  } {
        set groups_open 1
    }


}

gtkwave::/Time/Zoom/Zoom_Full
gtkwave::/Edit/UnHighlight_All
