#!/bin/bash

# echo "$pass" | sudo -S ./build.sh
# echo "$pass" | sudo -S ./build.sh --clean

# Builds a Raspbian lite image with some customizations include default locale, username, pwd, host name, boot setup customize etc.
# Must be run on Debian Buster or Ubuntu Xenial and requires some "horsepower".

SECONDS=0
clean=false

while [[ $# -ge 1 ]]; do
    i="$1"
    case $i in
        -c|--clean)
            clean=true
            shift
            ;;
        *)
            echo "Unrecognized option $1"
            exit 1
            ;;
    esac
    shift
done

read -r -t 2 -d $'\0' pi_pwd

if [ -z "$pi_pwd" ]; then
  echo "Pi user password is required (pass via stdin)" >&2
  exit 1
fi

# Script is in /boot/setup, switch to non-root pi-gen path per install script. Assuming default pi user.
#pushd /home/pi/pi-gen

# setup environment variables to tweak config. SD card write script will prompt for WIFI creds.
cat > config <<EOL
export IMG_NAME=blx-raspbian
export RELEASE=buster
export DEPLOY_ZIP=1
export LOCALE_DEFAULT=en_US.UTF-8
export TARGET_HOSTNAME=blx-pi
export KEYBOARD_KEYMAP=us
export KEYBOARD_LAYOUT="English (US)"
export TIMEZONE_DEFAULT=America/New_York
export FIRST_USER_NAME=blue0x
export FIRST_USER_PASS="${pi_pwd}"
export ENABLE_SSH=1
EOL

# Skip stages 3-5, only want Raspbian lite
touch ./stage3/SKIP ./stage4/SKIP ./stage5/SKIP
touch ./stage4/SKIP_IMAGES ./stage5/SKIP_IMAGES

pushd stage2

# don't need NOOBS
rm -f EXPORT_NOOBS || true


# ----- Begin Stage 02, Step 04 - Get BLX Prereqs Step -----
step="04-blx-install-prereq"
if [ -d "$step" ]; then rm -Rf $step; fi
mkdir $step && pushd $step

cat > 00-packages <<RUN
nginx unzip curl default-jdk jq php-fpm
RUN

popd
# ----- End Stage 02, Step 04 - Get BLX Prereqs Step -----

# ----- Begin Stage 02, Step 05 - BLX Install Step -----
step="05-blx-install"
if [ -d "$step" ]; then rm -Rf $step; fi
mkdir $step && pushd $step

BLX_MAINNET_FOLDER="blx-wallet"
BLX_MAINNET_SERVICE="blx-wallet"

NXT_MAINNET_PROPERTIES_FILE_CONTENT="
nxt.myPlatform=BLX-XXXX-XXXX-XXXX-XXXX
nxt.allowedBotHosts=*
nxt.apiServerHost=0.0.0.0
nxt.wellKnownPeers=api.blue0x.com;152.67.72.160;
"

## Contract Runnner Configuration ##
## see https://ardordocs.jelurida.com/Lightweight_Contracts for detailed informations ##
## nxt.addOns=nxt.addons.ContractRunner ##
## addon.contractRunner.secretPhrase=<secretphrase> ##
## addon.contractRunner.feeRateNQTPerFXT.IGNIS=250000000 ##


BLX_MAINNET_SERVICE_FILE_CONTENT="
[Unit]
Description=BLX-Wallet
After=syslog.target
After=network.target

[Service]
RestartSec=2s
Type=simple
WorkingDirectory=/home/blue0x/${BLX_MAINNET_FOLDER}/
ExecStart=/bin/bash /home/blue0x/${BLX_MAINNET_FOLDER}/run.sh
Restart=always

[Install]
WantedBy=multi-user.target
"

cat > 00-run-chroot.sh <<RUN
#!/bin/bash
uri='\$uri'
echo "Download and prepare BLX"
git clone https://github.com/theBlue0x/node.git /home/blue0x/blx-wallet
echo "" && echo "[INFO] creating BLX mainnet configuration ..."
echo "${NXT_MAINNET_PROPERTIES_FILE_CONTENT}" > /home/blue0x/${BLX_MAINNET_FOLDER}/conf/nxt.properties
#echo "" && echo "[INFO] Building financial freedom"
#cd /home/BLX/blx-wallet
#./compile.sh --show-progress
echo "" && echo "[INFO] cleaning up ..."
sudo apt autoremove -y
echo "" && echo "[INFO] creating ardor services ..."
sudo mkdir -p /etc/systemd/system
echo "${BLX_MAINNET_SERVICE_FILE_CONTENT}" | sudo tee /etc/systemd/system/${BLX_MAINNET_SERVICE}.service > /dev/null
sudo systemctl enable ${BLX_MAINNET_SERVICE}.service

echo "" && echo "[INFO] setting ownership of BLX folders ..."
sudo chown -R blue0x:blue0x /home/blue0x/${BLX_MAINNET_FOLDER}
echo "" && echo "[INFO] "

echo "" && echo "[INFO] creating dashboard ..."
wget https://github.com/05259/BLXPi/blob/main/BLXpiDash.zip
unzip BLXPiDash.zip -d /var/www/html
chown www-data:blue0x /var/www/html -R
rm BLXPiDash.zip
mv /etc/nginx/sites-available/default /home/BLX/nginxBackup
echo "
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;

    index index.html index.htm index.php index.nginx-debian.html;

    server_name _;

    location / {
        # First attempt to serve request as file, then
        # as directory, then fall back to displaying a 404.
        try_files \$uri \$uri/ =404;
    }

    # pass PHP scripts to FastCGI server
    #
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;

        # With php-fpm (or other unix sockets):
        fastcgi_pass unix:/run/php/php7.3-fpm.sock;
    #   # With php-cgi (or other tcp sockets):
    #   fastcgi_pass 127.0.0.1:9000;
    }

    # deny access to .htaccess files, if Apache's document root
    # concurs with nginx's one
    #
    location ~ /\.ht {
        deny all;
    }
}
" | sudo tee /etc/nginx/sites-available/default > /dev/null
RUN

chmod +x 00-run-chroot.sh

popd
# ----- End Stage 02, Step 05 - BLX Install Step -----

popd # stage 02

# run build
if [ "$clean" = true ] ; then
    echo "Running build with clean to rebuild last stage"
    CLEAN=1 ./build.sh
else
    echo "Running build"
    ./build.sh
fi

exitCode=$?

duration=$SECONDS
echo "Build process completed in $(($duration / 60)) minutes"

if [ $exitCode -ne 0 ]; then
    echo "Custom Raspbian lite build failed with exit code ${exitCode}" ; exit -1
fi

ls ./deploy
