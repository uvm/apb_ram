CC              = gcc
CFLAGS		= -Wall -O3 -fPIC
SEED            = 1

DFLAGS = -relocation-model=pic -w -O3

LDC2BINDIR = $(dir $(shell which ldc2))
VLBINDIR = $(dir $(shell which verilator))
VERBOSITY = NONE

.PHONY: all clean

all: apb_ram

clean:
	rm -rf apb_ram* euvm_dir obj_dir link_verilator

run: apb_ram
	./apb_ram +UVM_TESTNAME=apb_ram.random_test +UVM_VERBOSITY=$(VERBOSITY) +random_seed=$(SEED) # +UVM_OBJECTION_TRACE

obj_dir/DVapb_ram.a: ../rtl/apb_ram.v
	verilator --no-timing --threads 1 --trace-fst --cc --euvm $^
	make -C obj_dir -f DVapb_ram.mk DVapb_ram.a

apb_ram: ../testbench/apb_ram.d ../testbench/apb/*.d obj_dir/DVapb_ram.a
	ldc2 $(DFLAGS) -Ieuvm_dir -link-defaultlib-shared -of$@ -L-luvm-ldc-shared -L-lesdl-ldc-shared \
		-L-lphobos2-ldc-shared -L-ldl $^ -L-lstdc++

