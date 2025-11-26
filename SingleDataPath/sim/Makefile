# === QuestaSim Windows path ===
QUESTA_PATH=/mnt/c/questasim64_10.2c/win64
VLIB=$(QUESTA_PATH)/vlib.exe
VMAP=$(QUESTA_PATH)/vmap.exe
VLOG=$(QUESTA_PATH)/vlog.exe
VSIM=$(QUESTA_PATH)/vsim.exe

# === Simulation settings ===
TB_NAME    ?= test_bench
TESTNAME   ?= simlog
RADIX      ?= hex

# === Targets ===
all: build run

all_wave: build run wave

build:
	$(VLIB) work
	$(VMAP) work work
	$(VLOG) -f compile.f | tee compile.log

run:
	$(VSIM) -debugDB -l $(TESTNAME).log -voptargs=+acc -assertdebug -c $(TB_NAME) -do "log -r /*; run -all;"

wave:
	$(VSIM) -i -view vsim.wlf -do "add wave vsim:/$(TB_NAME)/*; radix -$(RADIX)" &

clean:
	rm -rf work
	rm -rf vsim.dbg
	rm -rf *.ini
	rm -rf *.log
	rm -rf *.wlf
	rm -rf transcript

help:
	@echo "***************************************"
	@echo "** make clean : clean all compiled data"
	@echo "** make build : build the design"
	@echo "** make run   : run simulation"
	@echo "** make all   : build and run simulation"
	@echo "** make wave  : open waveform"
	@echo "***************************************"

