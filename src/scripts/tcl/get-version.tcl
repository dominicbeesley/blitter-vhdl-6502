# MIT License
# -----------------------------------------------------------------------------
# Copyright (c) 2020 Dominic Beesley https://github.com/dominicbeesley
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

#  Company:         Dossytronics
#  Engineer:        Dominic Beesley
#  
#  Create Date:     Jun 2021
#  Design Name: 
#  Module Name:     get-version.tcl
#  Project Name: 
#  Target Devices: 
#  Tool versions: 
#  Description:     Attempt to get a version string from either svn or git
#  Dependencies: 
# 
#  Revision: 
#  Additional Comments: Note "|" (PIPE) chars will be read as x"00" in rom
# 
# --------------------------------------------------------------------------------

set systemTime [clock seconds]
set tm [clock format $systemTime -format {%Y-%m-%d:%H:%M:%S}]
set board [file tail [pwd]]

set svnv ""
set svnb ""

if {
    ![catch {exec svnversion .. } svnv] 
    && ![catch {exec svn info | sed -n -e 's/^Relative URL:\\s*\\(.*\\)/\\1/p'} svnb]
   } {
  set outdata "S:$svnv|$tm|$board|$svnb"
  set shortname "$svnv"

} else {
  # looks like this isn't an svn repo
  puts "Not in SVN, try git... $svnv $svnb"

  set gitv ""
  set gitb ""
  set gitul ""

  if {
    ![catch {exec git describe --always --dirty=M } gitv]
    && ![catch {exec git branch --show-current } gitb] 
    && ![catch {exec git config --get remote.origin.url } giturl]
    } {
    set outdata "G:$gitv|$tm|$board|$gitb:[regsub {\.git$} [regsub {github.com/?} [regsub {^https?://} $giturl ""] ""] "" ]"
    set shortname "$gitv"
  } else {
    puts "Not in GIT, just show build date $gitv $gitb"
    set outdata "UNVERSIONED $tm $board\\UNVERSIONED"
    set shortname {UNVERSIONED}
  }
}

if {[string length $outdata] > 126} {
  puts stderr "concatenated string is too long!"
  return error
}

set oftag [open "version.tag" w]
puts $oftag "$shortname"
close $oftag

set of [open "version.vhd" w]

puts $of "-- Automatically generated file (get-version.tcl) DO NOT EDIT!"
puts $of "-- $outdata {.}"
puts $of "library IEEE;"
puts $of "use IEEE.STD_LOGIC_1164.ALL;"
puts $of "use IEEE.NUMERIC_STD.ALL;"
puts $of "use IEEE.STD_LOGIC_MISC.ALL;"
puts $of "entity version_rom is port ("
puts $of " A : in std_logic_vector(6 downto 0);"
puts $of " Q : out std_logic_vector(7 downto 0)"
puts $of ");"
puts $of "end version_rom;"
puts $of "-- [regsub -all {(\r|\n)+} $outdata "\r\n-- "]"
puts $of "architecture rtl of version_rom is"
puts $of "begin"
puts $of "Q <="
for {set i 0} {$i < [string length $outdata] && $i < 256} {incr i} {
  set char [string index $outdata $i]
  if { $char == "|" } { set ascii 0 } else { scan $char %c ascii }
  set hx [format %02X $ascii]
  puts $of "   x\"$hx\" when unsigned(A) = $i else "
}

puts $of "   x\"00\";"

puts $of "end rtl;"

close $of