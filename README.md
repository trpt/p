# p
password-store wrapper with encrypted directory tree support  
shares some code from passmenu and possibly other scripts :)

# Config and encrypt existing database
You can find and edit config variables insdie the script. Basically you only need to edit PASSWORD_STORE_KEY variable if other settings were default ones. Other config entries are self-explanatory I hope. You can name this script whatever you want. Also it is probably a good idea to put in PATH and even bind keyboard shortcuts to actions.

Empty encrypted database is created if there is no such at ENCRYPTED_FILENAME path (check source). 

If you have existing pass tree, you should  
1. Create empty encrypted db  
2. Open it with `open` action  
3. Copy contents of existing one to `/dev/shm/{db_name}`  
4. Close it (encrypt back) with `close` action  

Then check config and usage of this wrapper with  
`p -h`

# Usage  
`p action`

where `action` is:  
`backup`, `b` - backup existing encrypted database  
`open`, `o` - decrypt database and extract it to $PASS_HOME_UNPACKED  
`close`, `c` - encrypt database at $PASS_HOME_UNPACKED and save it to $ENCRYPTED_FILENAME  
`dmenu`, `d` - use dmenu to list, choose password and copy it to clipboard  
`rofi`, `r` - use rofi to list, choose password and copy it to clipboard  
`gen`, `g` - generate pass using zenity as prompt for new entry

dmenu or rofi action parameters:  
`--type`, `-t`, `t` - use xdotool to autotype password  
`--show`, `-s`, `s` - use zenity to show content  
`--edit`, `-e`, `e` - edit chosen entry with $EDITOR  
`--del`,  `-d`, `d` - delete entry without warning  

# Examples:  
`p backup`  
`p dmenu`  
`p rofi --type`  
`p d -e`  
`p r s`

# Additional dependencies  
rofi or dmenu  
zenity  
xdotool  
some other basic commandline tools

# Additional notes
Wrapper may have some limitations. Particularly in git and other advanced functions, as I never used it.

Tested in Arch Linux
