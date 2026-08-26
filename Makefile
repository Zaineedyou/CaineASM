NASM ?= nasm
CC ?= gcc
BUILD_DIR := build
BINARY := $(BUILD_DIR)/caine-asm
ASM_OBJECTS := $(BUILD_DIR)/main.o $(BUILD_DIR)/gateway.o $(BUILD_DIR)/commands.o $(BUILD_DIR)/json.o $(BUILD_DIR)/discord_rest.o $(BUILD_DIR)/groq.o $(BUILD_DIR)/dispatch.o $(BUILD_DIR)/state_view.o $(BUILD_DIR)/guild_config.o $(BUILD_DIR)/guild_policy.o $(BUILD_DIR)/guild_auth.o $(BUILD_DIR)/lifecycle.o $(BUILD_DIR)/warnings.o $(BUILD_DIR)/history.o $(BUILD_DIR)/ai_rate_limit.o $(BUILD_DIR)/base64.o $(BUILD_DIR)/attachment_fetch.o $(BUILD_DIR)/attachment_parser.o $(BUILD_DIR)/vision_payload.o $(BUILD_DIR)/store.o $(BUILD_DIR)/afk.o $(BUILD_DIR)/xp.o $(BUILD_DIR)/persist.o
ADAPTER_OBJECTS := $(BUILD_DIR)/driver.o $(BUILD_DIR)/secure_transport.o
CFLAGS := -O2 -std=c11 -Wall -Wextra -Werror
CURL_CFLAGS := $(shell pkg-config --cflags libcurl)
CURL_LIBS := $(shell pkg-config --libs libcurl)
COMMAND_TEST := $(BUILD_DIR)/commands-vector
STORE_AFK_TEST := $(BUILD_DIR)/store-afk-vector
REST_TEST := $(BUILD_DIR)/discord-rest-vector
JSON_TEST := $(BUILD_DIR)/json-vector
DISPATCH_TEST := $(BUILD_DIR)/dispatch-vector
GATEWAY_TEST := $(BUILD_DIR)/gateway-vector
GROQ_TEST := $(BUILD_DIR)/groq-vector
XP_TEST := $(BUILD_DIR)/xp-vector
PERSIST_TEST := $(BUILD_DIR)/persist-vector
STATE_REPLAY_TEST := $(BUILD_DIR)/state-replay-vector
STATE_VIEW_TEST := $(BUILD_DIR)/state-view-vector
GUILD_CONFIG_TEST := $(BUILD_DIR)/guild-config-vector
GUILD_POLICY_TEST := $(BUILD_DIR)/guild-policy-vector
GUILD_AUTH_TEST := $(BUILD_DIR)/guild-auth-vector
LIFECYCLE_TEST := $(BUILD_DIR)/lifecycle-vector
WARNINGS_TEST := $(BUILD_DIR)/warnings-vector
HISTORY_TEST := $(BUILD_DIR)/history-vector
AI_RATE_LIMIT_TEST := $(BUILD_DIR)/ai-rate-limit-vector
BASE64_TEST := $(BUILD_DIR)/base64-vector
ATTACHMENT_FETCH_TEST := $(BUILD_DIR)/attachment-fetch-vector
ATTACHMENT_PARSER_TEST := $(BUILD_DIR)/attachment-parser-vector
VISION_PAYLOAD_TEST := $(BUILD_DIR)/vision-payload-vector

.PHONY: all clean inspect source-ratio test-commands test-store-afk test-rest test-json test-dispatch test-gateway test-groq test-xp test-persist test-state-replay test-state-view test-guild-config test-guild-policy test-guild-auth test-lifecycle test-warnings test-history test-ai-rate-limit test-base64 test-attachment-fetch test-attachment-parser test-vision-payload test

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

$(BUILD_DIR)/groq.o: src/groq.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(BUILD_DIR)/dispatch.o: src/dispatch.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(BUILD_DIR)/state_view.o: src/state_view.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(BUILD_DIR)/guild_config.o: src/guild_config.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(BUILD_DIR)/guild_policy.o: src/guild_policy.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(BUILD_DIR)/guild_auth.o: src/guild_auth.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(BUILD_DIR)/lifecycle.o: src/lifecycle.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(BUILD_DIR)/warnings.o: src/warnings.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(BUILD_DIR)/history.o: src/history.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(BUILD_DIR)/ai_rate_limit.o: src/ai_rate_limit.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(BUILD_DIR)/base64.o: src/base64.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(BUILD_DIR)/attachment_fetch.o: src/attachment_fetch.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(BUILD_DIR)/attachment_parser.o: src/attachment_parser.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(BUILD_DIR)/vision_payload.o: src/vision_payload.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(BUILD_DIR)/store.o: src/store.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(BUILD_DIR)/afk.o: src/afk.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(BUILD_DIR)/xp.o: src/xp.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(BUILD_DIR)/persist.o: src/persist.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(BUILD_DIR)/driver.o: adapter/driver.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(CURL_CFLAGS) -c $< -o $@

$(BUILD_DIR)/secure_transport.o: adapter/secure_transport.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(CURL_CFLAGS) -c $< -o $@

$(BINARY): $(ASM_OBJECTS) $(ADAPTER_OBJECTS)
	$(CC) -no-pie -Wl,-z,relro,-z,now,-z,noexecstack -o $@ $^ $(CURL_LIBS)

$(BUILD_DIR)/commands-vector.o: tests/commands_vector.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(COMMAND_TEST): $(BUILD_DIR)/commands-vector.o $(BUILD_DIR)/commands.o
	ld -static -z noexecstack -o $@ $^

test-commands: $(COMMAND_TEST)
	./$(COMMAND_TEST)

$(BUILD_DIR)/store-afk-vector.o: tests/store_afk_vector.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(STORE_AFK_TEST): $(BUILD_DIR)/store-afk-vector.o $(BUILD_DIR)/store.o $(BUILD_DIR)/afk.o $(BUILD_DIR)/persist.o
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

$(BUILD_DIR)/dispatch-vector.o: tests/dispatch_vector.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(DISPATCH_TEST): $(BUILD_DIR)/dispatch-vector.o $(BUILD_DIR)/dispatch.o $(BUILD_DIR)/commands.o $(BUILD_DIR)/json.o
	ld -static -z noexecstack -o $@ $^

test-dispatch: $(DISPATCH_TEST)
	./$(DISPATCH_TEST)

$(BUILD_DIR)/gateway-vector.o: tests/gateway_vector.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(GATEWAY_TEST): $(BUILD_DIR)/gateway-vector.o $(BUILD_DIR)/gateway.o $(BUILD_DIR)/json.o
	ld -static -z noexecstack -o $@ $^

test-gateway: $(GATEWAY_TEST)
	./$(GATEWAY_TEST)

$(BUILD_DIR)/groq-vector.o: tests/groq_vector.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(GROQ_TEST): $(BUILD_DIR)/groq-vector.o $(BUILD_DIR)/groq.o $(BUILD_DIR)/vision_payload.o $(BUILD_DIR)/json.o $(BUILD_DIR)/history.o
	ld -static -z noexecstack -o $@ $^

test-groq: $(GROQ_TEST)
	./$(GROQ_TEST)

$(BUILD_DIR)/xp-vector.o: tests/xp_vector.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(XP_TEST): $(BUILD_DIR)/xp-vector.o $(BUILD_DIR)/xp.o $(BUILD_DIR)/store.o $(BUILD_DIR)/persist.o
	ld -static -z noexecstack -o $@ $^

test-xp: $(XP_TEST)
	./$(XP_TEST)

$(BUILD_DIR)/persist-vector.o: tests/persist_vector.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(PERSIST_TEST): $(BUILD_DIR)/persist-vector.o $(BUILD_DIR)/persist.o
	ld -static -z noexecstack -o $@ $^

test-persist: $(PERSIST_TEST)
	./$(PERSIST_TEST)

$(BUILD_DIR)/state-replay-vector.o: tests/state_replay_vector.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(STATE_REPLAY_TEST): $(BUILD_DIR)/state-replay-vector.o $(BUILD_DIR)/persist.o $(BUILD_DIR)/store.o $(BUILD_DIR)/afk.o $(BUILD_DIR)/xp.o
	ld -static -z noexecstack -o $@ $^

test-state-replay: $(STATE_REPLAY_TEST)
	./$(STATE_REPLAY_TEST)

$(BUILD_DIR)/state-view-vector.o: tests/state_view_vector.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(STATE_VIEW_TEST): $(BUILD_DIR)/state-view-vector.o $(BUILD_DIR)/state_view.o $(BUILD_DIR)/store.o $(BUILD_DIR)/persist.o
	ld -static -z noexecstack -o $@ $^

test-state-view: $(STATE_VIEW_TEST)
	./$(STATE_VIEW_TEST)

$(BUILD_DIR)/guild-config-vector.o: tests/guild_config_vector.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(GUILD_CONFIG_TEST): $(BUILD_DIR)/guild-config-vector.o $(BUILD_DIR)/guild_config.o $(BUILD_DIR)/store.o $(BUILD_DIR)/persist.o
	ld -static -z noexecstack -o $@ $^

test-guild-config: $(GUILD_CONFIG_TEST)
	./$(GUILD_CONFIG_TEST)

$(BUILD_DIR)/guild-policy-vector.o: tests/guild_policy_vector.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(GUILD_POLICY_TEST): $(BUILD_DIR)/guild-policy-vector.o $(BUILD_DIR)/guild_policy.o $(BUILD_DIR)/store.o $(BUILD_DIR)/persist.o
	ld -static -z noexecstack -o $@ $^

test-guild-policy: $(GUILD_POLICY_TEST)
	./$(GUILD_POLICY_TEST)

$(BUILD_DIR)/guild-auth-vector.o: tests/guild_auth_vector.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(GUILD_AUTH_TEST): $(BUILD_DIR)/guild-auth-vector.o $(BUILD_DIR)/guild_auth.o $(BUILD_DIR)/json.o
	ld -static -z noexecstack -o $@ $^

test-guild-auth: $(GUILD_AUTH_TEST)
	./$(GUILD_AUTH_TEST)

$(BUILD_DIR)/lifecycle-vector.o: tests/lifecycle_vector.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(LIFECYCLE_TEST): $(BUILD_DIR)/lifecycle-vector.o $(BUILD_DIR)/lifecycle.o $(BUILD_DIR)/json.o
	ld -static -z noexecstack -o $@ $^

test-lifecycle: $(LIFECYCLE_TEST)
	./$(LIFECYCLE_TEST)

$(BUILD_DIR)/warnings-vector.o: tests/warnings_vector.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(WARNINGS_TEST): $(BUILD_DIR)/warnings-vector.o $(BUILD_DIR)/warnings.o $(BUILD_DIR)/store.o $(BUILD_DIR)/persist.o
	ld -static -z noexecstack -o $@ $^

test-warnings: $(WARNINGS_TEST)
	./$(WARNINGS_TEST)

$(BUILD_DIR)/history-vector.o: tests/history_vector.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(HISTORY_TEST): $(BUILD_DIR)/history-vector.o $(BUILD_DIR)/history.o
	ld -static -z noexecstack -o $@ $^

test-history: $(HISTORY_TEST)
	./$(HISTORY_TEST)

$(BUILD_DIR)/ai-rate-limit-vector.o: tests/ai_rate_limit_vector.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(AI_RATE_LIMIT_TEST): $(BUILD_DIR)/ai-rate-limit-vector.o $(BUILD_DIR)/ai_rate_limit.o
	ld -static -z noexecstack -o $@ $^

test-ai-rate-limit: $(AI_RATE_LIMIT_TEST)
	./$(AI_RATE_LIMIT_TEST)

$(BUILD_DIR)/base64-vector.o: tests/base64_vector.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(BASE64_TEST): $(BUILD_DIR)/base64-vector.o $(BUILD_DIR)/base64.o
	ld -static -z noexecstack -o $@ $^

test-base64: $(BASE64_TEST)
	./$(BASE64_TEST)

$(BUILD_DIR)/attachment-fetch-vector.o: tests/attachment_fetch_vector.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(ATTACHMENT_FETCH_TEST): $(BUILD_DIR)/attachment-fetch-vector.o $(BUILD_DIR)/attachment_fetch.o
	ld -static -z noexecstack -o $@ $^

test-attachment-fetch: $(ATTACHMENT_FETCH_TEST)
	./$(ATTACHMENT_FETCH_TEST)

$(BUILD_DIR)/attachment-parser-vector.o: tests/attachment_parser_vector.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(ATTACHMENT_PARSER_TEST): $(BUILD_DIR)/attachment-parser-vector.o $(BUILD_DIR)/attachment_parser.o $(BUILD_DIR)/json.o
	ld -static -z noexecstack -o $@ $^

test-attachment-parser: $(ATTACHMENT_PARSER_TEST)
	./$(ATTACHMENT_PARSER_TEST)

$(BUILD_DIR)/vision-payload-vector.o: tests/vision_payload_vector.asm | $(BUILD_DIR)
	$(NASM) -f elf64 -g -F dwarf $< -o $@

$(VISION_PAYLOAD_TEST): $(BUILD_DIR)/vision-payload-vector.o $(BUILD_DIR)/vision_payload.o $(BUILD_DIR)/json.o
	ld -static -z noexecstack -o $@ $^

test-vision-payload: $(VISION_PAYLOAD_TEST)
	./$(VISION_PAYLOAD_TEST)

test: test-commands test-store-afk test-rest test-json test-dispatch test-gateway test-groq test-xp test-persist test-state-replay test-state-view test-guild-config test-guild-policy test-guild-auth test-lifecycle test-warnings test-history test-ai-rate-limit test-base64 test-attachment-fetch test-attachment-parser test-vision-payload

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
