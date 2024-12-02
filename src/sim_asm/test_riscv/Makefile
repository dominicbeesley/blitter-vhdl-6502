RISCV_GNU_TOOLCHAIN_INSTALL_PREFIX = /opt/riscv
TOOLCHAIN_PREFIX = $(RISCV_GNU_TOOLCHAIN_INSTALL_PREFIX)/bin/riscv32-unknown-elf-

#COMPRESSED_ISA=C
COMPRESSED_ISA=



BUILD=./build

X:=$(shell mkdir ./build)

all:$(BUILD)/test.rom

$(BUILD)/%.o:%.S
	$(TOOLCHAIN_PREFIX)gcc -c -Wa,-al -mabi=ilp32 -march=rv32im$(subst C,c,$(COMPRESSED_ISA)) -o $@ $<



$(BUILD)/test.elf: $(BUILD)/test.o sections.lds
	$(TOOLCHAIN_PREFIX)gcc -Os -mabi=ilp32 -march=rv32im$(subst C,c,$(COMPRESSED_ISA)) -ffreestanding -nostdlib -o $@ \
		-Wl,--build-id=none,-Bstatic,-T,sections.lds,-Map,$(BUILD)/test.map,--strip-debug \
		$(filter %.o,$^) -lgcc

$(BUILD)/test.rom: $(BUILD)/test.elf
	$(TOOLCHAIN_PREFIX)objcopy -O binary $< $@
