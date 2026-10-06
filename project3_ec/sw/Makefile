# Build a C demo program into program.mem for the FPGA wrapper.
#
#   make PROGRAM=pong mem      build, check, and emit build/program.mem
#   make PROGRAM=pong disasm   show the disassembly
#   make all                   build every program
#   make clean
#
# The cross-toolchain runs in a container so the flow is identical on Windows,
# macOS and the CAE machines. This is the same image the course's assembly tests
# use, so you already have it.
#
# Full walkthrough: https://ece552.wiscarch.org/project3_ec/

PROGRAM   ?= echo
IMAGE     ?= coderkalyan/ece552-tools:latest
MEM_BYTES ?= 4096

PROGRAMS  := echo calc pong

CROSS   := riscv64-unknown-elf-
CFLAGS  := -march=rv32i -mabi=ilp32 -Os \
           -nostdlib -ffreestanding -fno-builtin \
           -msmall-data-limit=0 -fno-tree-loop-distribute-patterns \
           -Wall -Wextra -Werror
LDFLAGS := -T link.ld -Wl,-Map,build/$(PROGRAM).map

# On Linux, run as yourself rather than root, or everything the container writes
# is owned by root. Docker Desktop (Windows/macOS) maps ownership itself.
ifeq ($(shell uname -s 2>/dev/null),Linux)
  DOCKER_USER := --user $(shell id -u):$(shell id -g)
endif

# MSYS_NO_PATHCONV stops Git Bash rewriting container paths like /src
DOCKER  := MSYS_NO_PATHCONV=1 docker run --rm $(DOCKER_USER) -v "$(CURDIR)":/src -w /src $(IMAGE)

.PHONY: all mem disasm clean help
.DEFAULT_GOAL := help

help:
	@echo "make PROGRAM=<name> mem      compile, link, flatten, convert -> build/program.mem"
	@echo "make PROGRAM=<name> disasm   show the disassembly"
	@echo "make all                     build every program"
	@echo "make clean                   remove build/"
	@echo
	@echo "programs: $(PROGRAMS)"
	@echo "e.g.      make PROGRAM=pong mem"

build/$(PROGRAM).elf: $(PROGRAM).c crt0.S link.ld
	@mkdir -p build
	$(DOCKER) $(CROSS)gcc $(CFLAGS) $(LDFLAGS) crt0.S $(PROGRAM).c -o $@

mem: build/$(PROGRAM).elf
	@$(DOCKER) bash -c 'set -e; \
	  $(CROSS)objdump -d build/$(PROGRAM).elf > build/$(PROGRAM).dis; \
	  $(CROSS)objdump -h build/$(PROGRAM).elf > build/$(PROGRAM).sec; \
	  $(CROSS)objcopy -O binary --pad-to=$(MEM_BYTES) --gap-fill=0 \
	      build/$(PROGRAM).elf build/$(PROGRAM).bin; \
	  od -An -v -tx4 -w4 build/$(PROGRAM).bin | sed "s/^ //" > build/$(PROGRAM).mem'
	@$(DOCKER) python3 tools/isa_check.py $(PROGRAM) build/$(PROGRAM).dis build/$(PROGRAM).sec \
	    --max-bytes $(MEM_BYTES)
	@cp build/$(PROGRAM).mem build/program.mem
	@echo "      ->  build/program.mem"

disasm: build/$(PROGRAM).elf
	@$(DOCKER) $(CROSS)objdump -d $<

all:
	@for p in $(PROGRAMS); do "$(MAKE)" --no-print-directory PROGRAM=$$p mem || exit 1; done

clean:
	rm -rf build
