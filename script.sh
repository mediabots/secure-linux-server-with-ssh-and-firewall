#!/usr/bin/bash

# ENV for the Script 
export DEBIAN_FRONTEND=noninteractive
 export HISTCONTROL=ignoredups:ignorespace

# - color
GREEN='\033[0;32m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# - port
MIN_PORT=30000
MAX_PORT=62000

# - temp file for scripts subsequent usage
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
	echo "=================================================================="
	echo -e "${GREEN}[IMPORTANT]${NC}"
	echo -e "your passphrase for file - ${PURPLE}${filename}${NC} is: ${PURPLE}${PHRASE}${NC}"
	echo "please note it down in your non-digital notebook. This value is non-recoverable"
	printf "${PURPLE}$(cat $HOME/.ssh/$filename.pub)${NC}\n"
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
		sshpass -e ssh -o "StrictHostKeyChecking no" -o PreferredAuthentications=password -o PubkeyAuthentication=no $5@$6 -p $7;
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

if [ "$t_out" == "remote" ]; then
	echo $t_out;

	# setting default values if ENV were not set
	if [ -z $USERID ]; then
		USERID='ubuntu'
	fi
	if [ -z $PASSWORD ]; then
		 PASSWORD=$(tr </dev/urandom -dc A-Za-z0-9*%^+~ | head -c6)$(tr </dev/urandom -dc 0-9 | head -c1)$(tr </dev/urandom -dc *%^+~ | head -c1)
	fi

	if [ ! -z $RANDOMPORT ]; then
		PORT=$(($RANDOM%($MAX_PORT-$MIN_PORT+1)+$MIN_PORT))
	fi

	if [ -z $PORT ]; then
		if [ ! -z $3 ]; then
			number=$3
			if [ -z "${number//[0-9]}" ]; then
				if [ -n "$number" ]; then
					PORT=$number
				fi
			else
				PORT=60022
			fi
		else
			PORT=60022
		fi
	fi

	# if new user is already exist into the Remote machine then just add that user into the sudo group, else create new user with sudo privilege
	if [ `ls /home | grep $USERID | wc -l` = 1 ]; then 
		sudo usermod -aG sudo $USERID; 
	else 
		sudo useradd --create-home --user-group --groups sudo --shell /bin/bash $USERID; 
	fi

	# confirm created user groups
	groups $USERID

	# set new user password
	 echo -e "$PASSWORD\n$PASSWORD" | (sudo passwd $USERID)

	# get current/old user directory 
	USERDIR=`eval echo ~$USER`; 

	# pre-check SSH Auth requirements
	if [ ! -f $USERDIR/.ssh/authorized_keys ]; then
		echo -e "${RED}Error:${NC} looks like this remote machine has not setup for SSH authentication"
		echo -e "${PURPLE}=>${NC} to know how to setup SSH authentication, please refer to our Script documentation"
		exit 1;
	fi
	if [ $(cat $USERDIR/.ssh/authorized_keys | wc -l) -eq 0 ]; then 
		echo -e "${RED}Error:${NC} no public key has been added to this remote machine to allow SSH authentication from out_side/other_side"
		echo -e "${PURPLE}=>${NC} to know how to add a public key, please refer to our Script documentation"
		exit 1;
	fi

	# make .ssh folder for new user and set correct permission & ownership for that folder and its files. Then copy current/old user SSH keys to new user
	sudo mkdir -p /home/$USERID/.ssh
	sudo chmod 700 /home/$USERID/.ssh
	sudo cp -r $USERDIR/.ssh/* /home/$USERID/.ssh/
	sudo chmod 600 /home/$USERID/.ssh/authorized_keys
	sudo chown $USERID:$USERID /home/$USERID/.ssh -R

	# change default ssh port, disable password-based login, disable any kind of login for root; allow ssh-based authentication, and allow ssh-based port forwarding
	sudo sed -i "s/#\?Port.*$/Port $PORT/g" /etc/ssh/sshd_config
	sudo sed -i 's/#\?PermitRootLogin.*$/PermitRootLogin no/g' /etc/ssh/sshd_config
	sudo sed -i 's/#\?PasswordAuthentication.*$/PasswordAuthentication no/g' /etc/ssh/sshd_config
	sudo sed -i 's/#\?PermitEmptyPasswords.*$/#PermitEmptyPasswords no/g' /etc/ssh/sshd_config
	sudo sed -i 's/#\?PubkeyAuthentication.*$/PubkeyAuthentication yes/g' /etc/ssh/sshd_config
	sudo bash -c ' echo "GatewayPorts yes" >> /etc/ssh/sshd_config'

	# restart ssh server to make above changes
	sudo systemctl restart sshd

	# install feature rich Firewall
	sudo systemctl stop ufw
	sudo systemctl disable --now ufw
	sleep 3
	sudo apt remove --yes --purge ufw
	sudo apt update && sudo -E apt -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef" -qq -y install firewalld --allow-change-held-packages

	# confirm Firewall state
	sudo firewall-cmd --state

	# replace ssh default port to the new ssh port so Firewall will whitelist that new port for incoming connection  
	sudo sed -i "s/port=\".*\"/port=\"$PORT\"/g" /usr/lib/firewalld/services/ssh.xml
	
	# reload Firewall to take the effect of the above config changes
	sudo firewall-cmd --reload

	# set Firewall to auto start on every system reboot
	sudo systemctl enable --now firewalld

	# set Firewall rules to allow HTTP & HTTPS traffic
	sudo firewall-cmd --zone=public --add-port=80/tcp
	sudo firewall-cmd --zone=public --permanent --add-port=80/tcp
	sudo firewall-cmd --zone=public --add-port=443/tcp
	sudo firewall-cmd --zone=public --permanent --add-port=443/tcp

	# list Firewall rules, etc 
	sudo firewall-cmd --list-all
	sudo firewall-cmd --get-default-zone
	sudo firewall-cmd --get-active-zones

	# print info
	echo "=================================================================="
	echo -e "${GREEN}[IMPORTANT]${NC} ${PURPLE}username:${NC} $USERID ${PURPLE}password:${NC} $PASSWORD ${PURPLE}port:${NC} $PORT \nplease note them down in your notebook. These values are non-recoverable"
	exit 0;

fi

