SOURCE := draft-tlmk-infra-dnssd.md
IMAGE := ghcr.io/ietf-tools/ietf-at:1.2.3

BUILD_DIR := build
HTML := $(BUILD_DIR)/$(SOURCE:.md=.html)
TXT  := $(BUILD_DIR)/$(SOURCE:.md=.txt)

.PHONY: all clean

all: $(HTML) $(TXT)

$(HTML) $(TXT): $(BUILD_DIR)/$(SOURCE)
	docker run --rm -v "$(CURDIR)/$(BUILD_DIR):/rfc" -w /rfc \
		$(IMAGE) \
		kdrfc --html --txt $(SOURCE) \
		2>&1 | tee $(BUILD_DIR)/build.log

$(BUILD_DIR)/$(SOURCE): $(SOURCE) | $(BUILD_DIR)
	cp $< $@

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

clean:
	rm -rf $(BUILD_DIR)
