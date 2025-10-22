# ==============================================================================
#                 Power Delivery Network (PDN) Generation Script
#
# Purpose: This script automatically creates the metal grid (or mesh) that
#          distributes power (VDD) and ground (VSS) across an integrated
#          circuit design. A well-designed PDN is critical for ensuring
#          the chip operates reliably without significant voltage drops (IR drop).
# Tool:    OpenROAD
# Language: Tcl (Tool Command Language)
# ==============================================================================

puts "=== Starting PDN Generation ==="

# ------------------------------------------------------------------------------
# SECTION 1: CONFIGURATION
#
# Description: This section defines all the key parameters for the power grid.
#              It's designed to be easily configurable by either modifying the
#              default values here or by setting environment variables before
#              running the script. This allows for flexible and reusable code.
# ------------------------------------------------------------------------------

# Set the names for the primary power and ground nets. These variables will be
# used throughout the script to refer to these important nets.
set vdd_net "VDD"
set gnd_net "VSS"

# This section sets up the geometric parameters for the PDN grid.
# Each parameter can be overridden by setting an environment variable.
# If the environment variable exists, its value is used; otherwise, the default value is used.
# This makes the script highly customizable for different technologies or designs
# without needing to edit the script file itself.

# Metal layer for vertical power stripes
if {[info exists ::env(FP_PDN_VERTICAL_LAYER)]} {
    set v_layer $::env(FP_PDN_VERTICAL_LAYER)
} else {
    set v_layer "Metal4"
}

# Metal layer for horizontal power stripes
if {[info exists ::env(FP_PDN_HORIZONTAL_LAYER)]} {
    set h_layer $::env(FP_PDN_HORIZONTAL_LAYER)
} else {
    set h_layer "Metal5"
}

# Metal layer for rails that power the standard cells
if {[info exists ::env(FP_PDN_RAIL_LAYER)]} {
    set rail_layer $::env(FP_PDN_RAIL_LAYER)
} else {
    set rail_layer "Metal1"
}

# The width of the Metal1 power rails (in microns)
if {[info exists ::env(FP_PDN_RAIL_WIDTH)]} {
    set rail_width $::env(FP_PDN_RAIL_WIDTH)
} else {
    set rail_width "0.28"
}

# The center-to-center distance between vertical stripes (in microns)
if {[info exists ::env(FP_PDN_VPITCH)]} {
    set vpitch $::env(FP_PDN_VPITCH)
} else {
    set vpitch "80"
}

# The center-to-center distance between horizontal stripes (in microns)
if {[info exists ::env(FP_PDN_HPITCH)]} {
    set hpitch $::env(FP_PDN_HPITCH)
} else {
    set hpitch "80"
}

# The width of the vertical stripes on v_layer (in microns)
if {[info exists ::env(FP_PDN_VWIDTH)]} {
    set vwidth $::env(FP_PDN_VWIDTH)
} else {
    set vwidth "1.6"
}

# The width of the horizontal stripes on h_layer (in microns)
if {[info exists ::env(FP_PDN_HWIDTH)]} {
    set hwidth $::env(FP_PDN_HWIDTH)
} else {
    set hwidth "1.6"
}

# Define the offset (in microns) from the edge of the core logic area to the
# inner edge of the power ring.
set core_ring_offset 10.0

# Get a handle to the design database. This object, '$db_block', represents the
# current state of the chip design and is used to make modifications.
set db_block [ord::get_db_block]

# ------------------------------------------------------------------------------
# SECTION 2: ENSURE CORE_AREA IS DEFINED
#
# Description: The power grid is built within the core area of the chip. This
#              section acts as a safeguard. If the user hasn't explicitly
#              defined a core area, it defaults to using the entire chip's
#              (die) area to prevent errors.
# ------------------------------------------------------------------------------
if {![info exists ::env(CORE_AREA)]} {
    set die_area [$db_block getDieArea]
    set ::env(CORE_AREA) [list \
        [expr {[$die_area xMin] / 1000.0}] \
        [expr {[$die_area yMin] / 1000.0}] \
        [expr {[$die_area xMax] / 1000.0}] \
        [expr {[$die_area yMax] / 1000.0}] \
    ]
    puts "WARNING: ::env(CORE_AREA) not set. Using die area: $::env(CORE_AREA)"
}

# ------------------------------------------------------------------------------
# SECTION 3: CREATE POWER NETS
#
# Description: Before we can add metal shapes for our power grid, the logical
#              nets (e.g., VDD, VSS) must exist in the design database. This
#              procedure checks for their existence and creates them if they
#              are missing.
# ------------------------------------------------------------------------------

# Define a reusable procedure (function) to create a net if it's not already in the design.
proc ensure_net_exists {db_block netName sigType} {
    set db_net [$db_block findNet $netName]
    if {$db_net eq "" || $db_net eq "NULL"} {
        set db_net [odb::dbNet_create $db_block $netName]
        $db_net setSpecial
        $db_net setSigType $sigType
        puts "Created net $netName ($sigType)"
    }
    return $db_net
}

# Call the procedure to ensure the core power and I/O (Input/Output) power nets exist.
ensure_net_exists $db_block $vdd_net "POWER"
ensure_net_exists $db_block $gnd_net "GROUND"
ensure_net_exists $db_block "IOVDD"  "POWER"
ensure_net_exists $db_block "IOVSS"  "GROUND"

# ------------------------------------------------------------------------------
# SECTION 4: DEFINE AND BUILD THE PDN GRID
#
# Description: This is the main part of the script where the physical metal
#              structures of the power grid are defined and added to the design.
#              It involves creating a plan (grid), adding a ring, power rails
#              for cells, and a mesh of power stripes.
# ------------------------------------------------------------------------------

# Define a "voltage domain" which associates the logical power/ground nets
# with a name, 'CORE'. This helps organize designs with multiple power supplies.
set_voltage_domain -name CORE -power $vdd_net -ground $gnd_net

# Initialize a new PDN grid plan named 'core_grid'. All subsequent 'add_pdn_*'
# commands will add geometry to this plan.
define_pdn_grid -name core_grid -voltage_domains CORE

# Add a power ring around the perimeter of the core area. This ring acts as a
# primary power source for the internal grid.
add_pdn_ring -grid core_grid \
             -layers [list $v_layer $h_layer] \
             -widths [list 2.0 2.0] \
             -spacings [list 2.0 2.0] \
             -core_offsets [list $core_ring_offset $core_ring_offset]

puts "Creating Metal1 power rails using -followpins..."

# The '-followpins' option is a powerful feature that instructs the tool to
# create these rails directly on top of the VDD/VSS pins of the standard cell rows,
# ensuring every cell has direct access to power.
add_pdn_stripe -grid core_grid \
               -layer $rail_layer \
               -width $rail_width \
               -followpins

puts "  -> Created Metal1 power rails on $rail_layer using -followpins"

# Add vertical stripes using the parameters defined in the configuration section.
# This creates the main grid that distributes power from the ring to the rails.
add_pdn_stripe -grid core_grid \
               -layer $v_layer \
               -width $vwidth \
               -pitch $vpitch \
               -offset 0

# Add horizontal stripes, creating a mesh where they cross the vertical ones.
add_pdn_stripe -grid core_grid \
               -layer $h_layer \
               -width $hwidth \
               -pitch $hpitch \
               -offset 0

# A grid of disconnected metal lines is useless. This step adds vias (vertical
# connections) wherever the different metal layers of our grid intersect.

# Connect the lowest level (Metal1 rails) to the first level of the mesh (vertical stripes).
add_pdn_connect -grid core_grid -layers [list $rail_layer $v_layer]

# Connect the vertical and horizontal mesh layers.
add_pdn_connect -grid core_grid -layers [list $v_layer $h_layer]

puts "Connected $rail_layer <-> $v_layer <-> $h_layer"

# ------------------------------------------------------------------------------
# SECTION 5: GLOBAL CONNECTIONS
#
# Description: At this point, we have created the physical metal shapes for the
#              power grid. However, the design tool doesn't yet know that a
#              cell's VDD pin should be logically connected to the VDD grid.
#              This section establishes those logical connections.
# ------------------------------------------------------------------------------
puts "Setting up global connections..."

# The 'add_global_connection' command defines a rule. The 'global_connect'
# command at the end will apply all these rules simultaneously.

# Rule for Standard Cells: Connect any pin named VDD, VPWR, or VPB to the VDD net.
# The pattern uses regular expressions: '^' means start of string, '$' means end.
add_global_connection -net $vdd_net -pin_pattern {^(VDD|VPWR|VPB)$} -power
add_global_connection -net $gnd_net -pin_pattern {^(VSS|VGND|VNB)$} -ground

# Rule for I/O Pads: I/O pads can have complex naming. This loop iterates through
# common instance name patterns for I/O cells and connects their various power pins.
foreach pattern {".*u_pad_.*" ".*IOPad.*" "sg13g2_IOPad.*"} {
    add_global_connection -net $vdd_net -inst_pattern $pattern -pin_pattern {^(VDD|vdd)$} -power
    add_global_connection -net $gnd_net -inst_pattern $pattern -pin_pattern {^(VSS|vss)$} -ground
    add_global_connection -net "IOVDD"  -inst_pattern $pattern -pin_pattern {^(IOVDD|iovdd)$} -power
    add_global_connection -net "IOVSS"  -inst_pattern $pattern -pin_pattern {^(IOVSS|iovss)$} -ground
}

# Rule for dedicated Power Pads: Connects any pin on instances matching specific patterns
# directly to the corresponding power net. We use a wildcard pin pattern to match all pins.
add_global_connection -net $vdd_net -inst_pattern ".*u_pad_vdd.*" -pin_pattern ".*"
add_global_connection -net $gnd_net -inst_pattern ".*u_pad_vss.*" -pin_pattern ".*"
add_global_connection -net "IOVDD"  -inst_pattern ".*u_pad_iovdd.*" -pin_pattern ".*"
add_global_connection -net "IOVSS"  -inst_pattern ".*u_pad_iovss.*" -pin_pattern ".*"

# Fallback Rule: As a final catch-all, connect any pin with "VDD" or "VSS" in its
# name to the appropriate net. This helps catch unusually named pins.
add_global_connection -net $vdd_net -pin_pattern ".*VDD.*" -power
add_global_connection -net $gnd_net -pin_pattern ".*VSS.*" -ground

# This command executes all the 'add_global_connection' rules defined above,
# creating the final logical connections in the design database.
global_connect
puts "Global connections applied"

puts "=== PDN generation completed successfully ==="

# ==============================================================================
