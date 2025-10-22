// =============================================================================
// TOP-LEVEL MODULE WITH I/O PADS (gcd_with_io.v)
// =============================================================================
// This module is the complete chip including:
// - I/O pads (interface to external pins)
// - GCD core logic (the actual computation)
// - Signal routing between pads and core
//
// Think of this as the "complete chip" with its external packaging
// while gcd.v is just the internal logic

// Set timing precision for simulation
// 1ns = 1 nanosecond time unit (how we measure delays)
// 10ps = 10 picosecond precision (smallest time we can represent)
`timescale 1ns/10ps

module gcd_with_io (
    inout wire [7:0] pads    // Bidirectional pads (can be input or output)
);

    // =========================================================================
    // INTERNAL SIGNAL DECLARATIONS
    // =========================================================================
    // These are the actual digital signals inside the chip
    // The pads convert external voltages to these internal logic levels
    
    // --------------------------
    // Control signals
    // --------------------------
    wire clk_int;        // Internal clock signal from pad
    wire reset_int;      // Internal reset signal from pad
    wire req_val_int;    // Request valid - indicates input data is ready
    wire req_rdy_int;    // Request ready - indicates GCD is ready for input
    wire resp_val_int;   // Response valid - indicates output data is ready
    wire resp_rdy_int;   // Response ready - indicates external system can accept output
    
    // --------------------------
    // Data signals
    // --------------------------
    wire [31:0] req_msg_int;   // Request message - input data (32 bits)
    wire [15:0] resp_msg_int;  // Response message - output result (16 bits)

    // =========================================================================
    // I/O PAD INTERFACE SIGNALS
    // =========================================================================
    // These connect to the actual I/O pad cells
    
    wire [3:0] pad_in;   // Signals coming FROM pads INTO the chip
    wire [3:0] pad_out;  // Signals going FROM the chip OUT to pads

    // =========================================================================
    // INPUT SIGNAL MAPPING
    // =========================================================================
    // Connect pad inputs to internal signals
    // Each pad carries one bit, which we map to internal wires
    
    assign clk_int      = pad_in[0];  // Pad 0 = clock input
    assign reset_int    = pad_in[1];  // Pad 1 = reset input
    assign req_val_int  = pad_in[2];  // Pad 2 = request valid flag
    assign resp_rdy_int = pad_in[3];  // Pad 3 = response ready flag
    
    // --------------------------
    // INPUT DATA EXPANSION
    // --------------------------
    // We only have 4 input pads but need 32 bits of input data!
    // Solution: Replicate each input bit across multiple positions
    // This is a simplified interface - a real chip would need more I/O pads
    // or serial communication for 32-bit data
    
    // {8{pad_in[3]}} means "replicate pad_in[3] eight times"
    // So if pad_in[3]=1, this creates 8'b11111111
    assign req_msg_int[31:24] = {8{pad_in[3]}};  // Bits 31-24 = pad_in[3] repeated
    assign req_msg_int[23:16] = {8{pad_in[2]}};  // Bits 23-16 = pad_in[2] repeated
    assign req_msg_int[15:8]  = {8{pad_in[1]}};  // Bits 15-8  = pad_in[1] repeated
    assign req_msg_int[7:0]   = {8{pad_in[0]}};  // Bits 7-0   = pad_in[0] repeated
    
    // NOTE: This encoding scheme is just for demonstration
    // In a real design, you'd need 32 input pads for 32-bit data,
    // or use a serial protocol (SPI, I2C, etc.)

    // =========================================================================
    // OUTPUT SIGNAL MAPPING
    // =========================================================================
    // Connect internal signals to pad outputs
    
    assign pad_out[0] = req_rdy_int;        // Pad 4 = request ready flag
    assign pad_out[1] = resp_val_int;       // Pad 5 = response valid flag
    assign pad_out[2] = resp_msg_int[15];   // Pad 6 = MSB of result (bit 15)
    assign pad_out[3] = resp_msg_int[0];    // Pad 7 = LSB of result (bit 0)
    
    // We only output 2 bits of the 16-bit result (MSB and LSB)
    // Again, this is simplified - a real chip would need more output pads

    // =========================================================================
    // GCD CORE INSTANTIATION
    // =========================================================================
    // This is the actual GCD (Greatest Common Divisor) computation logic
    // It's in a separate module (gcd.v) that we instantiate here
    
    gcd gcd_core (
        .clk        (clk_int),        // Connect internal clock
        .reset      (reset_int),      // Connect internal reset
        .req_msg    (req_msg_int),    // Connect 32-bit input data
        .req_val    (req_val_int),    // Connect request valid flag
        .req_rdy    (req_rdy_int),    // Connect request ready flag
        .resp_msg   (resp_msg_int),   // Connect 16-bit output data
        .resp_val   (resp_val_int),   // Connect response valid flag
        .resp_rdy   (resp_rdy_int)    // Connect response ready flag
    );
    
    // The GCD core uses a handshaking protocol:
    // - req_val=1 means "I have input data"
    // - req_rdy=1 means "I can accept input data"
    // - resp_val=1 means "I have output data"
    // - resp_rdy=1 means "Please give me output data"

    // =========================================================================
    // INPUT PAD INSTANTIATION
    // =========================================================================
    // These are the physical I/O pad cells that connect to chip pins
    // sg13g2_IOPadIn = Input pad cell from the sg13g2 library
    
    // Pad 0: Clock input
    sg13g2_IOPadIn u_pad_0 (
        .pad(pads[0]),      // External connection (chip pin)
        .p2c(pad_in[0])     // Pad-to-core signal (internal wire)
    );
    
    // Pad 1: Reset input
    sg13g2_IOPadIn u_pad_1 (
        .pad(pads[1]), 
        .p2c(pad_in[1])
    );
    
    // Pad 2: Request valid input
    sg13g2_IOPadIn u_pad_2 (
        .pad(pads[2]), 
        .p2c(pad_in[2])
    );
    
    // Pad 3: Response ready input
    sg13g2_IOPadIn u_pad_3 (
        .pad(pads[3]), 
        .p2c(pad_in[3])
    );

    // =========================================================================
    // OUTPUT PAD INSTANTIATION
    // =========================================================================
    // sg13g2_IOPadOut16mA = Output pad with 16mA drive strength
    // Higher drive strength = can drive larger loads (more capacitance)
    
    // Pad 4: Request ready output
    sg13g2_IOPadOut16mA u_pad_4 (
        .c2p(pad_out[0]),   // Core-to-pad signal (internal wire)
        .pad(pads[4])       // External connection (chip pin)
    );
    
    // Pad 5: Response valid output
    sg13g2_IOPadOut16mA u_pad_5 (
        .c2p(pad_out[1]), 
        .pad(pads[5])
    );
    
    // Pad 6: Response message MSB output
    sg13g2_IOPadOut16mA u_pad_6 (
        .c2p(pad_out[2]), 
        .pad(pads[6])
    ); 
    
    // Pad 7: Response message LSB output
    sg13g2_IOPadOut16mA u_pad_7 (
        .c2p(pad_out[3]), 
        .pad(pads[7])
    ); 

    // =========================================================================
    // POWER PAD INSTANTIATION
    // =========================================================================
    // These pads supply power to the chip
    // (* keep *) prevents optimization from removing them (they have no logic connections)
    
    // VDD pad - supplies positive voltage (e.g., 1.2V) to core
    (* keep *)sg13g2_IOPadVdd   u_pad_vdd   ();
    
    // VSS pad - supplies ground (0V) to core
    (* keep *)sg13g2_IOPadVss   u_pad_vss   ();
    
    // IOVDD pad - supplies I/O voltage (often higher, e.g., 3.3V)
    // I/O pads need higher voltage to interface with external systems
    (* keep *)sg13g2_IOPadIOVdd u_pad_iovdd ();
    
    // IOVSS pad - supplies I/O ground
    (* keep *)sg13g2_IOPadIOVss u_pad_iovss ();
    
    // Power pads have no signal connections in Verilog
    // They connect to power nets (VDD, VSS, IOVDD, IOVSS) which are
    // defined in the PDN script (pdn.tcl)

endmodule

// =============================================================================
// CHIP ARCHITECTURE SUMMARY
// =============================================================================
//
// External View (Package):
// ┌─────────────────────────────────────┐
// │  Pin 0 (clk)      Pin 4 (req_rdy)   │
// │  Pin 1 (reset)    Pin 5 (resp_val)  │
// │  Pin 2 (req_val)  Pin 6 (resp[15])  │
// │  Pin 3 (resp_rdy) Pin 7 (resp[0])   │
// │  + Power pins (VDD, VSS, IOVDD, IOVSS) │
// └─────────────────────────────────────┘
//
// Internal View:
// ┌──────────────────────────────────────────┐
// │  I/O PAD RING                            │
// │  ┌────────────────────────────────────┐  │
// │  │  CORE AREA                         │  │
// │  │  ┌──────────────────────────────┐  │  │
// │  │  │  GCD Module                  │  │  │
// │  │  │  - Computes greatest common  │  │  │
// │  │  │    divisor using Euclidean   │  │  │
// │  │  │    algorithm                 │  │  │
// │  │  │  - Uses req/resp handshaking │  │  │
// │  │  └──────────────────────────────┘  │  │
// │  │                                     │  │
// │  │  Power Distribution Network (PDN)  │  │
// │  │  delivers power to all cells       │  │
// │  └────────────────────────────────────┘  │
// │                                          │
// │  Pads: Input, Output, Power              │
// └──────────────────────────────────────────┘
//
// Signal Flow:
// 1. External pins → Input pads → pad_in wires → Internal signals
// 2. Internal signals → GCD core (computation)
// 3. Internal signals → pad_out wires → Output pads → External pins
//
// =============================================================================