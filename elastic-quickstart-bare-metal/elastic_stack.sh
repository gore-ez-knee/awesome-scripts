#!/bin/bash

# Default packages to install if no version is selected.
# If another architecture type is needed, you can change these names to what you need.
# https://elastic.co/downloads/past-releases

green=`tput setaf 2`
reset=`tput sgr0`

load_animation () {
while kill -0 $! >/dev/null 2>&1
do
  for i in {1..3};do
    echo -n "."
    sleep 1
  done
  echo -ne "\033[3D\033[0K"
done
echo ${green}" DONE"${reset}
}

get_version () {
    echo -ne "Retrieving available Elastic 8 versions...\r"
    versions=()
    version_list=$(curl -s https://www.elastic.co/downloads/past-releases#elasticsearch | grep -ho "8\.[[:digit:]]\.[[:digit:]]" | sort -ru)

    for val in $version_list
    do
        versions+=("$val")
    done
}

get_ip () {
    ips=()
    ip_list=$(ip addr | grep -Eo "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" | grep -Ev "(127.0.0.1|255$|\.1$|^169)")
    for i in $ip_list
    do
        ips+=("$i")
    done
}

package_prefix="https://artifacts.elastic.co/downloads/"

get_version
get_ip

num=0

echo -e "\033[KSelect a number corresponding to the version you'd like to download: "
for version in "${versions[@]}"; do
    echo "$num)  $version"
    ((num=num+1))
done

read -p "Enter number: " v

if [ $((v)) -le $((${#versions[@]}-1)) ];then
    elastic_package="elasticsearch-${versions[$v]}-amd64.deb"
    kibana_package="kibana-${versions[$v]}-amd64.deb"
    agent_package="elastic-agent-${versions[$v]}-amd64.deb"
else
    echo "Pick a number that is available"
    echo "Exiting Script"
    exit
fi

num=0
server_ip=""

echo "Select a number corresponding the Server's IP: "
for ip in "${ips[@]}"; do
    echo "$num)  $ip"
    ((num=num+1))
done

read -p "Enter number: " p

if [ $((v)) -le $((${#versions[@]}-1)) ];then
    server_ip="${ips[$p]}"
else
    echo "Pick a number that is available"
    echo "Exiting Script"
    exit
fi

echo -ne "[*] Downloading Elasticsearch ${versions[$v]}...\r"
if curl -s -L -O $package_prefix"elasticsearch/"$elastic_package &> /dev/null;then
    echo -e "\033[K[*] Elasticsearch ${versions[$v]} Download Successful!"
else
    echo -e "\033[K[-] Unable to Download Elasticsearch"
    echo "[-] Exiting Script"
    exit
fi

echo -ne "[*] Installing Elasticsearch ${versions[$v]}...\r"
if sudo dpkg -i $elastic_package | tee elasticsearch_install.out &> /dev/null;then
    echo -e "\033[K[+] Elasticsearch ${versions[$v]} Installed!"
    echo "[!] Important output saved in elasticsearch_install.out"
else
    echo -e "\033[K[-] Unable to install Elasticsearch"
    echo "[-] Exiting Script"
    exit
fi

su_password=$(cat elasticsearch_install.out | grep "is : " | rev | cut -d " " -f 1 | rev)

echo "[*] Enabling Elasticsearch to autostart..."
sudo /bin/systemctl daemon-reload
sudo /bin/systemctl enable elasticsearch.service &> /dev/null
echo -ne "[*] Starting Elasticsearch...\r"
sudo /bin/systemctl start elasticsearch.service

# If the last command ran successfully, then Connection to Elasticsearch was successfull
if curl -s -k -u "elastic:$su_password" https://127.0.0.1:9200 | grep "You Know, for Search" &> /dev/null; then
    echo -e "\033[K[+] Successful Connection to Elasticsearch! :)"
else
    echo -e "\033[K[-] Unable to Connect to Elasticsearch :("
    echo "[-] Exiting Script"
    exit
fi

echo "[*] Generating Kibana Enrollment Token..."
kibana_token=$(sudo /usr/share/elasticsearch/bin/elasticsearch-create-enrollment-token -s kibana)

echo -ne "[*] Downloading Kibana ${versions[$v]}...\r"
if wget $package_prefix"kibana/"$kibana_package &> /dev/null;then
    echo -e "\033[K[*] Kibana ${versions[$v]} Download Successful!"
else
    echo -e "\033[K[-] Unable to Download Kibana"
    echo "[-] Exiting Script"
    exit
fi

echo -ne "[*] Installing Kibana ${versions[$v]}...\r"
if sudo dpkg -i $kibana_package &> /dev/null;then
    echo -e "\033[K[+] Kibana ${versions[$v]} Installed!"
else
    echo -e "\033[K[-] Unable to install Kibana ${versions[$v]}"
    echo "[-] Exiting Script"
    exit
fi

echo -ne "[*] Setting Up Kibana with Elasticsearch...\r"
if sudo /usr/share/kibana/bin/kibana-setup -s -t $kibana_token;then
    echo -e "\033[K[+] Kibana Successfully Setup with Elasticsearch"
else
    echo -e "\033[K[-] Something went wrong with the enrollement token..."
    echo "[-] Exiting Script"
    exit
fi

read -p "[?] Would you like to add a password to your self-signed keys?(y/n): " question
password=""
if [[ "$question" == "y" || "$question" == "Y" ]];then
    while true; do
        read -s -p "Password: " password
        echo
        read -s -p "Password (again): " password2
        echo
        [[ "$password" == "$password2" ]] && break
        echo "Please try again"
    done
    echo "$password" | sudo /usr/share/kibana/bin/kibana-keystore add server.ssl.keystore.password -x -s
fi

sudo mkdir /etc/kibana/certs

echo -ne "[*] Creating self-signed certificates...\r"
if sudo /usr/share/elasticsearch/bin/elasticsearch-certutil cert -s --self-signed --pass "$password" --name kibana-certs --out /etc/kibana/certs/kibana-certs.p12;then
    echo -e "\033[K[+] Certificates created!"
else
    echo -e "\033[K[-] Unable to create certificates :("
    echo "[-] Exiting Script"
    exit
fi

sudo chown -R kibana: /etc/kibana/certs

echo "[*] Modifying kibana.yml with new settings..."
echo -e "server.host: 0.0.0.0\nserver.ssl.enabled: true\nserver.ssl.keystore.path: \"/etc/kibana/certs/kibana-certs.p12\"" | sudo tee -a /etc/kibana/kibana.yml &> /dev/null
if [[ "$question" == "n" || "$question" == "N" ]];then
    echo "server.ssl.keystore.password: \"\"" | sudo tee -a /etc/kibana/kibana.yml &> /dev/null
fi

echo "[*] Generating Encryption Keys for Kibana and writing them to kibana.yml"
sudo /usr/share/kibana/bin/kibana-encryption-keys generate -f | tail -4 | sudo tee -a /etc/kibana/kibana.yml &>/dev/null
echo -e "uiSettings:\n  overrides:\n    \"theme:darkMode\": true" | sudo tee -a /etc/kibana/kibana.yml &>/dev/null

echo "[*] Enabling Kibana to autostart..."
sudo /bin/systemctl daemon-reload
sudo /bin/systemctl enable kibana.service &> /dev/null
echo -ne "[*] Starting Kibana...\r"
sudo /bin/systemctl start kibana.service

rm $elastic_package
rm $kibana_package

# It takes a few seconds for the Kibana service to properly load
sleep 15

echo -ne "\033[K"

echo "================================================================"
echo "==              Elasticsearch & Kibana Installed              =="
echo "================================================================"
echo "[*] Now go to https://SERVER_IP:5601"
echo "[*] Login with:"
echo "    Username: elastic"
echo "    Password: $su_password"
echo "================================================================"
read -p "[?] Would you like to setup a Fleet Server?(y/n): " q
if [[ "$q" == "n" || "$q" == "N" ]];then
    echo "Alrighty then. Have fun with Elastic!"
    exit
fi

echo -ne "[*] Downloading Elastic Agent ${versions[$v]}...\r"
if curl -s -L -O $package_prefix"beats/elastic-agent/"$agent_package &> /dev/null;then
    echo -e "\033[K[*] Elastic Agent ${versions[$v]} Download Successful!"
else
    echo -e "\033[K[-] Unable to Download Elastic Agent"
    echo "[-] Exiting Script"
    exit
fi

echo -ne "[*] Installing Elastic Agent ${versions[$v]}...\r"
if sudo dpkg -i $agent_package &> /dev/null;then
    echo -e "\033[K[+] Elastic agent ${versions[$v]} Installed!"
else
    echo -e "\033[K[-] Unable to install Elastic Agent"
    echo "[-] Exiting Script"
    exit
fi

sudo mkdir /etc/elastic-agent/certs/
echo "[*] Generating a CA to create Fleet Server Certificates"
sudo /usr/share/elasticsearch/bin/elasticsearch-certutil ca -s --pem --out /etc/elasticsearch/certs/ca.zip

if ! which unzip &>/dev/null
then
    echo "[!] Need to install Unzip binary"
    sudo apt install unzip -y &>/dev/null
fi

if ! which jq &>/dev/null
then
    echo "[!] Need to install jq binary"
    sudo apt install jq -y &>/dev/null
fi

sudo unzip -q /etc/elasticsearch/certs/ca.zip -d /etc/elasticsearch/certs/
sudo rm /etc/elasticsearch/certs/ca.zip

echo "[*] Creating Certificates for Fleet Server"
sudo /usr/share/elasticsearch/bin/elasticsearch-certutil cert -s --name fleet-server --ca-cert /etc/elasticsearch/certs/ca/ca.crt --ca-key /etc/elasticsearch/certs/ca/ca.key --out /etc/elastic-agent/certs/fleet-server.zip --pem
sudo unzip /etc/elastic-agent/certs/fleet-server.zip -d /etc/elastic-agent/certs/ &>/dev/null
sudo rm /etc/elastic-agent/certs/fleet-server.zip

rm $agent_package

curl -k -u "elastic:$su_password" https://localhost:5601/api/fleet/agents/setup -XGET \
--header 'kbn-xsrf: true' &>/dev/null

echo -n "[*] Setting Up Fleet Agent Policy"
curl -k -u "elastic:$su_password" https://localhost:5601/api/fleet/agent_policies?sys_monitoring=true -XPOST \
--header 'content-type: application/json' \
--header 'kbn-xsrf: true' \
--data '{"id":"fleet-server-policy","name":"Fleet Server policy","description":"","namespace":"default","monitoring_enabled":["logs","metrics"],"has_fleet_server":true}' &>/dev/null &
load_animation

echo "[*] Snagging Service Token"
token=`curl -k -u "elastic:$su_password" -s -X POST https://localhost:5601/api/fleet/service_tokens --header 'kbn-xsrf: true' | jq -r .value`

echo "[*] Getting Elastcsearch CA Fingerprint"
fingerprint=`sudo openssl x509 -fingerprint -sha256 -noout -in /etc/elasticsearch/certs/http_ca.crt | awk -F"=" {' print $2 '} | sed s/://g | tr '[:upper:]' '[:lower:]'`

echo -n "[*] Adding Fleet Server host"
curl -k -XPUT -u "elastic:$su_password" https://localhost:5601/api/fleet/settings \
--header 'kbn-xsrf: true' \
--header 'content-type: application/json' \
-d '{"fleet_server_hosts":["https://192.168.235.133:8220"]}' &
load_animation

curl -k -u "elastic:$su_password" https://localhost:5601/api/fleet/agents/setup -XGET \
--header 'kbn-xsrf: true' &>/dev/null

echo -n "[*] Enrolling Fleet"
sudo elastic-agent enroll -f \
--url=https://$server_ip:8220 \
--fleet-server-es=https://$server_ip:9200 \
--fleet-server-service-token=$token \
--fleet-server-policy=fleet-server-policy \
--fleet-server-es-ca-trusted-fingerprint=$fingerprint \
--certificate-authorities=/etc/elasticsearch/certs/ca/ca.crt \
--fleet-server-cert=/etc/elastic-agent/certs/fleet-server/fleet-server.crt \
--fleet-server-cert-key=/etc/elastic-agent/certs/fleet-server/fleet-server.key &>/dev/null &
load_animation

sudo /bin/systemctl daemon-reload
sudo /bin/systemctl enable elastic-agent &> /dev/null
sudo /bin/systemctl start elastic-agent

echo "================================================================"
echo "==                   Fleet Server Installed                   =="
echo "================================================================"