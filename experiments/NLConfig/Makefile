# NLConfig build helper.
# The system `swift` may be the CLI tools (too old for swift-tools-version 6.2).
# This Makefile uses `xcrun swift` which resolves through the active Xcode toolchain.
# Switch toolchains with: sudo xcode-select --switch /Applications/Xcode.app

SWIFT := xcrun swift

.PHONY: build run clean

build:
	$(SWIFT) build

run:
	$(SWIFT) run NLConfig

clean:
	$(SWIFT) package clean
