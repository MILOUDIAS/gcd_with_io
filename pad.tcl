# ==============================================================================
# I/O PAD PLACEMENT SCRIPT (pad.tcl)
# ==============================================================================
# This script places I/O pads around the perimeter of the chip.
# I/O pads are the interface between the chip's internal logic and external pins.
#
# Think of them as the "doors and windows" of your chip - they let signals
# in and out while protecting internal circuits from external electrical conditions.

puts "pad - I/O pad placement for gcd_with_io"

# ==============================================================================
# STEP 1: COLLECT ALL PAD INSTANCES
# ==============================================================================
# Find all the I/O pad cells that were instantiated in the Verilog code

# Search for cells matching these patterns:
# - ref_name ~ sg13g2_IOPad* = any pad cell from the sg13g2 library
# - name ~ u_pad_* = instance names starting with "u_pad_"
# -quiet flag = don't print warnings if nothing found
set pad_cells [get_cells -quiet -filter "ref_name=~sg13g2_IOPad* && name=~u_pad_*"]

# Check if we found any pads
if {[llength $pad_cells] == 0} {
    puts "ERROR: No I/O pads found (ref_name ~ sg13g2_IOPad*). Aborting."
    return
}

# ==============================================================================
# STEP 2: ORGANIZE PADS INTO LISTS
# ==============================================================================
# Convert pad cells into a sorted list of names
set pad_names {}
foreach p $pad_cells { 
    lappend pad_names [get_name $p]  
}
# Sort alphabetically for consistent ordering
set pad_names [lsort $pad_names]  

# Separate power pads from signal pads
# Power pads (VDD, VSS, IOVDD, IOVSS) need special handling
set power_pads {}
set signal_pads {}
# Convert to lowercase for easier matching
foreach n $pad_names {
    set nl [string tolower $n]  
    
    # Check if the name contains power/ground keywords
    if {[string match *vdd* $nl] || [string match *vss* $nl] || 
        [string match *iovdd* $nl] || [string match *iovss* $nl]} {
        lappend power_pads $n
    } else {
        lappend signal_pads $n
    }
}

# Place power pads first (they're more critical), then signal pads
set pad_list [concat $power_pads $signal_pads]

# Count and report what we found
set n_pads [llength $pad_list]
puts "Found $n_pads I/O pads to place (Power: [llength $power_pads], Signal: [llength $signal_pads])."

# ==============================================================================
# STEP 3: DEFINE GEOMETRIC CONSTANTS
# ==============================================================================
# These values define the physical dimensions of pad-related structures
# All values are in micrometers (µm)
# Length of each I/O pad cell (180µm)
set IO_LENGTH 180        
# Width of each I/O pad cell (80µm)
set IO_WIDTH 80          
#Size of the bond pad (where wire bonds attach)
set BONDPAD_SIZE 70      
# Space for seal ring (protects chip from moisture/contaminants)
set SEALRING_OFFSET 20   

# Visual layout:
# ┌─────────────────────────────────┐
# │  Bond Pad Area (70µm)           │
# │  ┌───────────────────────────┐  │
# │  │ Seal Ring (20µm offset)   │  │
# │  │  ┌─────────────────────┐  │  │
# │  │  │ I/O Pad (180µm)     │  │  │
# │  │  │                     │  │  │
# │  │  └─────────────────────┘  │  │
# │  └───────────────────────────┘  │
# └─────────────────────────────────┘

# ==============================================================================
# STEP 4: PAD LOCATION CALCULATION PROCEDURES
# ==============================================================================
# These functions calculate where each pad should be placed along a chip edge

# ------------------------------------------------------------------------------
# HORIZONTAL PAD PLACEMENT (Top and Bottom edges)
# ------------------------------------------------------------------------------
proc calc_horizontal_pad_location { index total IO_LENGTH IO_WIDTH BONDPAD_SIZE SEALRING_OFFSET } {
    # Calculate the width of the die (chip)
    set DIE_WIDTH [expr { [lindex $::env(DIE_AREA) 2] - [lindex $::env(DIE_AREA) 0] }]
    
    # PAD_OFFSET = distance from chip edge to where pads start
    # This accounts for bond pad area, seal ring, and I/O pad length
    set PAD_OFFSET [expr { $IO_LENGTH + $BONDPAD_SIZE + $SEALRING_OFFSET }]
    
    # PAD_AREA_WIDTH = available space for placing pads horizontally
    # Subtract offsets from both left and right sides
    set PAD_AREA_WIDTH [expr { $DIE_WIDTH - ($PAD_OFFSET * 2) }]
    
    # HORIZONTAL_PAD_DISTANCE = spacing between adjacent pads
    # Divide available space by number of pads, then subtract pad width
    set HORIZONTAL_PAD_DISTANCE [expr { ($PAD_AREA_WIDTH / $total) - $IO_WIDTH }]
    
    # Calculate X coordinate for this specific pad (indexed from 0)
    # Start at PAD_OFFSET, then add (width + spacing) for each previous pad,
    # then add half the spacing to center the pad in its slot
    return [expr { $PAD_OFFSET + (($IO_WIDTH + $HORIZONTAL_PAD_DISTANCE) * $index) + ($HORIZONTAL_PAD_DISTANCE / 2) }]
}

# ------------------------------------------------------------------------------
# VERTICAL PAD PLACEMENT (Left and Right edges)
# ------------------------------------------------------------------------------
proc calc_vertical_pad_location { index total IO_LENGTH IO_WIDTH BONDPAD_SIZE SEALRING_OFFSET } {
    # Same logic as horizontal, but for the vertical dimension
    set DIE_HEIGHT [expr { [lindex $::env(DIE_AREA) 3] - [lindex $::env(DIE_AREA) 1] }]
    set PAD_OFFSET [expr { $IO_LENGTH + $BONDPAD_SIZE + $SEALRING_OFFSET }]
    set PAD_AREA_HEIGHT [expr { $DIE_HEIGHT - ($PAD_OFFSET * 2) }]
    set VERTICAL_PAD_DISTANCE [expr { ($PAD_AREA_HEIGHT / $total) - $IO_WIDTH}]
    
    # Calculate Y coordinate for this specific pad
    return [expr { $PAD_OFFSET + (($IO_WIDTH + $VERTICAL_PAD_DISTANCE) * $index) + ($VERTICAL_PAD_DISTANCE / 2) }]
}

# ==============================================================================
# STEP 5: CREATE I/O SITES
# ==============================================================================
# "Sites" are placement locations for I/O cells
# Think of them as parking spaces where pads can be placed

set IO_OFFSET [expr { $BONDPAD_SIZE + $SEALRING_OFFSET }]

# Create a fake site for regular I/O pads (on sides)
# Width = 1µm (very thin, allows flexible placement)
# Height = 180µm (matches IO_LENGTH)
make_fake_io_site -name IOLibSite -width 1 -height $IO_LENGTH

# Create a fake site for corner I/O pads
# Width = Height = 180µm (square corners)
make_fake_io_site -name IOLibCSite -width $IO_LENGTH -height $IO_LENGTH

# Create rows of sites around all four edges
# -horizontal_site = site type for top and bottom edges
# -vertical_site = site type for left and right edges  
# -corner_site = site type for the four corners
# -offset = how far from chip edge to start placing sites
make_io_sites \
  -horizontal_site IOLibSite \
  -vertical_site IOLibSite \
  -corner_site IOLibCSite \
  -offset $IO_OFFSET

# ==============================================================================
# STEP 6: PLACE PADS AROUND THE CHIP PERIMETER
# ==============================================================================
# We'll distribute pads evenly around four sides: South, East, North, West
# This design uses 3 pads per side (12 total including power pads)
# Counter to track which pad we're placing
set pad_idx 0  
puts "\nPlacing pads with calculated coordinates..."

# ------------------------------------------------------------------------------
# SOUTH SIDE (Bottom edge) - 3 pads
# ------------------------------------------------------------------------------
# Number of pads on this side
set n_side 3  
for {set i 0} {$i < $n_side && $pad_idx < $n_pads} {incr i} {
# Get next pad from our list
    set pad_name [lindex $pad_list $pad_idx]  
    
    # Place the pad in the IO_SOUTH row at calculated X position
    place_pad -row IO_SOUTH \
              -location [calc_horizontal_pad_location $i $n_side $IO_LENGTH $IO_WIDTH $BONDPAD_SIZE $SEALRING_OFFSET] \
              $pad_name
# Move to next pad
    incr pad_idx  
}

# ------------------------------------------------------------------------------
# EAST SIDE (Right edge) - 3 pads
# ------------------------------------------------------------------------------
set n_side 3
for {set i 0} {$i < $n_side && $pad_idx < $n_pads} {incr i} {
    set pad_name [lindex $pad_list $pad_idx]
    
    # Place pad in IO_EAST row at calculated Y position
    place_pad -row IO_EAST \
              -location [calc_vertical_pad_location $i $n_side $IO_LENGTH $IO_WIDTH $BONDPAD_SIZE $SEALRING_OFFSET] \
              $pad_name
    
    incr pad_idx
}

# ------------------------------------------------------------------------------
# NORTH SIDE (Top edge) - 3 pads
# ------------------------------------------------------------------------------
set n_side 3
for {set i 0} {$i < $n_side && $pad_idx < $n_pads} {incr i} {
    set pad_name [lindex $pad_list $pad_idx]
    
    place_pad -row IO_NORTH \
              -location [calc_horizontal_pad_location $i $n_side $IO_LENGTH $IO_WIDTH $BONDPAD_SIZE $SEALRING_OFFSET] \
              $pad_name
    
    incr pad_idx
}

# ------------------------------------------------------------------------------
# WEST SIDE (Left edge) - 3 pads
# ------------------------------------------------------------------------------
set n_side 3
for {set i 0} {$i < $n_side && $pad_idx < $n_pads} {incr i} {
    set pad_name [lindex $pad_list $pad_idx]
    
    place_pad -row IO_WEST \
              -location [calc_vertical_pad_location $i $n_side $IO_LENGTH $IO_WIDTH $BONDPAD_SIZE $SEALRING_OFFSET] \
              $pad_name
    
    incr pad_idx
}

# ------------------------------------------------------------------------------
# VERIFY ALL PADS WERE PLACED
# ------------------------------------------------------------------------------
puts "\nPLACEMENT SUMMARY"
puts "   Total pads: $n_pads | Placed: $pad_idx"
if {$pad_idx == $n_pads} {
    puts "All pads placed successfully."
} else {
    puts "Error: Not all pads were placed."
}

# ==============================================================================
# STEP 7: PLACE CORNERS, FILLERS, AND BONDPADS
# ==============================================================================
puts "\nPlacing corner, filler, and bondpad cells..."

# ------------------------------------------------------------------------------
# CORNER CELLS
# ------------------------------------------------------------------------------
# Special cells go in the four corners to:
# - Complete the seal ring
# - Provide proper well connections
# - Meet manufacturing design rules
place_corners sg13g2_Corner

# ------------------------------------------------------------------------------
# FILLER CELLS
# ------------------------------------------------------------------------------
# Filler cells fill gaps between I/O pads
# Different sizes let us fill any gap efficiently (like having coins of different denominations)
set iofill {
    sg13g2_Filler10000   
    sg13g2_Filler4000    
    sg13g2_Filler2000    
    sg13g2_Filler1000   
    sg13g2_Filler400     
    sg13g2_Filler200     
}

# Why fillers are important:
# 1. Continuous power rails between pads
# 2. Complete the seal ring
# 3. Meet minimum density rules
# 4. Provide proper substrate/well connections

# Place fillers on all four sides
foreach side {IO_NORTH IO_SOUTH IO_WEST IO_EAST} {
    place_io_fill -row $side {*}$iofill
}

# ------------------------------------------------------------------------------
# BONDPADS
# ------------------------------------------------------------------------------
# Bondpads are the metal squares where wire bonds attach
# They connect the chip to package pins
# 
# -bond bondpad_70x70 = use 70µm x 70µm bondpad
# [get_cells -quiet u_pad_*] = apply to all pad instances
# -offset {5.0 -70.0} = place bondpad 5µm right, 70µm down from pad center
place_bondpad -bond bondpad_70x70 [get_cells -quiet u_pad_*] -offset {5.0 -70.0}

# ------------------------------------------------------------------------------
# CONNECT BY ABUTMENT
# ------------------------------------------------------------------------------
# "Abutment" means placing cells directly next to each other
# This command connects power/ground rails between adjacent pads automatically
# No routing needed - the metal layers align and touch
connect_by_abutment

# ------------------------------------------------------------------------------
# CLEANUP
# ------------------------------------------------------------------------------
# Remove the temporary I/O site rows (we don't need them anymore)
# The pads are now fixed in place
remove_io_rows

puts "\npad placement finished for gcd_with_io "

# ==============================================================================
# FINAL PAD RING STRUCTURE
# ==============================================================================
# After this script, the chip looks like this (top view):
#
#        NORTH (3 pads)
#    ┌─────────────────────┐
#    │ Corner              │
#  W │        CORE         │ E
#  E │       (logic)       │ A
#  S │                     │ S
#  T │   260µm x 260µm     │ T
#    │                     │
#  3 │                     │ 3
#    │                     │
#  p │                     │ p
#  a │                     │ a
#  d │                     │ d
#  s │                     │ s
#    │                     │
#    │ Corner        Corner│
#    └─────────────────────┘
#        SOUTH (3 pads)
#
# Total chip: 800µm x 800µm
# Core area: 530µm x 530µm (starting at 270µm, 270µm)
#
# Each side has:
# - 3 signal/power pads
# - Filler cells between pads
# - Corner cells at intersections
# - Bondpads on top of each pad
# ==============================================================================