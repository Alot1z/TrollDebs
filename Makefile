TARGET_CODESIGN = $(shell which ldid)
TARGET_DPKG = 	  $(shell which dpkg)

APP_TMP         	= $(TMPDIR)/TrollDebs-build
APP_BUNDLE_PATH 	= $(APP_TMP)/Build/Products/Release-iphoneos/TrollDebs.app

all:
	xcodebuild -quiet -jobs $(shell sysctl -n hw.ncpu) -project 'TrollDebs.xcodeproj' -scheme TrollDebs -configuration Release -arch arm64 -sdk iphoneos -derivedDataPath $(APP_TMP) \
		CODE_SIGNING_ALLOWED=NO DSTROOT=$(APP_TMP)/install
		
	ldid -Sentitlements.plist $(APP_BUNDLE_PATH)/TrollDebs
	rm -rf build
	mkdir -p build/Payload

	mv $(APP_BUNDLE_PATH) 	build/Payload

	# make TrollStore tipa
	@ln -sf build/Payload Payload
	zip -r9 build/TrollDebsTrollStore.tipa Payload
	@rm -rf Payload

	# lol
	find . -name ".DS_Store" -delete
	@cp -r layout build
	@mkdir -p build/layout/Applications
	# make deb
	@cp -R build/Payload/TrollDebs.app build/layout/Applications/TrollDebs.app
	dpkg-deb --build build/layout
	@mv build/layout.deb build/TrollDebs.deb

	@rm -rf build/layout/Applications
	# rootless deb
	@mkdir -p build/layout/var/jb/Applications
	@mv build/Payload/TrollDebs.app build/layout/var/jb/Applications/TrollDebs.app
	dpkg-deb --build build/layout
	@mv build/layout.deb build/TrollDebsRootless.deb
	
	@rm -rf build/Payload
	@rm -rf build/layout

	@echo TrollStore .tipa written to build/TrollDebsTrollStore.tipa
	@echo Jailbroken .deb written to build/TrollDebs.deb
