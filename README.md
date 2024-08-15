
## Notes

This is how I have it set up on my MacBook.

The below is the content of my `~/Library/LaunchAgents/is.bep.dns.plist` file. I have a `nogo.db` file in `~/config/nogo` and the `nogo` binary in `~/go/bin`. You obviously need to change the paths to your liking.

```xml
<!DOCTYPE plist PUBLIC -//Apple Computer//DTD PLIST 1.0//EN http://www.apple.com/DTDs/PropertyList-1.0.dtd >
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>com.is.dns</string>
   	<key>ProgramArguments</key>
	    <array>
	    <string>/Users/bep/go/bin/nogo</string>
		<string>-web-addr</string>
		<string>:8123</string>
		<string>-dns-proxyto</string>
		<string>1.1.1.1:53,8.8.8.8:53,8.8.4.4:53</string>
		<string>-db</string>
		<string>/Users/bep/config/nogo/nogo.db</string>
	    </array>
    <key>KeepAlive</key>
    <true/>
	<key>RunAtLoad</key>
	<true/>
<key>StandardOutPath</key>
<string>/var/log/nogo.log</string>
<key>StandardErrorPath</key>
<string>/var/log/nogo.log</string>
</dict>
</plist>
```

