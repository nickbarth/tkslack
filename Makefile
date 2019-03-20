default: clean
	# https://github.com/machinebox/appify
	chmod +x main.tcl
	appify -name "tkslack" -icon slack.png main.tcl
	zip -r tkslack-mac.zip tkslack.app
	openssl sha256 tkslack-mac.zip
clean:
	rm -rf *.app
	rm -rf *.zip
