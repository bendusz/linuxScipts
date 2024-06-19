sudo apt update
sudo apt install -y curl

curl -o adJoin.sh https://raw.githubusercontent.com/bendusz/linuxScipts/main/adJoin.sh
chmod +x adJoin.sh
sudo ./adJoin.sh
