# montgomery_minimal.xdc
# Minimal constraints for Montgomery multiplier on Alveo U250
# Only ports: clk, reset, start, done

# ------------------------------------------------------------------
# 1. Clock Constraint
# ------------------------------------------------------------------
create_clock -period 4.500 -name clk [get_ports clk]

# ------------------------------------------------------------------
# 2. Input Delays
# ------------------------------------------------------------------
set_input_delay -clock clk -min 1.000 [get_ports start]
set_input_delay -clock clk -max 2.000 [get_ports start]

# ------------------------------------------------------------------
# 3. Output Delays (only 'done' output - no 'result' port)
# ------------------------------------------------------------------
set_output_delay -clock clk -min 0.000 [get_ports done]
set_output_delay -clock clk -max 0.500 [get_ports done]

# ------------------------------------------------------------------
# 4. False/Async Paths
# ------------------------------------------------------------------
set_false_path -from [get_ports reset]

# ------------------------------------------------------------------
# 5. Optional: Input delay for reset (if it's synchronous)
#    Remove if reset is truly asynchronous
# ------------------------------------------------------------------
# set_input_delay -clock clk -min 1.000 [get_ports reset]
# set_input_delay -clock clk -max 2.000 [get_ports reset]
