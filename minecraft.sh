#!/bin/bash
# Only for Ubuntu 22.04 

sudo apt update

sudo apt install apt-transport-https software-properties-common gnupg wget screen ufw -y

sudo add-apt-repository ppa:openjdk-r/ppa
sleep 2

sudo apt update
sleep 2

sudo apt install openjdk-17-jre-headless
sleep 2

sudo ufw allow 25565
sleep 2

wget https://piston-data.mojang.com/v1/objects/8dd1a28015f51b1803213892b50b7b4fc76e594d/server.jar
sleep 2

java -Xms1024M -Xmx1024M -jar server.jar nogui

echo "eula=true" > eula.txt

echo "Gunakan screen -S "My Minecraft Server untuk cek server"