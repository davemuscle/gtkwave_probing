#!/bin/bash

declare -a PROBES
declare -a VCDS

PROBES=($(find . -name "*.probe"))
VCDS=($(find . -name "*.vcd"))
SCRIPT_DIR=$(dirname $(readlink $0))
TMPFILE=.tmp.wave.tcl

# Cleanup
rm -f $TMPFILE

# Choose from list of VCD files (required)
if [ ${#VCDS[@]} -eq 1 ]; then
    VCD=${VCDS[0]}
elif [ ${#VCDS[@]} -ne 0 ]; then
    echo "Select a VCD file to open (CTRL+C to exit):"
    select VCD in ${VCDS[@]}
    do
        break;
    done
    echo "Selected VCD: $VCD"
else
    echo "No VCD files found"
    VCD=""
    exit;
fi

# Check if a VCD file is even selected
if [ -z "$VCD" ]; then
    echo "No VCD file selected"
    exit;
fi

echo ""
PROBE=""
# Choose from list of Probes (optional)
if [ ${#PROBES[@]} -ne 0 ]; then
    echo "Select a probe to open a waveform with (CTRL+C to exit, CTRL+D to skip):"
    select PROBE in ${PROBES[@]}
    do
        break;
    done
fi

if [ -n "$PROBE" ]; then
    cp $PROBE $TMPFILE
    # Pre-process whitespace and handle escape sequences for tcl/regex capturing classes
    # sed commands in order of appearance:
    # - ignore comment lines
    # - trim whitespace
    # - remove empty lines
    # - replace with curly braces
    # - replace [ with \[ for tcl escape
    # - replace \\[ with \\\[ for capturing class escape
    sed -Ei '/#/d'                                      $TMPFILE
    sed -Ei 's/^ *//; s/ *$$//; s/ +/ /g'               $TMPFILE
    sed -Ei '/^$$/d'                                    $TMPFILE
    sed -Ei 's/^/{/ ; s/$$/}/; s/ /} {/g'               $TMPFILE
    sed -Ei 's/\[/\\[/g; s/\]/\\]/g'                    $TMPFILE
    sed -Ei 's/\\\\\[/\\\\\\\[/g ; s/\\\\\]/\\\\\\\]/g' $TMPFILE

    # Process regex commands into tcl compatible with the probe tcl base
    # - place each line in quotes
    # - add the append command to each line of text
    # - add the list definition
    sed -Ei 's/^/"/; s/$$/"/'           $TMPFILE
    sed -Ei 's/^/lappend ctrl /'        $TMPFILE
    sed -Ei '1s/^/set ctrl \[list\]\n/' $TMPFILE
    
    cat ${SCRIPT_DIR}/probe_base.tcl >> $TMPFILE
    gtkwave -og $VCD -S $TMPFILE &

else
    gtkwave -og $VCD &

fi
