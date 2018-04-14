BOARD:=tf534
BUSSOURCES="../rtl/bus_top.v  ../rtl/m6800.v ../rtl/ata.v"
RAMSOURCES="../rtl/ram_top.v ../rtl/fastram.v ../rtl/gayle.v ../rtl/zxmmc.v ../rtl/autoconfig.v"

all: tf534r2
tf534r2: clean tf534r2_ram tf534r2_bus
tf534r2_ram:
	make -f Makefile.cpld BOARD=tf534 SOURCES=$(RAMSOURCES) SUBPROJ=ram REVISION=rev2 OPTMODE=speed OPTIMISE=speed
tf534r2_bus:
	make -f Makefile.cpld BOARD=tf534 SOURCES=$(BUSSOURCES) SUBPROJ=bus REVISION=rev2 OPTMODE=speed OPTIMISE=speed
clean:	
	rm -rf work _xmsgs
distclean: clean
	rm -f *.jed *~ *.svf
