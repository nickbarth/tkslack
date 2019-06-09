# tkslack

A refined minimalist slacking experience for tcl connoisseurs.

### Dependencies

Requires Tcl/Tk 8.6.9

MacOS

```
brew install tcl-tk
```

Ubuntu

```
apt install tcl tk tcllib tcl-tls
```

### Run

First grab a token from https://api.slack.com/custom-integrations/legacy-tokens then do this:

```bash
wish <(curl -s https://raw.githubusercontent.com/nickbarth/tkslack/master/main.tcl)
```

![screenshot](https://raw.githubusercontent.com/nickbarth/tkslack/master/screenshot.png)

### Hotkeys 

<table>
  <tr>
    <td>⌘ k</td><td>Switch Channel</td>
  </tr>
  <tr>
    <td>Enter</td><td>Send Message</td>
  </tr>
</table>

### License
WTFPL &copy; 2019 Nick Barth
