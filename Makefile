# To compile additional files, add them to the TESTBENCH or SIMFILES as needed
# Every .vg file will need its own rule and one or more synthesis scripts
# The information contained here (in the rules for those vg files) will be
# similar to the information in those scripts but that seems hard to avoid.
#

# added "SW_VCS=2011.03 and "-full64" option -- awdeorio fall 2011
# added "-sverilog" and "SW_VCS=2012.09" option,
#	and removed deprecated Virsim references -- jbbeau fall 2013
# updated library path name -- jbbeau fall 2013

VCS = SW_VCS=2017.12-SP2-1 vcs +v2k -sverilog +vc -Mupdate -line -full64
LIB = ./library/NanGate_15nm_OCL_conditional.v

all:    simv
	./simv | tee program.out
#####
# Modify starting here
#####

TESTBENCH = HDL/PU_test.sv
SIMFILES = HDL/sys_defs.svh HDL/accumulator.sv HDL/delta_down_counter.sv HDL/index_down_counter.sv HDL/shifter.sv HDL/multiplier.sv HDL/output_buffer.sv HDL/processing_element.sv HDL/processing_unit.sv
SYNFILES = outputs/processing_unit.vg
SCRIPT = scripts/script.tcl
SYN_OUTPUT = logs/synth.log

$(SYNFILES):	$(SCRIPT)
	dc_shell-t -f $(SCRIPT) | tee $(SYN_OUTPUT)

#####
# Should be no need to modify after here
#####
sim:	simv $(ASSEMBLED)
	./simv | tee sim_program.out

simv:	$(HEADERS) $(SIMFILES) $(TESTBENCH)
	$(VCS) $^ -o simv

.PHONY: sim


# updated interactive debugger "DVE", using the latest version of VCS
# awdeorio fall 2011
dve:	$(SIMFILES) $(TESTBENCH)
	$(VCS) +memcbk $(TESTBENCH) $(SIMFILES) -o dve -R -gui

syn_simv:	$(SYNFILES) $(TESTBENCH)
	$(VCS) $(TESTBENCH) $(SYNFILES) $(LIB) -o syn_simv

syn:	syn_simv
	./syn_simv | tee syn_program.out

clean:
	rm -rvf simv *.daidir csrc vcs.key program.out \
	  syn_simv syn_simv.daidir syn_program.out \
          dve *.vpd *.vcd *.dump ucli.key *.log *.svf

nuke:	clean
	rm -rvf *.vg *.rep *.db *.chk *.log *.out *.ddc *.svf DVEfiles/ reports/* outputs/*

.PHONY: dve clean nuke
