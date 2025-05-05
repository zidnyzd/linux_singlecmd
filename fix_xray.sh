sudo mv /usr/local/bin/xray /usr/local/bin/xray.bak && \
    wget -qO /usr/local/bin/xray "https://raw.githubusercontent.com/zidnyzd/linux/main/xray/xray.linux.64bit"  && \
chmod +x /usr/local/bin/xray && \
sed -i 's/"enabled": true/"enabled": false/' /etc/xray/vmess/config.json \
    /etc/xray/vless/config.json \
    /etc/xray/trojan/config.json \
    /etc/xray/shadowsocks/config.json && \
systemctl restart vmess@config vless@config trojan@config shadowsocks@config