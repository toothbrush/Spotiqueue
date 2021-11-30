# This is adapted from https://github.com/exelban/stats/blob/master/Makefile

APP = Spotiqueue
BUNDLE_ID = com.rustlingbroccoli.Spotiqueue

TEAM_ID := $(shell security find-certificate -c "Developer ID Application:" | grep "alis" | awk 'NF { print $$NF }' | tr -d \(\)\")

BUILD_PATH = $(PWD)/build
APP_PATH = "$(BUILD_PATH)/$(APP).app"
ZIP_PATH = "$(BUILD_PATH)/$(APP).zip"

AC_USERNAME := $(shell pass spotiqueue-itc-signing | grep email | awk '{print $$2}')
export AC_PASSWORD := $(shell pass spotiqueue-itc-signing | grep app-specific-pass | awk '{print $$2}')

.PHONY: build
build: archive notarize sign make-zip

# --- MAIN WORKFLOW FUNCTIONS --- #

.PHONY: archive
archive: clean
	@echo "Exporting application archive..."

	xcodebuild \
		-scheme $(APP) \
		-destination 'generic/platform=OS X' \
		-configuration Release archive \
		-archivePath $(BUILD_PATH)/$(APP).xcarchive

	@echo "Application built, starting the export archive..."

	xcodebuild -exportArchive \
		-exportOptionsPlist "$(PWD)/ExportOptions.plist" \
		-archivePath $(BUILD_PATH)/$(APP).xcarchive \
		-exportPath $(BUILD_PATH)

	ditto -c -k --keepParent $(APP_PATH) $(ZIP_PATH)

	@echo "Project archived successfully"

.PHONY: notarize
notarize:
	@echo "Submitting app for notarization..."

	xcrun altool --notarize-app \
	  --primary-bundle-id $(BUNDLE_ID) \
	  --team-id $(TEAM_ID) \
	  -u $(AC_USERNAME) \
	  -p @env:AC_PASSWORD \
	  --file $(ZIP_PATH)

	@echo "Application sent to the notarization center"

	sleep 30s

.PHONY: sign
sign:
	@echo "Checking if package is approved by Apple..."

	@while true; do \
		if [[ "$$(xcrun altool --notarization-history 0 --team-id ${TEAM_ID} -u $(AC_USERNAME) -p @env:AC_PASSWORD | sed -n '6p')" == *"success"* ]]; then \
			echo "OK" ;\
			break ;\
		fi ;\
		echo "Package was not approved by Apple, recheck in 10s..."; \
		sleep 10s ;\
	done

	@echo "Going to staple an application..."

	xcrun stapler staple $(APP_PATH)
	spctl -a -t exec -vvv $(APP_PATH)

	@echo "Spotiqueue successfully stapled"

.PHONY: make-zip
make-zip: VERSION = $(shell /usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$(APP_PATH)/Contents/Info.plist")
make-zip: sign
	ditto -c -k --keepParent $(APP_PATH) $(ZIP_PATH)
	cp -v $(ZIP_PATH) updates/Spotiqueue-v$(VERSION).zip
	~/Downloads/Sparkle-1.27.1/bin/generate_appcast updates/

.PHONY: prepare-dSYM
prepare-dSYM:
	@echo "Zipping dSYMs..."
	cd $(BUILD_PATH)/Spotiqueue.xcarchive/dSYMs && zip -r $(PWD)/dSYMs.zip .
	@echo "Created zip with dSYMs"

# --- HELPERS --- #

.PHONY: clean
clean:
	rm -rf $(BUILD_PATH)
	if [ -a $(PWD)/dSYMs.zip ]; then rm $(PWD)/dSYMs.zip; fi;
	if [ -a $(PWD)/Spotiqueue.dmg ]; then rm $(PWD)/Spotiqueue.dmg; fi;

.PHONY: next-version
next-version:
	versionNumber=$$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$(PWD)/Spotiqueue/Info.plist") ;\
	@echo "Actual version is: $$versionNumber" ;\
	versionNumber=$$((versionNumber + 1)) ;\
	@echo "Next version is: $$versionNumber" ;\
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $$versionNumber" "$(PWD)/Spotiqueue/Info.plist" ;\

.PHONY: history
history:
	xcrun altool --notarization-history 0 \
		--team-id ${TEAM_ID} \
		-u $(AC_USERNAME) \
		-p @env:AC_PASSWORD
