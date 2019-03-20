default: clean
	# https://github.com/machinebox/appify
	chmod +x main.tcl
	appify -name "tkslack" -icon slack.png main.tcl
clean:
	rm -rf *.app
