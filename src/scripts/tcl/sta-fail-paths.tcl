# MIT License
# -----------------------------------------------------------------------------
# Copyright (c) 2026 Dominic Beesley https://github.com/dominicbeesley
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
# -----------------------------------------------------------------------------

# List the worst failing setup and hold paths in every timing corner.
# Used by the board Makefiles' "timing" target when the summary shows a fail.
#
# usage: quartus_sta -t sta-fail-paths.tcl <project> <output file>

set project [lindex $quartus(args) 0]
set outfile [lindex $quartus(args) 1]

project_open $project
create_timing_netlist
read_sdc
update_timing_netlist

# start with an empty file; each report below appends to it
close [open $outfile w]

foreach_in_collection oc [get_available_operating_conditions] {
   set_operating_conditions $oc
   update_timing_netlist
   set corner [get_operating_conditions_info $oc -display_name]

   foreach kind {setup hold} {
      set f [open $outfile a]
      puts $f ""
      puts $f "==== $corner : $kind ===="
      close $f
      report_timing -$kind -npaths 5 -nworst 1 -less_than_slack 0 \
         -detail summary -file $outfile -append
   }
}

delete_timing_netlist
project_close
