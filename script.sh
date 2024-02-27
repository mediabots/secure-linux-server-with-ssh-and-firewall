#!/usr/bin/bash

export DEBIAN_FRONTEND=noninteractive

tmp_file_path=/tmp/.script #$HOME/.script

while getopts ":a:t:m:" opt; do
  case $opt in
    a) arg_1="$OPTARG"
    ;;
    t) t_out="$OPTARG"
    ;;
    m) m_out="$OPTARG"
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
    exit 1
    ;;
  esac

  case $OPTARG in
    -*) echo "Option $opt needs a valid argument"
    exit 1
    ;;
  esac
done

if [ "$1" != '-t' ]; then echo "value of -t is required, please check the document to pass a proper value of it"; exit 1; fi

if [ "$t_out" != "host" ] && [ "$t_out" != "remote" ]; then echo "value of -t should be either host or remote"; exit 1; fi
if [ "$t_out" == "host" ] && [ -z $m_out ] ; then echo "for -t host value of -m is required, please check the document to pass a proper value of it"; exit 1; fi 
printf "type is %s\n" "$t_out"
#printf "Argument arg_1 is %s\n" "$arg_1"


if [ "$t_out" == "host" ] && [ "$m_out" == "generate" ];
then
	echo "generating ssh key pair for you";
	while :; do filename=id_$(openssl rand -hex 1); if [[ ! -f $HOME/.ssh/$filename ]] ; then break; fi; done
	 export PHRASE=$(tr </dev/urandom -dc A-Za-z0-9*%^+~ | head -c6)$(tr </dev/urandom -dc 0-9 | head -c1)$(tr </dev/urandom -dc *%^+~ | head -c1)	
	rm -rf $tmp_file_path
	echo export PHRASE="${PHRASE}" > $tmp_file_path
	echo export KEYFILEPATH=$HOME/.ssh/$filename >> $tmp_file_path
	##source $tmp_file_path
	##rm -rf $tmp_file_path
	ssh-keygen -t ed25519 -C $filename -f $HOME/.ssh/$filename -P "${PHRASE}"
	echo "========================================================"
	echo "your passphrase for file - "$filename "is: "$PHRASE
	echo "IMPORTANT: please note it down in your non-digital notebook. This value in non-recoverable"
	cat $HOME/.ssh/$filename.pub
	echo "above is the public key of your SSH key pair. You can share it with your Hosting/Cloud provider"
	exit 0;
fi

if [ "$t_out" == "host" ] && [ "$m_out" == "login" ];
then
	echo "log into remote machine";
	if [ -z $WITHPASS ]; then
		echo "WITHPASS enviroment variable has not been set by you, please check the document to set a proper value of it"
		exit 1;
	else
		if [ "$WITHPASS" == 1 ] && [ -z $SSHPASS ]; then
			echo "SSHPASS enviroment variable has not been set by you, please check the document to set a proper value of it"
			exit 1;
		fi
	fi
	if [ -z $5 ]; then
		echo "username not provided via commnad line argument, please check the document to know how to pass a username"
		exit 1;
	fi
	if [ -z $6 ]; then
		echo "IPv4 not provided via commnad line argument, please check the document to know how to pass a IP"
		exit 1;
	fi
	if [ -z $7 ]; then
		echo "Port not provided via commnad line argument, please check the document to know how to pass a port number"
		exit 1;
	fi
	if [ "$WITHPASS" == 1 ]; then
		sudo -E apt -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef" -qq -y install sshpass --allow-change-held-packages;
		sshpass -e ssh -o "StrictHostKeyChecking no" $5@$6 -p $7;
		exit 0;
	else
		echo "use expect";
		if [ -f $tmp_file_path ] && [ -z $8  ]
		then
			echo "souring file - ${tmp_file_path}" 
			source $tmp_file_path
		fi
		if [ -z $8 ] && [ -z $KEYFILEPATH ]; then
			echo "Private key path not provided via commnad line argument, please check the document to know how to pass that"
			exit 1;
		fi
		if [ ! -z $8 ]; then
		       KEYFILEPATH=$8
		fi	       
		if [ -z $PHRASE ]; then
			echo "PHRASE enviroment variable has not been set by you, please check the document to set a proper value of it"
			exit 1;
		fi
		sudo -E apt -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef" -qq -y install expect keychain --allow-change-held-packages;
		eval `keychain --eval --nogui`
		#chmod +x expect-command.exp
		./expect-command.exp $5 $6 $7 $KEYFILEPATH $PHRASE
		exit 0;
	fi
fi

if [ "$t_out" == "remote" ];
then
	echo $t_out;
	exit 0;
fi

