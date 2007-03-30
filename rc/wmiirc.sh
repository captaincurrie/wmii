#!/bin/sh
# Configure wmii
set -f

# Configuration Variables
MODKEY=Mod1
UP=k
DOWN=j
LEFT=h
RIGHT=l

# Colors tuples are "<text> <background> <border>"
WMII_NORMCOLORS='#222222 #5FBF77 #2A7F3F'
WMII_FOCUSCOLORS='#ffffff #153F1F #2A7F3F'
WMII_BACKGROUND='#333333'
WMII_FONT='-*-fixed-medium-r-normal-*-13-*-*-*-*-*-*-*'

set -- $(echo $WMII_NORMCOLORS $WMII_FOCUSCOLORS)

WMII_MENU="dmenu -b -fn $WMII_FONT -nf $1 -nb $2 -sf $4 -sb $5"
WMII_9MENU="wmii9menu -font $WMII_FONT -nf $1 -nb $2 -sf $4 -sb $5 -br $6"
WMII_TERM="xterm"

export WMII_MENU WMII_9MENU WMII_FONT WMII_TERM
export WMII_FOCUSCOLORS WMII_SELCOLORS WMII_NORMCOLORS

# Column Rules
wmiir write /colrules <<EOF
/.*/ -> 58+42
EOF

# Tagging Rules
wmiir write /tagrules <<EOF
/XMMS.*/ -> ~
/MPlayer.*/ -> ~
/.*/ -> !
/.*/ -> 1
EOF

# Event processing
# Status Bar Info
status() {
	echo -n $(uptime | sed 's/.*://; s/,//g') '|' $(date)
}

eventstuff() {
	cat <<'EOF'
# Events
Event Start
	case "$1" in
	wmiirc)
		exit;
	esac
Event Key
	fn=$(echo $@ | sed 's/[^a-zA-Z_0-9]/_/g')
	Key_$fn $@
Event CreateTag
	echo "$WMII_NORMCOLORS" "$@" | wmiir create "/lbar/$@"
Event DestroyTag
	wmiir remove "/lbar/$@"
Event FocusTag
	wmiir xwrite "/lbar/$@" "$WMII_FOCUSCOLORS" "$@"
Event UnfocusTag
	wmiir xwrite "/lbar/$@" "$WMII_NORMCOLORS" "$@"
Event UrgentTag
	shift
	wmiir xwrite "/lbar/$@" "*$@"
Event NotUrgentTag
	shift
	wmiir xwrite "/lbar/$@" "$@"
Event LeftBarClick
	shift
	wmiir xwrite /ctl view "$@"
# Actions
Action quit
	wmiir xwrite /ctl quit
Action rehash
	proglist $PATH >$PROGS_FILE
Action status
	set +xv
	if wmiir remove /rbar/status 2>/dev/null; then
		sleep 2
	fi
	echo "$WMII_NORMCOLORS" | wmiir create /rbar/status
	while status | wmiir write /rbar/status; do
		sleep 1
	done
Event ClientMouseDown
	client=$1; button=$2
	case "$button" in
	3)
		do=$($WMII_9MENU -initial "${menulast:-SomeRandomName}" Nop Delete)
		case "$do" in
		Delete)
			wmiir xwrite /client/$client/ctl kill
		esac
		menulast=${do:-"$menulast"}
	esac
EOF
	cat <<EOF
# Key Bindings
Key $MODKEY-Control-t
	case \$(wmiir read /keys | wc -l | tr -d ' \t\n') in
	0|1)
		echo -n \$Keys | tr ' ' '\012' | wmiir write /keys
		wmiir xwrite /ctl grabmod $MODKEY;;
	*)
		wmiir xwrite /keys $MODKEY-Control-t
		wmiir xwrite /ctl grabmod Mod3;;
	esac
Key $MODKEY-$LEFT
	wmiir xwrite /tag/sel/ctl select left
Key $MODKEY-$RIGHT
	wmiir xwrite /tag/sel/ctl select right
Key $MODKEY-$DOWN
	wmiir xwrite /tag/sel/ctl select down
Key $MODKEY-$UP
	wmiir xwrite /tag/sel/ctl select up
Key $MODKEY-space
	wmiir xwrite /tag/sel/ctl select toggle
Key $MODKEY-d
	wmiir xwrite /tag/sel/ctl colmode sel default
Key $MODKEY-s
	wmiir xwrite /tag/sel/ctl colmode sel stack
Key $MODKEY-m
	wmiir xwrite /tag/sel/ctl colmode sel max
Key $MODKEY-a
	Action \$(actionlist | \$WMII_MENU) &
Key $MODKEY-p
	sh -c "\$(\$WMII_MENU <\$PROGS_FILE)" &
Key $MODKEY-t
	wmiir xwrite /ctl "view \$(tagsmenu)" &
Key $MODKEY-Return
	$WMII_TERM &
Key $MODKEY-Shift-$LEFT
	wmiir xwrite /tag/sel/ctl send sel left
Key $MODKEY-Shift-$RIGHT
	wmiir xwrite /tag/sel/ctl send sel right
Key $MODKEY-Shift-$DOWN
	wmiir xwrite /tag/sel/ctl send sel down
Key $MODKEY-Shift-$UP
	wmiir xwrite /tag/sel/ctl send sel up
Key $MODKEY-Shift-space
	wmiir xwrite /tag/sel/ctl send sel toggle
Key $MODKEY-Shift-c
	wmiir xwrite /client/sel/ctl kill
Key $MODKEY-Shift-t
	wmiir xwrite "/client/\$(wmiir read /client/sel/ctl)/tags" "\$(tagsmenu)" &
EOF
	for i in 0 1 2 3 4 5 6 7 8 9; do
		cat << EOF
Key $MODKEY-$i
	wmiir xwrite /ctl view "$i"
Key $MODKEY-Shift-$i
	wmiir xwrite /client/sel/tags "$i"
EOF
	done
}

IFS=''
eval $(eventstuff | wmiiloop)
unset IFS

# Functions
proglist() {
	paths=$(echo "$@" | sed 'y/:/ /')
	ls -lL $paths 2>/dev/null |
		awk '$1 ~ /^[^d].*x/ { print $NF }' |
		sort | uniq
}

actionlist() {
	{
		proglist $WMII_CONFPATH
		echo -n $Actions | tr ' ' '\012'
	} | sort | uniq
}

tagsmenu() {
        wmiir ls /tag | sed "s|/||; /^sel$/d" | $WMII_MENU
}

conf_which() {
	prog=$(PATH="$WMII_CONFPATH:$PATH" which $1)
	shift
	if [ -n "$prog" ]; then
		$prog
	fi
}

Action() {
	action=$1; shift
	if [ -n "$action" ]; then
		Action_$action $@ || conf_which $action $@
	fi
}

# Misc
PROGS_FILE="$WMII_NS_DIR/.proglist"
Action status &
proglist $PATH >$PROGS_FILE &

xsetroot -solid "$WMII_BACKGROUND" &

# WM Configuration
wmiir write /ctl << EOF
font $WMII_FONT
focuscolors $WMII_FOCUSCOLORS
normcolors $WMII_NORMCOLORS
grabmod $MODKEY
border 1
EOF

# Setup Tag Bar
wmiir ls /lbar |
while read bar; do
	wmiir remove "/lbar/$bar"
done

seltag="$(wmiir read /tag/sel/ctl 2>/dev/null)"
wmiir ls /tag | sed -e 's|/||; /^sel$/d' |
while read tag; do
	if [ "X$tag" = "X$seltag" ]; then
		echo "$WMII_FOCUSCOLORS" "$tag" | wmiir create "/lbar/$tag" 
	else
		echo "$WMII_NORMCOLORS" "$tag" | wmiir create "/lbar/$tag"
	fi
done

# Stop any running instances of wmiirc
echo Start wmiirc | wmiir write /event || exit 1

wmiir read /event |
while read event; do
	set -- $event
	event=$1; shift
	Event_$event $@ 2>/dev/null
done