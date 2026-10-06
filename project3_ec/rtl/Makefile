# Build and simulate the FPGA demo with your processor.
#
#   make sim PROG=echo     build the software and run the testbench
#   make sim PROG=calc
#   make sim PROG=pong
#   make lint              elaborate the synthesisable design only
#   make clean
#
# Put your processor (hart.v and whatever it instantiates) in this directory,
# next to soc_core.v, then fill in the hart instantiation in soc_core.v.
#
# See https://ece552.wiscarch.org/project3_ec/ for the full walkthrough.

PROG    ?= echo
# One image does everything: it carries the RISC-V toolchain and Icarus Verilog.
IMAGE   ?= coderkalyan/ece552-tools:latest
SW_DIR  := ../sw

# Your files plus soc_core.v; the finished wrapper modules live in ip/.
SRC     := $(wildcard *.v)
IP      := $(wildcard ip/*.v)
IP_SYN  := $(filter-out ip/soc_tb.v,$(IP))

# On Linux, run as yourself rather than root, or everything the container writes
# is owned by root. Docker Desktop (Windows/macOS) maps ownership itself.
ifeq ($(shell uname -s 2>/dev/null),Linux)
  DOCKER_USER := --user $(shell id -u):$(shell id -g)
endif

# MSYS_NO_PATHCONV stops Git Bash rewriting container paths like /src
DOCKER  := MSYS_NO_PATHCONV=1 docker run --rm $(DOCKER_USER) -v "$(CURDIR)":/src -w /src $(IMAGE)

.PHONY: sim lint image clean help
.DEFAULT_GOAL := help

help:
	@echo "make sim PROG=<name>   build software + run the testbench"
	@echo "make lint              elaborate the synthesisable design"
	@echo "make clean             remove simulation artifacts"
	@echo
	@echo "programs: echo calc pong"
	@echo
	@echo "full walkthrough: https://ece552.wiscarch.org/project3_ec/"
	@echo
	@echo "your files here: $(SRC)"
	@if [ ! -f hart.v ]; then echo; echo "  !! hart.v not found -- copy your processor into this directory"; fi

image:
	@"$(MAKE)" -C $(SW_DIR) --no-print-directory PROGRAM=$(PROG) mem >/dev/null
	@cp $(SW_DIR)/build/$(PROG).mem program.mem

sim: image
	@$(DOCKER) bash -c '\
	  iverilog -g2005 -o soc_tb.out -s soc_tb $(SRC) $(IP) && \
	  vvp soc_tb.out +PROG=$(PROG)'

# Elaborates the board top level -- the same file set Quartus will synthesise.
# Catches a syntax error or a bad port name in seconds instead of twenty
# minutes into a compile.
lint:
	@$(DOCKER) iverilog -g2005 -o /dev/null -s de1soc_top $(SRC) $(IP_SYN)
	@echo "  lint ok"

clean:
	rm -f soc_tb.out program.mem *.vcd
