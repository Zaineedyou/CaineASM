NASM ?= nasm
CC ?= gcc
BUILD_DIR := build
BINARY := $(BUILD_DIR)/caine-asm
ASM_OBJECTS := $(BUILD_DIR)/main.o $(BUILD_DIR)/gateway.o $(BUILD_DIR)/commands.o $(BUILD_DIR)/json.o $(BUILD_DIR)/discord_rest.o $(BUILD_DIR)/store.o $(BUILD_DIR)/afk.o
ADAPTER_OBJECTS := $(BUILD_DIR)/driver.o $(BUILD_DIR)/secure_transport.o
CFLAGS := -O2 -std=c11 -Wall -Wextra -Werror
CURL_CFLAGS := $(shell pkg-config --cflags libcurl)
CURL_LIBS := $(shell pkg-config --libs libcurl)
COMMAND_TEST := $(BUILD_DIR)/commands-vector
STORE_AFK_TEST := $(BUILD_DIR)/store-afk-vector
REST_TEST := $(BUILD_DIR)/discord-rest-vector
JSON_TEST := $(BUILD_DIR)/json-vector

.PHONY: all clean inspect source-ratio test-commands test-store-afk test-rest test-json test

all: $(BINARY)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/main.o: src/main.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(BUILD_DIR)/gateway.o: src/gateway.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(BUILD_DIR)/commands.o: src/commands.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(BUILD_DIR)/json.o: src/json.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(BUILD_DIR)/discord_rest.o: src/discord_rest.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(BUILD_DIR)/store.o: src/store.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(BUILD_DIR)/afk.o: src/afk.asm | $(BUILD_DIR)
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

$(BUILD_DIR)/store-afk-vector.o: tests/store_afk_vector.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(STORE_AFK_TEST): $(BUILD_DIR)/store-afk-vector.o $(BUILD_DIR)/store.o $(BUILD_DIR)/afk.o
	ld -static -z noexecstack -o $@ $^

test-store-afk: $(STORE_AFK_TEST)
	./$(STORE_AFK_TEST)

$(BUILD_DIR)/discord-rest-vector.o: tests/discord_rest_vector.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(REST_TEST): $(BUILD_DIR)/discord-rest-vector.o $(BUILD_DIR)/discord_rest.o $(BUILD_DIR)/json.o
	ld -static -z noexecstack -o $@ $^

test-rest: $(REST_TEST)
	./$(REST_TEST)

$(BUILD_DIR)/json-vector.o: tests/json_vector.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(JSON_TEST): $(BUILD_DIR)/json-vector.o $(BUILD_DIR)/json.o
	ld -static -z noexecstack -o $@ $^

test-json: $(JSON_TEST)
	./$(JSON_TEST)

test: test-commands test-store-afk test-rest test-json

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
