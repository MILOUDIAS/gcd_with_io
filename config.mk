# ==============================================================================
# DESIGN CONFIGURATION FILE (config.mk)
# ==============================================================================
# This file tells the OpenROAD tool how to build your chip design.
# It specifies what files to use, what settings to apply, and how big the chip is.

# ------------------------------------------------------------------------------
# DESIGN IDENTIFICATION
# ------------------------------------------------------------------------------
# The full name of your top-level design module
export DESIGN_NAME = gcd_with_io

# A shorter nickname used in file paths (easier to type)
export DESIGN_NICKNAME = gcd2

# The manufacturing technology we're targeting
# ihp-sg13g2 = IHP's 130nm SiGe BiCMOS technology process
export PLATFORM = ihp-sg13g2

# ------------------------------------------------------------------------------
# SOURCE FILES
# ------------------------------------------------------------------------------
# List of Verilog files that describe your digital circuit
# The backslash (\) lets us split long lines for readability
# These files contain the actual hardware description code
# export VERILOG_FILES += $(DESIGN_HOME)/$(DESIGN_NICKNAME)/src/gcd_with_io.v \
#                         $(DESIGN_HOME)/$(DESIGN_NICKNAME)/src/gcd.v

export VERILOG_FILES += $(DESIGN_HOME)/$(PLATFORM)/$(DESIGN_NICKNAME)/src/gcd.v \
                        $(DESIGN_HOME)/$(PLATFORM)/$(DESIGN_NICKNAME)/src/gcd_with_io.v
# gcd_with_io.v = top level with I/O pads
# gcd.v = the core GCD algorithm logic

# ------------------------------------------------------------------------------
# TIMING CONSTRAINTS
# ------------------------------------------------------------------------------
# SDC file = Synopsys Design Constraints
# This file tells the tool how fast your circuit needs to run
# and what timing requirements the inputs/outputs must meet
export SDC_FILE = $(DESIGN_HOME)/$(PLATFORM)/$(DESIGN_NICKNAME)/constraint.sdc

# ------------------------------------------------------------------------------
# FILL CELLS
# ------------------------------------------------------------------------------
# USE_FILL = 1 means "add filler cells to empty spaces"
# Filler cells fill gaps between standard cells to ensure:
# - Continuous power rails
# - Proper well connections
# - Manufacturing requirements are met
export USE_FILL = 1

# ------------------------------------------------------------------------------
# POWER DISTRIBUTION NETWORK
# ------------------------------------------------------------------------------
# PDN_TCL points to the script that creates the power grid
# This grid delivers VDD (power) and VSS (ground) to all cells
export PDN_TCL = ${DESIGN_HOME}/${PLATFORM}/${DESIGN_NICKNAME}/pdn.tcl

# ------------------------------------------------------------------------------
# I/O PAD PLACEMENT
# ------------------------------------------------------------------------------
# FOOTPRINT_TCL defines where the I/O pads go around the chip edge
# I/O pads connect internal signals to the outside world (chip pins)
export FOOTPRINT_TCL = $(DESIGN_HOME)/$(PLATFORM)/$(DESIGN_NICKNAME)/pad.tcl

# ------------------------------------------------------------------------------
# PIN PLACEMENT SETTINGS
# ------------------------------------------------------------------------------
# For designs without I/O pads, this would control where pins go
# -hor_layers Metal3 = horizontal connections use Metal3
# -ver_layers Metal2 = vertical connections use Metal2
# (Not heavily used here since we have explicit I/O pads)
export PLACE_PINS_ARGS = -hor_layers Metal3 -ver_layers Metal2

# ------------------------------------------------------------------------------
# CELL PLACEMENT DENSITY
# ------------------------------------------------------------------------------
# PLACE_DENSITY = 0.88 means "use 88% of available space for cells"
# Leaving 12% empty gives room for:
# - Routing wires between cells
# - Buffer insertion for timing fixes
# - Design changes during optimization
# Higher density = less routing space, potentially harder to route
export PLACE_DENSITY ?= 0.3

# ------------------------------------------------------------------------------
# CHIP DIMENSIONS
# ------------------------------------------------------------------------------
# DIE_AREA defines the complete chip size (including I/O pads)
# Format: lower-left-x lower-left-y upper-right-x upper-right-y
# Units are micrometers (µm)
# This creates an 800µm x 800µm chip
export DIE_AREA = 0.0 0.0 800.0 800.0
# export DIE_AREA = 0.0 0.0 1000.0 1000.0

# CORE_AREA defines where standard cells can be placed
# This is the inner area, excluding the I/O pad ring
# This creates a 260µm x 260µm core (530-270 = 260 on each side)
export CORE_AREA = 270.0 270.0 530.0 530.0
# export CORE_AREA = 300.0 300.0 730.0 730.0

# ------------------------------------------------------------------------------
# ROUTING OPTIMIZATION
# ------------------------------------------------------------------------------
# GRT_THREADS = Global Routing uses 10 parallel threads
# Global routing plans the general path for each wire
# export GRT_THREADS = 10

# DRT_THREADS = Detailed Routing uses 10 parallel threads  
# Detailed routing assigns wires to specific metal tracks
# More threads = faster routing (if your computer has multiple cores)
# export DRT_THREADS = 10

# ------------------------------------------------------------------------------
# TIMING CLOSURE
# ------------------------------------------------------------------------------
# TNS_END_PERCENT = Total Negative Slack target
# 100 means "keep optimizing until timing is 100% met"
# TNS measures how much timing violations remain
export TNS_END_PERCENT = 100

