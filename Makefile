NASM ?= nasm
CC ?= gcc
BUILD_DIR := build
BINARY := $(BUILD_DIR)/caine-asm
ASM_OBJECTS := $(BUILD_DIR)/main.o $(BUILD_DIR)/gateway.o $(BUILD_DIR)/commands.o
ADAPTER_OBJECTS := $(BUILD_DIR)/driver.o $(BUILD_DIR)/secure_transport.o
CFLAGS := -O2 -std=c11 -Wall -Wextra -Werror
CURL_CFLAGS := $(shell pkg-config --cflags libcurl)
CURL_LIBS := $(shell pkg-config --libs libcurl)
COMMAND_TEST := $(BUILD_DIR)/commands-vector

.PHONY: all clean inspect source-ratio test-commands

all: $(BINARY)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/main.o: src/main.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(BUILD_DIR)/gateway.o: src/gateway.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(BUILD_DIR)/commands.o: src/commands.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(BUILD_DIR)/driver.o: adapter/driver.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(CURL_CFLAGS) -c $< -o $@

$(BUILD_DIR)/secure_transport.o: adapter/secure_transport.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(CURL_CFLAGS) -c $< -o $@

$(BINARY): $(ASM_OBJECTS) $(ADAPTER_OBJECTS)
	$(CC) -no-pie -Wl,-z,noexecstack -o $@ $^ $(CURL_LIBS)

$(BUILD_DIR)/commands-vector.o: tests/commands_vector.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(COMMAND_TEST): $(BUILD_DIR)/commands-vector.o $(BUILD_DIR)/commands.o
	ld -static -z noexecstack -o $@ $^

test-commands: $(COMMAND_TEST)
	./$(COMMAND_TEST)

inspect: $(BINARY)
	file $(BINARY)
	ldd $(BINARY)

source-ratio:
	@asm=$$(find src -name '*.asm' -print0 | xargs -0 cat | wc -l); \
	c=$$(find adapter -name '*.c' -print0 | xargs -0 cat | wc -l); \
	total=$$((asm + c)); \
	printf 'NASM: %s lines (%.1f%%)\nC adapter: %s lines (%.1f%%)\n' $$asm "$$(awk "BEGIN {print 100 * $$asm / $$total}")" $$c "$$(awk "BEGIN {print 100 * $$c / $$total}")"

clean:
	rm -rf $(BUILD_DIR)
