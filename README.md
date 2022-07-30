# Blue0x Pi

![BLXPi Dashboard](https://github.com/05259/BLXPi/blob/main/BLXPiScreen.png)

## RaspberryPi Image with Blue0x preinstalled
- Blue0x already installed and bootstrapped
- Node set as archival and openAPI
- Starts Blue0x up on boot as a service
- Dashboard with links to wallet, test api page and BLX Docs

### Instructions

## Build yourself

Tested on Ubuntu 18.04.4 LTS

- sudo apt -y install coreutils quilt parted qemu-user-static debootstrap zerofree zip dosfstools bsdtar libcap2-bin grep rsync xz-utils file git curl bc
- git clone https://github.com/05259/pi-gen.git (You could also try the newest version here, but untested: https://github.com/RPi-Distro/pi-gen.git)
- cd pi-gen
- wget https://github.com/05259/BLXPi/blob/main/blxpi.sh
- echo "pi" | sudo bash ./blxpi.sh (You can change **pi** to whatever password you want to set for the user BLX)
