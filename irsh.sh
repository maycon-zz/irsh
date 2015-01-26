#!/usr/bin/bash

# Network infos
[[ -z $IRC_HOST ]] && IRC_HOST='irc.freenode.net'
[[ -z $IRC_PORT ]] && IRC_PORT=6667
[[ -z $IRC_CHAN ]] && IRC_CHAN='#hacknroll'

# User infos
[[ -z $IRC_USR_NICK ]] && IRC_USR_NICK='menina'
[[ -z $IRC_USR_PASS ]] && IRC_USR_PASS='***********'
[[ -z $IRC_USR_NAME ]] && IRC_USR_NAME='Heloiza'

[[ -z $IRC_CFG_DEBUG ]] && IRC_CFG_DEBUG=1

str_match()
{
	regexp=$1
	shift; echo "$*" | grep -E "$regexp" > /dev/null
}

debug_print()
{
	[[ $IRC_CFG_DEBUG ]] && echo "$*"
}

#
# Connect to the server using /dev/tcp/[HOST]/[PORT]
# See http://tldp.org/LDP/abs/html/devref1.html#DEVTCP
#
socket_connect()
{
	exec 3<>/dev/tcp/$IRC_HOST/$IRC_PORT || (
		echo "Unable to connect" &&
		exit 1
	)
}

socket_send()
{
	debug_print "< $*"
	echo "$*" >&3;
}

function irc_ident()
{
	socket_send "NICK $IRC_USR_NICK"
	socket_send "USER $IRC_USR_NICK $IRC_USR_NICK $IRC_HOST :$IRC_USR_NAME"
}

function irc_privmsg()
{
	place="$1"; shift; msg="$*"
	msg=$(printf "PRIVMSG %s :%s" "$place" "$msg")

	sleep $(( (${RANDOM} % 2) + 2 ))
	socket_send "$msg"
}

function url_encode()
{
	echo "$*"| xxd -plain | tr -d '\n' | sed 's/\(..\)/%\1/g'
}

function get_anwser()
{
	message=$(replace_to_send "$*")
	message=$(url_encode "$message")

	#anwser=$(curl -s "http://www.ed.conpet.gov.br/mod_perl/bot_gateway.cgi?server=0.0.0.0%3A8085&charset_post=iso-8859-1&charset=utf-8&pure=1&js=0&tst=1&msg=$message" | sed -e :a -e 's/<[^>]*>//g;/</N;//ba')
	anwser="$(
		curl -s "http://bot.insite.com.br/cgi-bin/bot_gateway.cgi?server=0.0.0.0:8088&js=1&msg=$message" |
		head -n 1 |
		cut -d\' -f 2 |
		cut -d\\ -f 1
	)"

	replace_to_recv "$anwser"
}

function get_who()
{
	who="$1"
	who=${who%%\!*} # remove all after !
	who=${who:1}    # remove :
	echo $who
}

function replace_to_recv()
{
	msg="$1"
	msg="${msg/Sete Zoom/$IRC_USR_NAME}"
	msg="${msg/Sete/$IRC_USR_NAME}"
	msg="${msg/Zoom/Cirino}"

	echo "$msg"
}

function replace_to_send()
{
	msg="$1"
	msg="${msg/$IRC_USR_NICK/Sete}"
	msg="${msg/$IRC_USR_NAME/Sete}"

	echo "$msg"
}

#get_anwser "Olá. Qual o seu nome?"
#exit; 

socket_connect
irc_ident

# loop read
while read recv; do
	# Remove CR (\r)
	recv=$(echo -n "$recv" | tr -d '\r')

	debug_print "> $recv"

	# Convert to array
	tokens=( $recv )

	if [[ "${tokens[0]:0:1}" == ':' ]]; then
		case "${tokens[1]}" in
			[0-9]*)
				case "${tokens[1]}" in
					# RPL_WELCOME
					001)
						socket_send "NICKSERV IDENTIFY $IRC_USR_PASS"
					;;
				esac
			;;

			'NOTICE')
				#
				# Join in the channel after identify accepted
				#
				str_match 'You are now identified' $recv && (
					socket_send "JOIN $IRC_CHAN"
				)
			;;


			#
			# When somebody send a message
			#
			'PRIVMSG')
				place="${tokens[2]}"
				msg="${tokens[@]:3}"; msg="${msg:1}"
				nick=$(get_who ${tokens[0]})

				
				str_match "$IRC_USR_NICK" "$msg" && (
					anwser=$(get_anwser "$msg")
					irc_privmsg "$place" "$nick, $anwser"
				)
			;;


			#
			# When JOIN a channel
			#
			'JOIN')
				place="${tokens[2]}"
				nick=$(get_who ${tokens[0]})

				if [[ "$nick" !=  "$IRC_USR_NICK" ]]; then
					anwser=$(get_anwser "Oi")
					irc_privmsg "$place" "$nick, $anwser"
				fi
			;;
		esac

		continue
	else
		case "${tokens[0]}" in
			PING)
				socket_send "PONG $IRC_USR_NICK"
			;;

			#
			# Some error? Try to reconnect
			#
			ERROR)
				socket_connect
				irc_ident
			;;
		esac
	fi
done <&3

