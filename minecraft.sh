sudo apt update

sudo apt install apt-transport-https software-properties-common gnupg wget

wget -qO - https://adoptopenjdk.jfrog.io/adoptopenjdk/api/gpg/key/public | sudo apt-key add -
sudo add-apt-repository https://adoptopenjdk.jfrog.io/adoptopenjdk/deb/

sudo apt update
sudo apt install adoptopenjdk-16-hotspot
sleep 2

sudo apt install screen -y
sleep 2

cd ~
mkdir minecraft
cd minecraft

wget https://piston-data.mojang.com/v1/objects/8dd1a28015f51b1803213892b50b7b4fc76e594d/server.jar
sleep 2

nano start.sh
sleep 2

java -Xms512M -Xmx1024M -jar server.jar nogui

chmod +x start.sh
echo "eula=true" > eula.txt

echo "Gunakan -> screen -S "My Minecraft Server <- untuk cek server"