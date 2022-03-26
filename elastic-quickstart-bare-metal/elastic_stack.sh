#!/bin/bash

# Default packages to install if no version is selected.
# If another architecture type is needed, you can change these names to what you need.
# https://elastic.co/downloads/past-releases
elastic_package="elasticsearch-8.1.1-amd64.deb"
kibana_package="kibana-8.1.1-amd64.deb"

package_prefix="https://artifacts.elastic.co/downloads/"

versions=("8.1.1" "8.1.0" "8.0.1" "8.0.0")

num=0

echo "Select a number corresponding to the version you'd like to download: "
for version in ${versions[@]}; do
    echo "$num)  $version"
    ((num=num+1))
done
echo "4)  Use default package that is set in the script"

read -p "Enter number: " v

if [ $((v)) -le 9 ];then
    elastic_package="elasticsearch-${versions[$v]}-amd64.deb"
    kibana_package="kibana-${versions[$v]}-amd64.deb"
fi


echo "[*] Downloading Elasticsearch ${versions[$v]}..."
if curl -s -L -O $package_prefix"elasticsearch/"$elastic_package &> /dev/null;then
    echo "[*] Elasticsearch ${versions[$v]} Download Successful!"
else
    echo "[-] Unable to Download Elasticsearch"
    echo "[-] Exiting Script"
    exit
fi

echo "[*] Installing Elasticsearch ${versions[$v]}..."
if sudo dpkg -i $elastic_package | tee elasticsearch_install.out &> /dev/null;then
    echo "[+] Elasticsearch ${versions[$v]} Installed!"
    echo "[!] Important output saved in elasticsearch_install.out"
else
    echo "[-] Unable to install Elasticsearch"
    echo "[-] Exiting Script"
    exit
fi

su_password=$(cat elasticsearch_install.out | grep "is : " | rev | cut -d " " -f 1 | rev)

echo "[*] Enabling Elasticsearch to autostart..."
sudo /bin/systemctl daemon-reload
sudo /bin/systemctl enable elasticsearch.service &> /dev/null
echo "[*] Starting Elasticsearch..."
sudo /bin/systemctl start elasticsearch.service

# If the last command ran successfully, then Connection to Elasticsearch was successfull
if curl -s -k -u "elastic:$su_password" https://127.0.0.1:9200 | grep "You Know, for Search" &> /dev/null; then
    echo "[+] Successful Connection to Elasticsearch! :)"
else
    echo "[-] Unable to Connect to Elasticsearch :("
    echo "[-] Exiting Script"
    exit
fi

echo "[*] Generating Kibana Enrollment Token..."
kibana_token=$(sudo /usr/share/elasticsearch/bin/elasticsearch-create-enrollment-token -s kibana)

#echo "Superuser Password: $su_password"
#echo "Kibana Token: $kibana_token"

echo "[*] Downloading Kibana ${versions[$v]}..."
if wget $package_prefix"kibana/"$kibana_package &> /dev/null;then
    echo "[*] Kibana ${versions[$v]} Download Successful!"
else
    echo "[-] Unable to Download Kibana"
    echo "[-] Exiting Script"
    exit
fi

echo "[*] Installing Kibana ${versions[$v]}..."
if sudo dpkg -i $kibana_package &> /dev/null;then
    echo "[+] Kibana Installed!"
else
    echo "[-] Unable to install Kibana"
    echo "[-] Exiting Script"
    exit
fi

echo "[*] Setting Up Kibana with Elasticsearch..."
if sudo /usr/share/kibana/bin/kibana-setup -s -t $kibana_token;then
    echo "[+] Kibana Successfully Setup with Elasticsearch"
else
    echo "[-] Something went wrong with the enrollement token..."
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

echo "[*] Creating self-signed certificates..."
if sudo /usr/share/elasticsearch/bin/elasticsearch-certutil cert -s --self-signed --pass "$password" --name kibana-certs --out /etc/kibana/certs/kibana-certs.p12;then
    echo "[+] Certificates created!"
else
    echo "[-] Unable to create certificates :("
    echo "[-] Exiting Script"
    exit
fi

sudo chown -R kibana: /etc/kibana/certs

echo "[*] Modifying kibana.yml with new settings..."
echo -e "server.host: 0.0.0.0\nserver.ssl.enabled: true\nserver.ssl.keystore.path: \"/etc/kibana/certs/kibana-certs.p12\"" | sudo tee -a /etc/kibana/kibana.yml &> /dev/null
if [[ "$question" == "n" || "$question" == "N" ]];then
    echo "server.ssl.keystore.password: \"\"" | sudo tee -a /etc/kibana/kibana.yml &> /dev/null
fi

echo "[*] Enabling Kibana to autostart..."
sudo /bin/systemctl daemon-reload
sudo /bin/systemctl enable kibana.service &> /dev/null
echo "[*] Starting Kibana..."
sudo /bin/systemctl start kibana.service

# It takes a few seconds for the Kibana service to properly load
sleep 15

echo "================================================================"
echo "==              Elasticsearch & Kibana Installed              =="
echo "================================================================"
echo "[*] Now go to https://SERVER_IP:5601"
echo "[*] Login with:"
echo "    Username: elastic"
echo "    Password: $su_password"