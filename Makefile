APP_NAME := Kipr
BUILD_DIR := build
APP_BUNDLE := $(BUILD_DIR)/$(APP_NAME).app
DEBUG_BINARY := .build/debug/$(APP_NAME)
RELEASE_BINARY := .build/release/$(APP_NAME)

.PHONY: build release bundle install run test clean

build:
	swift build

release:
	swift build -c release

bundle: build
	rm -rf "$(APP_BUNDLE)"
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS" "$(APP_BUNDLE)/Contents/Resources"
	cp "$(DEBUG_BINARY)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	cp Resources/Info.plist "$(APP_BUNDLE)/Contents/Info.plist"
	cp Resources/config.json "$(APP_BUNDLE)/Contents/Resources/config.json"
	codesign -s - --force "$(APP_BUNDLE)"

install: bundle
	-pkill -x $(APP_NAME)
	rm -rf "/Applications/$(APP_NAME).app"
	cp -R "$(APP_BUNDLE)" /Applications/

run: bundle
	open "$(APP_BUNDLE)"

test:
	swift run KiprTests

clean:
	swift package clean
	rm -rf "$(BUILD_DIR)"
