#!/bin/bash

# Default packages to install if no version is selected.
# If another architecture type is needed, you can change these names to what you need.
# https://elastic.co/downloads/past-releases

get_version () {
    echo -ne "Retrieving available Elastic 8 versions...\r"
    versions=()
    version_list=$(curl -s https://www.elastic.co/downloads/past-releases#elasticsearch | grep -ho "8\.[[:digit:]]\.[[:digit:]]" | sort -ru)

    for val in $version_list
    do
        versions+=("$val")
    done
}

package_prefix="https://artifacts.elastic.co/downloads/"

get_version

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
echo -e "uiSettings:\n  overrides:\n    \"theme:darkMode\": true" | sudo tee -a /etc/kibana/kibana.yml $>/dev/null

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
    sudo apt install unzip &>/dev/null
fi

sudo unzip -q /etc/elasticsearch/certs/ca.zip -d /etc/elasticsearch/certs/
sudo rm /etc/elasticsearch/certs/ca.zip

echo "[*] Creating Certificates for Fleet Server"
sudo /usr/share/elasticsearch/bin/elasticsearch-certutil cert -s --name fleet-server --ca-cert /etc/elasticsearch/certs/ca/ca.crt --ca-key /etc/elasticsearch/certs/ca/ca.key --out /etc/elastic-agent/certs/fleet-server.zip --pem
sudo unzip /etc/elastic-agent/certs/fleet-server.zip -d /etc/elastic-agent/certs/ &>/dev/null
sudo rm /etc/elastic-agent/certs/fleet-server.zip

rm $agent_package

echo "================================================================"
echo "==                     Fleet-Server Setup                     =="
echo "================================================================"
echo "[*] Go to Kibana -> Click on Fleet"
echo "[!] Step 1: Click on Create Policy"
echo "[*] Step 2: Ignore. Elastic Agent is already Downloaded"
echo "[*] Step 3: Choose \"Quick start\" for Deployment Mode "
echo "[*] Step 4: Type in https://SERVER_IP:8220 and click \"Add host\""
echo "[*] Step 5: Click Generate Token"
echo "[*] Use the following template to enroll the Fleet Server"
echo "[*] Replace the 3 variables (SERVER_IP, FLEET_SERVER_TOKEN, & ELASTICSEARCH_CA_FINGERPRINT) with the information that Step 6 provides:"
echo "sudo elastic-agent enroll -f \\"
echo "--url=https://SERVER_IP:8220 \\"
echo "--fleet-server-es=https://SERVER_IP:9200 \\"
echo "--fleet-server-service-token=FLEET_SERVER_TOKEN \\"
echo "--fleet-server-policy=fleet-server-policy \\"
echo "--fleet-server-es-ca-trusted-fingerprint=ELASTICSEARCH_CA_FINGERPRINT \\"
echo "--certificate-authorities=/etc/elasticsearch/certs/ca/ca.crt \\"
echo "--fleet-server-cert=/etc/elastic-agent/certs/fleet-server/fleet-server.crt \\"
echo "--fleet-server-cert-key=/etc/elastic-agent/certs/fleet-server/fleet-server.key"
echo "[*] Once you have entered the command and the Agent shuts down, start the agent:"
echo "sudo service elastic-agent start"
echo "[+] Check Fleet. You should see Fleet Server up and healthy!"