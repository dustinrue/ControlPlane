SWIFT       := swift
CONFIG      := debug
INSTALL_DIR := $(HOME)/.local/bin

# Per-arch build output directories (deterministic, no shell invocation needed)
BIN_ARM  := .build/arm64-apple-macosx/$(CONFIG)
BIN_X86  := .build/x86_64-apple-macosx/$(CONFIG)
UNIV_DIR := .build/universal/$(CONFIG)

# The app bundle is assembled from the universal binaries
APP_BUNDLE := $(UNIV_DIR)/ControlPlane.app
APP_BINARY := $(APP_BUNDLE)/Contents/MacOS/ControlPlane
INFO_PLIST := Resources/ControlPlane-Info.plist
ICON       := Resources/AppIcon.icns

.PHONY: all build install run clean

## Default: build universal binaries and install cpctl
all: build install

## Build for arm64 and x86_64, then lipo into universal binaries
build:
	$(SWIFT) build -c $(CONFIG) --arch arm64  --product ControlPlane --product cpctl
	$(SWIFT) build -c $(CONFIG) --arch x86_64 --product ControlPlane --product cpctl
	@mkdir -p $(UNIV_DIR)
	lipo -create $(BIN_ARM)/ControlPlane $(BIN_X86)/ControlPlane -output $(UNIV_DIR)/ControlPlane
	lipo -create $(BIN_ARM)/cpctl        $(BIN_X86)/cpctl        -output $(UNIV_DIR)/cpctl
	@echo "Universal binaries → $(UNIV_DIR)/"

## Install cpctl to $(INSTALL_DIR)
install: build
	@mkdir -p $(INSTALL_DIR)
	cp $(UNIV_DIR)/cpctl $(INSTALL_DIR)/cpctl
	codesign --force --sign - $(INSTALL_DIR)/cpctl
	@echo "Installed cpctl → $(INSTALL_DIR)/cpctl"

## Assemble the app bundle, sign it, register it with LaunchServices, and launch it
run: build install
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	cp $(INFO_PLIST) "$(APP_BUNDLE)/Contents/Info.plist"
	cp $(UNIV_DIR)/ControlPlane "$(APP_BINARY)"
	cp $(UNIV_DIR)/cpctl "$(APP_BUNDLE)/Contents/MacOS/cpctl"
	cp $(ICON) "$(APP_BUNDLE)/Contents/Resources/AppIcon.icns"
	codesign --force --deep --sign - --identifier "com.controlplane.app" "$(APP_BUNDLE)"
	/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
		-f "$(APP_BUNDLE)"
	-pkill -x ControlPlane 2>/dev/null; sleep 0.5
	open "$(APP_BUNDLE)"
	@echo "ControlPlane running from $(APP_BUNDLE)"

## Remove all build artifacts
clean:
	$(SWIFT) package clean
	rm -rf .build/universal
