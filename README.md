![Verilog](https://img.shields.io/badge/Verilog-hardware%20design-blue)
![Python](https://img.shields.io/badge/Python-software%20baseline-green)
![Hardware Security](https://img.shields.io/badge/Hardware-security-purple)
![Coursework](https://img.shields.io/badge/UTH-ECE455-teal)

# ECE455 Hardware Security: Montgomery Modular Multiplier Accelerator

A high-performance hardware accelerator for Montgomery modular exponentiation, designed from scratch in Verilog and synthesized for the Xilinx Alveo U250 FPGA. 

This project explores the architectural design, synthesis optimization, and cycle-level performance of cryptographic cores targeting large-integer modular arithmetic (512-bit, 1024-bit, and 2048-bit operands) typically used in RSA and Diffie-Hellman cryptographic systems.

## Architectures

The project evaluates two distinct hardware architectures:
* **Generic (Sequential):** Operates on 1024-bit operands by decomposing them into sixteen 64-bit words, scheduling multiplications sequentially over 274 clock cycles per Montgomery multiplication.
* **Ultra-Parallel:** Optimizes data-path parallelism by executing sixteen 64-bit word-level multiplications simultaneously in a single clock cycle, completing a full Montgomery multiplication in just 19 clock cycles. 

## Performance

The design was fully synthesized and implemented via Xilinx Vivado (targeting 222 MHz). When benchmarked against a software baseline (`software/cpu_benchmark.py`), the Ultra-Parallel FPGA architecture demonstrates massive acceleration due to structural parallelism:

* **1024-bit Moduli:** Up to 42.1x speedup over CPU.
* **2048-bit Moduli:** Up to 147.6x speedup over CPU.

*Note: The 1024-bit configuration was independently synthesized; 512-bit and 2048-bit performance metrics were analytically scaled from the 1024-bit post-implementation latency.*

## Repository Structure

* `RTL/`: Contains the Verilog source code for both the sequential and ultra-parallel Montgomery multiplier architectures.
* `software/`: Contains the Python baseline scripts (`cpu_benchmark.py`) used to extract software execution timings.
* `power_area/`: Contains Vivado post-implementation power and resource utilization reports.
* `Report_Project_Montgomery_Multiplier.pdf`: The full academic paper detailing the mathematical methodology, synthesis challenges, timing analysis, and architectural comparisons.

## Authors

* **Christos Mountakis** (cmountakis at uth dot gr)
* **Alexandra Tsakiri** (altsakiri at uth dot gr)
